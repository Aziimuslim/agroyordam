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
from app.models import Diagnosis, Disease, ExpertApplication, Plant, Question, User
from app.schemas.common import ORMModel
from app.services.review_service import apply_review

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


class ExpertSettingsIn(BaseModel):
    specialization: str | None = Field(default=None, min_length=3, max_length=200)
    accepting_questions: bool | None = None


class QueueItem(BaseModel):
    id: uuid.UUID
    image_url: str
    ai_label: str | None = None
    disease_name: str | None = None
    plant_name: str | None = None
    confidence: float | None = None
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
    rating = await db.scalar(select(func.avg(Question.rating)).where(Question.expert_id == u.id, Question.rating.is_not(None)))
    return ExpertOut(id=u.id, full_name=u.full_name, avatar_url=u.avatar_url, region=u.region, specialization=u.specialization,
                     accepting_questions=u.accepting_questions, answers=answers,
                     rating=round(float(rating), 1) if rating is not None else None)


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
    out = []
    for d in rows:
        farmer = await db.get(User, d.user_id)
        disease = await db.get(Disease, d.disease_id) if d.disease_id else None
        plant = await db.get(Plant, d.plant_id) if d.plant_id else None
        out.append(QueueItem(
            id=d.id, image_url=d.image_url, ai_label=d.ai_label, disease_name=disease.name if disease else None,
            plant_name=plant.name if plant else None, confidence=float(d.confidence) if d.confidence is not None else None,
            review_requested=d.review_requested, review_note=d.review_note,
            farmer_name=farmer.full_name.split(" ")[0] if farmer else "Dehqon", farmer_region=farmer.region if farmer else None,
            diagnosed_at=d.diagnosed_at,
        ))
    return out


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
    return {
        "reviewed_today": await db.scalar(reviewed.where(Diagnosis.reviewed_at >= today)) or 0,
        "reviewed_total": total,
        "ai_agreement": round(confirmed / (confirmed + corrected) * 100) if (confirmed + corrected) else None,
        "queue_pending": await db.scalar(select(func.count()).select_from(Diagnosis).where(Diagnosis.review_status == "pending")) or 0,
        "questions_new": await db.scalar(select(func.count()).select_from(Question).where(Question.status == "new")) or 0,
        "answers": me.answers,
        "rating": me.rating,
    }
