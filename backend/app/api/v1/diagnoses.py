import uuid

from datetime import date

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.security import utcnow
from app.models import AnalysisJob, Crop, CropLog, Diagnosis, Disease, Plant, Post, Reminder, User
from app.repositories.catalog_repo import DiseaseRepository
from app.schemas.community import PostOut
from app.schemas.diagnosis import AnalysisJobOut, CarePlanApplied, CarePlanApply, CarePlanOut, CarePlanTask, DiagnosisOut, FeedbackIn, ReviewRequestIn, ShareIn
from app.services.care_plan import build_plan
from app.services.community_service import post_out
from app.services.diagnosis_service import health_from, run_diagnosis, to_out
from app.services import analysis_jobs
from app.services.limits import ensure_can_add_crop, ensure_can_diagnose
from app.services.storage import get_storage, read_image

router = APIRouter(prefix="/diagnoses", tags=["Diagnoses"])


async def own(db: AsyncSession, diag_id: uuid.UUID, user: User) -> Diagnosis:
    d = await db.get(Diagnosis, diag_id)
    if d is None or d.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tashxis topilmadi")
    return d


@router.post("", response_model=DiagnosisOut, status_code=201)
async def create_diagnosis(
    image: UploadFile = File(...),
    crop_id: uuid.UUID | None = Form(default=None),
    plant_id: uuid.UUID | None = Form(default=None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """plant_id — ixtiyoriy ekin turi: AI faqat shu ekin kasalliklari ichidan tanlaydi (aniqroq natija)."""
    return await run_diagnosis(db, user, image, crop_id, plant_id)


@router.post("/jobs", response_model=AnalysisJobOut, status_code=202)
async def create_job(
    image: UploadFile = File(...),
    client_key: str = Form(min_length=8, max_length=64),
    crop_id: uuid.UUID | None = Form(default=None),
    plant_id: uuid.UUID | None = Form(default=None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """TZ A01: rasm tekshiriladi va saqlanadi, tahlil fonda boradi. Holat — GET /diagnoses/jobs/{id}.
    `client_key` — ilova har bir tanlangan rasm uchun yaratadi: qayta yuborilsa o'sha ish qaytadi (dublikat yo'q)."""
    existing = await db.scalar(select(AnalysisJob).where(AnalysisJob.user_id == user.id, AnalysisJob.client_key == client_key))
    if existing is not None:
        return existing
    await ensure_can_diagnose(db, user)
    if crop_id:
        crop = await db.get(Crop, crop_id)
        if crop is None or crop.user_id != user.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Ekin topilmadi")
    if plant_id and await db.get(Plant, plant_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "O'simlik turi topilmadi")
    data, ext = await read_image(image)
    job = AnalysisJob(user_id=user.id, client_key=client_key, image_url=get_storage().save(data, ext, "diagnoses"), ext=ext,
                      crop_id=crop_id, plant_id=None if crop_id else plant_id)
    db.add(job)
    await db.commit()
    await db.refresh(job)
    analysis_jobs.schedule(job.id)
    return job


async def own_job(db: AsyncSession, job_id: uuid.UUID, user: User) -> AnalysisJob:
    job = await db.get(AnalysisJob, job_id)
    if job is None or job.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tahlil topilmadi")
    return job


@router.get("/jobs/{job_id}", response_model=AnalysisJobOut)
async def get_job(job_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await own_job(db, job_id, user)


@router.post("/jobs/{job_id}/cancel", response_model=AnalysisJobOut)
async def cancel_job(job_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """TZ S03: bekor qilish server holatini tekshiradi. Natija allaqachon tayyor bo'lsa, ish "done" bo'lib qaytadi
    (ilova natijani ochadi); bekor qilingan tahlil tashxis yaratmaydi va limitdan hisoblanmaydi."""
    job = await own_job(db, job_id, user)
    await analysis_jobs.cancel(db, job.id)
    await db.refresh(job)
    return job


@router.get("", response_model=list[DiagnosisOut])
async def list_diagnoses(crop_id: uuid.UUID | None = None, limit: int = 50,
                         user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = (select(Diagnosis).where(Diagnosis.user_id == user.id, Diagnosis.hidden_at.is_(None))
            .order_by(Diagnosis.diagnosed_at.desc()).limit(min(limit, 200)))
    if crop_id:
        stmt = stmt.where(Diagnosis.crop_id == crop_id)
    return [await to_out(db, d) for d in (await db.scalars(stmt)).all()]


@router.get("/{diag_id}", response_model=DiagnosisOut)
async def get_diagnosis(diag_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await to_out(db, await own(db, diag_id, user))


@router.delete("/{diag_id}", status_code=204)
async def hide_diagnosis(diag_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Tarixdan yashirish (TZ S07). Yozuv o'chirilmaydi: agronom javobi va dataset saqlanadi, /restore bilan qaytadi."""
    d = await own(db, diag_id, user)
    d.hidden_at = utcnow()
    await db.commit()


@router.post("/{diag_id}/restore", response_model=DiagnosisOut)
async def restore_diagnosis(diag_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    d = await own(db, diag_id, user)
    d.hidden_at = None
    await db.commit()
    await db.refresh(d)
    return await to_out(db, d)


@router.post("/{diag_id}/feedback", response_model=DiagnosisOut)
async def diagnosis_feedback(diag_id: uuid.UUID, body: FeedbackIn,
                             user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """"AI to'g'ri topdimi?" — xato deb belgilanganlar dataset tekshiruvida birinchi ko'rsatiladi."""
    d = await own(db, diag_id, user)
    d.user_feedback = body.correct
    await db.commit()
    return await to_out(db, d)


@router.post("/{diag_id}/request-review", response_model=DiagnosisOut)
async def request_review(diag_id: uuid.UUID, body: ReviewRequestIn | None = None,
                         user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """"Agronomga yuborish": tashxis agronomlar navbatida birinchi turadi; javob bildirishnoma bo'lib keladi."""
    d = await own(db, diag_id, user)
    if d.review_status != "pending":
        raise HTTPException(status.HTTP_409_CONFLICT, "Bu tashxisni agronom allaqachon tekshirgan")
    d.review_requested = True
    if body and body.note:
        d.review_note = body.note.strip()
    await db.commit()
    return await to_out(db, d)


@router.post("/{diag_id}/share", response_model=PostOut, status_code=201)
async def share_diagnosis(diag_id: uuid.UUID, body: ShareIn | None = None,
                          user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    d = await own(db, diag_id, user)
    disease = await db.get(Disease, d.disease_id) if d.disease_id else None
    body = body or ShareIn()
    default_title = f"{disease.name} aniqlandi" if disease else "O'simligim sog'lom"
    default_content = (
        f"AI tashxis qo'ydi: {disease.name.lower()}, {float(d.confidence or 0):.0f}% ishonch. {d.recommendations or ''}".strip()
        if disease else "AI tahlili bo'yicha o'simligim sog'lom."
    )
    post = Post(user_id=user.id, diagnosis_id=d.id, title=body.title or default_title,
                content=body.content or default_content, image_url=d.image_url,
                category="disease" if disease else "experience")
    db.add(post)
    await db.commit()
    await db.refresh(post)
    return await post_out(db, post, user)


async def _plan(db: AsyncSession, d: Diagnosis, start: date) -> CarePlanOut:
    disease = await db.get(Disease, d.disease_id) if d.disease_id else None
    plant = await db.get(Plant, d.plant_id) if d.plant_id else None
    meds = [(m.name, rec, m.label_verified) for m, rec in await DiseaseRepository(db).medicines_for(disease.id)] if disease else []
    healthy = disease is None and d.risk_level == "low"
    duration, tasks = build_plan(disease, plant, meds, healthy)
    return CarePlanOut(
        diagnosis_id=d.id, crop_id=d.crop_id, plant_id=d.plant_id, plant_name=plant.name if plant else None,
        disease_name=disease.name if disease else None, confidence=d.confidence, is_healthy=healthy,
        duration_days=duration,
        tasks=[CarePlanTask(day=t.day, date=t.on(start), time=t.at, title=t.title, description=t.description,
                            reminder_type=t.reminder_type) for t in tasks],
    )


@router.get("/{diag_id}/care-plan", response_model=CarePlanOut)
async def care_plan(diag_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Tashxis bo'yicha kunlik parvarish/davolash rejasi (ko'rish uchun, hech narsa saqlanmaydi)."""
    return await _plan(db, await own(db, diag_id, user), date.today())


@router.post("/{diag_id}/care-plan", response_model=CarePlanApplied, status_code=201)
async def apply_care_plan(diag_id: uuid.UUID, body: CarePlanApply | None = None,
                          user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Tashxisni "Mening bog'im"ga qo'shadi (mavjud yoki yangi ekin) va rejani eslatmalar sifatida saqlaydi."""
    d = await own(db, diag_id, user)
    body = body or CarePlanApply()

    crop_id = body.crop_id or d.crop_id
    if crop_id:
        crop = await db.get(Crop, crop_id)
        if crop is None or crop.user_id != user.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Ekin topilmadi")
    else:
        await ensure_can_add_crop(db, user)
        plant_id = body.plant_id or d.plant_id
        plant = await db.get(Plant, plant_id) if plant_id else None
        if plant_id and plant is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "O'simlik turi topilmadi")
        crop = Crop(user_id=user.id, plant_id=plant_id, name=body.crop_name or (plant.name if plant else "Ekin"),
                    variety=body.variety, location=body.location, planting_date=None)
        db.add(crop)
        await db.flush()

    if crop.plant_id is None and d.plant_id:
        crop.plant_id = d.plant_id
    d.crop_id = crop.id
    if d.plant_id is None:
        d.plant_id = crop.plant_id

    disease = await db.get(Disease, d.disease_id) if d.disease_id else None
    healthy = disease is None and d.risk_level == "low"
    score = health_from(disease, healthy, float(d.confidence or 0))
    if score is not None:
        crop.health_score = score

    # Shu tashxis bo'yicha avval yaratilgan, hali bajarilmagan eslatmalar yangi reja bilan almashtiriladi
    old = await db.scalars(select(Reminder).where(Reminder.diagnosis_id == d.id, Reminder.user_id == user.id,
                                                  Reminder.is_completed.is_(False)))
    for r in old.all():
        await db.delete(r)

    plan = await _plan(db, d, date.today())
    for t in plan.tasks:
        db.add(Reminder(user_id=user.id, crop_id=crop.id, diagnosis_id=d.id, title=t.title[:150], description=t.description,
                        reminder_type=t.reminder_type, reminder_date=t.date, reminder_time=t.time))
    summary = (f"AI tashxis: {disease.name} ({float(d.confidence or 0):.0f}%). " if disease else "AI tashxis: sog'lom. ")
    db.add(CropLog(crop_id=crop.id, user_id=user.id, image_url=d.image_url,
                   content=f"{summary}{plan.duration_days} kunlik parvarish rejasi boshlandi ({len(plan.tasks)} ta vazifa)."))
    await db.commit()
    return CarePlanApplied(crop_id=crop.id, reminders_created=len(plan.tasks))
