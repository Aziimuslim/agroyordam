import uuid

from datetime import date

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import Crop, CropLog, Diagnosis, Disease, Plant, Post, Reminder, User
from app.repositories.catalog_repo import DiseaseRepository
from app.schemas.community import PostOut
from app.schemas.diagnosis import CarePlanApplied, CarePlanApply, CarePlanOut, CarePlanTask, DiagnosisOut, FeedbackIn, ShareIn
from app.services.care_plan import build_plan
from app.services.community_service import post_out
from app.services.diagnosis_service import health_from, run_diagnosis, to_out
from app.services.limits import ensure_can_add_crop

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


@router.get("", response_model=list[DiagnosisOut])
async def list_diagnoses(crop_id: uuid.UUID | None = None, limit: int = 50,
                         user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(Diagnosis).where(Diagnosis.user_id == user.id).order_by(Diagnosis.diagnosed_at.desc()).limit(min(limit, 200))
    if crop_id:
        stmt = stmt.where(Diagnosis.crop_id == crop_id)
    return [await to_out(db, d) for d in (await db.scalars(stmt)).all()]


@router.get("/{diag_id}", response_model=DiagnosisOut)
async def get_diagnosis(diag_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await to_out(db, await own(db, diag_id, user))


@router.delete("/{diag_id}", status_code=204)
async def delete_diagnosis(diag_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await db.delete(await own(db, diag_id, user))
    await db.commit()


@router.post("/{diag_id}/feedback", response_model=DiagnosisOut)
async def diagnosis_feedback(diag_id: uuid.UUID, body: FeedbackIn,
                             user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """"AI to'g'ri topdimi?" — xato deb belgilanganlar dataset tekshiruvida birinchi ko'rsatiladi."""
    d = await own(db, diag_id, user)
    d.user_feedback = body.correct
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
    meds = [(m.name, rec) for m, rec in await DiseaseRepository(db).medicines_for(disease.id)] if disease else []
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
