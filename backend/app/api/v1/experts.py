"""Agronom roli: arizalar, agronomlar ro'yxati, tashxislarni tekshirish navbati va agronom statistikasi."""
import uuid
from datetime import datetime, time

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.deps import EXPERT_ROLES, get_current_user, require_expert
from app.core.security import utcnow
from app.models import CatalogChange, Diagnosis, Disease, ExpertApplication, Plant, Question, QuestionMessage, User
from app.schemas.common import ORMModel
from app.services.diagnosis_service import is_healthy_label
from app.services.review_service import USABLE, apply_review

router = APIRouter(prefix="/experts", tags=["Agronomlar"])


# ---------- Schemas ----------
class ApplicationIn(BaseModel):
    specialization: str = Field(min_length=3, max_length=200)
    experience_years: int = Field(ge=0, le=60)
    about: str | None = Field(default=None, max_length=2000)
    document_url: str | None = Field(default=None, max_length=255)


class ApplicationOut(ORMModel):
    id: uuid.UUID
    user_id: uuid.UUID
    specialization: str
    experience_years: int
    about: str | None = None
    document_url: str | None = None
    status: str
    reason: str | None = None
    created_at: datetime | None = None
    reviewed_at: datetime | None = None


class ExpertOut(BaseModel):
    id: uuid.UUID
    full_name: str
    avatar_url: str | None = None
    region: str | None = None
    specialization: str | None = None
    accepting_questions: bool = True
    answers: int = 0
    rating: float | None = None
    work_hours: str | None = None
    district: str | None = None
    about: str | None = None
    experience_years: int | None = None
    education: str | None = None
    skills: list[str] | None = None
    ratings_count: int = 0


class ExpertSettingsIn(BaseModel):
    specialization: str | None = Field(default=None, min_length=3, max_length=200)
    accepting_questions: bool | None = None
    work_hours: str | None = Field(default=None, max_length=100)


class Alternative(BaseModel):
    """AI ning muqobil javobi: agronom bitta bosish bilan tanlaydi."""
    label: str
    confidence: float | None = None
    disease_id: uuid.UUID | None = None
    disease_name: str | None = None
    healthy: bool = False


class QueueItem(BaseModel):
    id: uuid.UUID
    image_url: str
    ai_label: str | None = None
    disease_name: str | None = None
    plant_id: uuid.UUID | None = None
    plant_name: str | None = None
    confidence: float | None = None
    alternatives: list[Alternative] = []
    review_requested: bool = False
    review_note: str | None = None
    farmer_name: str
    farmer_region: str | None = None
    diagnosed_at: datetime | None = None


class QueueReviewIn(BaseModel):
    status: str = Field(pattern=r"^(confirmed|corrected|rejected)$")
    label: str | None = Field(default=None, max_length=150)
    comment: str | None = Field(default=None, max_length=1000)


# ---------- Arizalar ----------
@router.post("/applications", response_model=ApplicationOut, status_code=201)
async def apply(body: ApplicationIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if user.role in EXPERT_ROLES:
        raise HTTPException(status.HTTP_409_CONFLICT, "Siz allaqachon agronomsiz")
    pending = await db.scalar(select(ExpertApplication.id).where(ExpertApplication.user_id == user.id,
                                                                  ExpertApplication.status == "pending"))
    if pending:
        raise HTTPException(status.HTTP_409_CONFLICT, "Arizangiz ko'rib chiqilmoqda")
    app_ = ExpertApplication(user_id=user.id, **body.model_dump())
    db.add(app_)
    await db.commit()
    await db.refresh(app_)
    return app_


@router.get("/applications/me", response_model=ApplicationOut | None)
async def my_application(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await db.scalar(select(ExpertApplication).where(ExpertApplication.user_id == user.id)
                           .order_by(ExpertApplication.created_at.desc()).limit(1))


# ---------- Agronomlar ro'yxati (dehqon uchun) ----------
async def _expert_out(db: AsyncSession, u: User) -> ExpertOut:
    answers = await db.scalar(select(func.count()).select_from(Question).where(Question.expert_id == u.id)) or 0
    rated = Question.expert_id == u.id, Question.rating.is_not(None)
    rating = await db.scalar(select(func.avg(Question.rating)).where(*rated))
    ratings_count = await db.scalar(select(func.count()).select_from(Question).where(*rated)) or 0
    return ExpertOut(id=u.id, full_name=u.full_name, avatar_url=u.avatar_url, region=u.region, specialization=u.specialization,
                     accepting_questions=u.accepting_questions, answers=answers, work_hours=u.work_hours,
                     rating=round(float(rating), 1) if rating is not None else None, ratings_count=ratings_count,
                     district=u.district, about=u.about, experience_years=u.experience_years, education=u.education,
                     skills=u.skills)


@router.get("", response_model=list[ExpertOut])
async def list_experts(_: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    users = (await db.scalars(select(User).where(User.role == "agronomist", User.is_active.is_(True))
                              .order_by(User.accepting_questions.desc(), User.full_name))).all()
    return [await _expert_out(db, u) for u in users]


@router.put("/me", response_model=ExpertOut)
async def update_me(body: ExpertSettingsIn, user: User = Depends(require_expert), db: AsyncSession = Depends(get_db)):
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(user, k, v)
    await db.commit()
    return await _expert_out(db, user)


# ---------- Tekshirish navbati ----------
@router.get("/queue", response_model=list[QueueItem])
async def queue(
    filter_: str = Query(default="all", alias="filter", pattern=r"^(all|requested|low)$"),
    limit: int = Query(default=30, le=100),
    offset: int = 0,
    _: User = Depends(require_expert),
    db: AsyncSession = Depends(get_db),
):
    """Tekshirilmagan tashxislar: avval dehqon so'raganlari, keyin ishonchi pastlari, keyin yangilari."""
    stmt = select(Diagnosis).where(Diagnosis.review_status == "pending")
    if filter_ == "requested":
        stmt = stmt.where(Diagnosis.review_requested.is_(True))
    elif filter_ == "low":
        stmt = stmt.where(Diagnosis.confidence < settings.AI_MIN_CONFIDENCE)
    stmt = stmt.order_by(case((Diagnosis.review_requested.is_(True), 0), else_=1), Diagnosis.confidence.asc(),
                         Diagnosis.diagnosed_at.desc())
    rows = (await db.scalars(stmt.limit(limit).offset(offset))).all()
    return [await _queue_item(db, d) for d in rows]


async def _queue_item(db: AsyncSession, d: Diagnosis) -> QueueItem:
    farmer = await db.get(User, d.user_id)
    disease = await db.get(Disease, d.disease_id) if d.disease_id else None
    plant = await db.get(Plant, d.plant_id) if d.plant_id else None
    conf = float(d.confidence) if d.confidence is not None else None
    top = d.ai_top or ([{"label": d.ai_label, "confidence": conf}] if d.ai_label else [])
    alts = []
    for t in top:
        dis = None if is_healthy_label(t["label"]) else await db.scalar(select(Disease).where(Disease.ai_label == t["label"]))
        alts.append(Alternative(label=t["label"], confidence=t.get("confidence"), disease_id=dis.id if dis else None,
                                disease_name=dis.name if dis else ("Sog'lom" if is_healthy_label(t["label"]) else None),
                                healthy=is_healthy_label(t["label"])))
    return QueueItem(
        id=d.id, image_url=d.image_url, ai_label=d.ai_label, disease_name=disease.name if disease else None,
        plant_id=d.plant_id, plant_name=plant.name if plant else None, confidence=conf, alternatives=alts,
        review_requested=d.review_requested, review_note=d.review_note,
        farmer_name=farmer.full_name.split(" ")[0] if farmer else "Dehqon", farmer_region=", ".join(x for x in (farmer.region, farmer.district) if x) or None if farmer else None,
        diagnosed_at=d.diagnosed_at,
    )


@router.get("/queue/{diag_id}", response_model=QueueItem)
async def queue_item(diag_id: uuid.UUID, _: User = Depends(require_expert), db: AsyncSession = Depends(get_db)):
    d = await db.get(Diagnosis, diag_id)
    if d is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tashxis topilmadi")
    return await _queue_item(db, d)


@router.post("/queue/{diag_id}", response_model=QueueItem | None)
async def review(diag_id: uuid.UUID, body: QueueReviewIn, reviewer: User = Depends(require_expert),
                 db: AsyncSession = Depends(get_db)):
    """Tasdiqlash / tuzatish / rad etish. Dehqonga bildirishnoma boradi. Javobda — navbatdagi keyingi tashxis."""
    d = await db.get(Diagnosis, diag_id)
    if d is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tashxis topilmadi")
    if d.review_status != "pending":
        raise HTTPException(status.HTTP_409_CONFLICT, "Bu tashxis allaqachon tekshirilgan")
    await apply_review(db, d, body.status, body.label, reviewer, comment=body.comment, notify_owner=True)
    await db.commit()
    nxt = await queue(filter_="all", limit=1, offset=0, _=reviewer, db=db)
    return nxt[0] if nxt else None


@router.get("/stats/me")
async def my_stats(user: User = Depends(require_expert), db: AsyncSession = Depends(get_db)):
    today = datetime.combine(utcnow().date(), time.min)
    reviewed = select(func.count()).select_from(Diagnosis).where(Diagnosis.reviewed_by == user.id)
    total = await db.scalar(reviewed) or 0
    confirmed = await db.scalar(reviewed.where(Diagnosis.review_status == "confirmed")) or 0
    corrected = await db.scalar(reviewed.where(Diagnosis.review_status == "corrected")) or 0
    me = await _expert_out(db, user)
    # O'rtacha javob vaqti: savol berilgandan agronomning birinchi xabarigacha
    first = (await db.execute(
        select(Question.created_at, func.min(QuestionMessage.created_at))
        .join(QuestionMessage, QuestionMessage.question_id == Question.id)
        .where(Question.expert_id == user.id, QuestionMessage.sender_id == user.id)
        .group_by(Question.id, Question.created_at))).all()
    waits = [(b - a).total_seconds() / 60 for a, b in first if a and b]
    return {
        "reviewed_today": await db.scalar(reviewed.where(Diagnosis.reviewed_at >= today)) or 0,
        "reviewed_total": total,
        "ai_agreement": round(confirmed / (confirmed + corrected) * 100) if (confirmed + corrected) else None,
        "queue_pending": await db.scalar(select(func.count()).select_from(Diagnosis).where(Diagnosis.review_status == "pending")) or 0,
        "questions_new": await db.scalar(select(func.count()).select_from(Question).where(Question.status == "new")) or 0,
        "answers": me.answers,
        "rating": me.rating,
        "ratings_count": await db.scalar(select(func.count()).select_from(Question).where(
            Question.expert_id == user.id, Question.rating.is_not(None))) or 0,
        "avg_answer_minutes": round(sum(waits) / len(waits)) if waits else None,
    }


# ---------- Bilimlar bazasi: o'zgarishlar tarixi va datasetdan rasm ----------
class ChangeOut(BaseModel):
    id: uuid.UUID
    user_name: str | None = None
    mine: bool = False
    entity: str
    entity_id: uuid.UUID | None = None
    action: str
    summary: str
    created_at: datetime | None = None


@router.get("/catalog-changes", response_model=list[ChangeOut])
async def catalog_changes(mine: bool = False, limit: int = Query(default=50, le=200),
                          user: User = Depends(require_expert), db: AsyncSession = Depends(get_db)):
    """Agronomlar bilimlar bazasiga kiritgan o'zgarishlar (admin panelda qaytarish mumkin)."""
    stmt = select(CatalogChange).order_by(CatalogChange.created_at.desc()).limit(limit)
    if mine:
        stmt = stmt.where(CatalogChange.user_id == user.id)
    out = []
    for c in (await db.scalars(stmt)).all():
        u = await db.get(User, c.user_id) if c.user_id else None
        out.append(ChangeOut(id=c.id, user_name=u.full_name if u else None, mine=c.user_id == user.id, entity=c.entity,
                             entity_id=c.entity_id, action=c.action, summary=c.summary, created_at=c.created_at))
    return out


class DatasetImage(BaseModel):
    id: uuid.UUID
    image_url: str
    review_status: str


@router.get("/dataset-images", response_model=list[DatasetImage])
async def dataset_images(label: str = Query(min_length=3, max_length=150), limit: int = Query(default=24, le=60),
                         _: User = Depends(require_expert), db: AsyncSession = Depends(get_db)):
    """Agronom tasdiqlagan dala rasmlari — rasmi yo'q kasallik uchun ma'lumotnoma rasmini tanlashda."""
    rows = (await db.scalars(select(Diagnosis).where(Diagnosis.verified_label == label, Diagnosis.review_status.in_(USABLE))
                             .order_by(Diagnosis.reviewed_at.desc()).limit(limit))).all()
    return [DatasetImage(id=d.id, image_url=d.image_url, review_status=d.review_status) for d in rows]


# Oxirida turadi: "/queue" kabi yo'llarni {expert_id} yutib yubormasligi uchun
@router.get("/{expert_id}", response_model=ExpertOut)
async def get_expert(expert_id: uuid.UUID, _: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    u = await db.get(User, expert_id)
    if u is None or u.role != "agronomist" or not u.is_active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Agronom topilmadi")
    return await _expert_out(db, u)
