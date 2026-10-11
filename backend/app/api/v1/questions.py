"""Dehqon ↔ agronom savollari (konsultatsiya).

Dehqon savol beradi (ekin, tashxis, rasm biriktiriladi) → agronomlar ro'yxatida "new" → birinchi javob bergan agronom
savolni oladi ("answered") → dehqon yoki agronom yopadi ("closed") → dehqon baholaydi.
Bepul rejada oyiga FREE_QUESTIONS_PER_MONTH ta savol, Premium'da cheksiz.
"""
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.deps import EXPERT_ROLES, get_current_user, require_expert
from app.core.security import utcnow
from app.models import Crop, Diagnosis, Disease, Medicine, Question, QuestionMessage, User
from app.schemas.user import UserPublic
from app.services.notification_service import notify

router = APIRouter(prefix="/questions", tags=["Savollar"])


class QuestionIn(BaseModel):
    title: str = Field(min_length=3, max_length=200)
    body: str | None = Field(default=None, max_length=4000)
    crop_id: uuid.UUID | None = None
    diagnosis_id: uuid.UUID | None = None
    image_url: str | None = Field(default=None, max_length=255)


class MessageIn(BaseModel):
    body: str | None = Field(default=None, max_length=4000)
    medicine_id: uuid.UUID | None = None
    image_url: str | None = Field(default=None, max_length=255)


class RateIn(BaseModel):
    rating: int = Field(ge=1, le=5)


class MedicineCard(BaseModel):
    id: uuid.UUID
    name: str
    usage: str | None = None


class MessageOut(BaseModel):
    id: uuid.UUID
    sender: UserPublic
    body: str | None = None
    medicine: MedicineCard | None = None
    image_url: str | None = None
    created_at: datetime | None = None


class QuestionOut(BaseModel):
    id: uuid.UUID
    author: UserPublic
    expert: UserPublic | None = None
    title: str
    body: str | None = None
    image_url: str | None = None
    crop_id: uuid.UUID | None = None
    crop_name: str | None = None
    diagnosis_id: uuid.UUID | None = None
    diagnosis_name: str | None = None
    diagnosis_confidence: float | None = None
    status: str
    rating: int | None = None
    messages_count: int = 0
    created_at: datetime | None = None
    updated_at: datetime | None = None


class QuestionDetail(QuestionOut):
    messages: list[MessageOut] = []


class Quota(BaseModel):
    used: int
    limit: int | None  # None — cheksiz (Premium)
    remaining: int | None


def _month_start() -> datetime:
    n = utcnow()
    return datetime(n.year, n.month, 1)


async def _quota(db: AsyncSession, user: User) -> Quota:
    used = await db.scalar(select(func.count()).select_from(Question).where(
        Question.user_id == user.id, Question.created_at >= _month_start())) or 0
    if user.is_premium:
        return Quota(used=used, limit=None, remaining=None)
    lim = settings.FREE_QUESTIONS_PER_MONTH
    return Quota(used=used, limit=lim, remaining=max(0, lim - used))


async def _out(db: AsyncSession, q: Question, detail: bool = False) -> QuestionOut | QuestionDetail:
    author = await db.get(User, q.user_id)
    expert = await db.get(User, q.expert_id) if q.expert_id else None
    crop = await db.get(Crop, q.crop_id) if q.crop_id else None
    diag = await db.get(Diagnosis, q.diagnosis_id) if q.diagnosis_id else None
    disease = await db.get(Disease, diag.disease_id) if diag and diag.disease_id else None
    count = await db.scalar(select(func.count()).select_from(QuestionMessage).where(QuestionMessage.question_id == q.id)) or 0
    data = dict(
        id=q.id, author=UserPublic.model_validate(author), expert=UserPublic.model_validate(expert) if expert else None,
        title=q.title, body=q.body, image_url=q.image_url or (diag.image_url if diag else None),
        crop_id=q.crop_id, crop_name=crop.name if crop else None, diagnosis_id=q.diagnosis_id,
        diagnosis_name=disease.name if disease else (("Sog'lom" if diag.risk_level == "low" else None) if diag else None),
        diagnosis_confidence=float(diag.confidence) if diag and diag.confidence is not None else None,
        status=q.status, rating=q.rating, messages_count=count, created_at=q.created_at, updated_at=q.updated_at,
    )
    if not detail:
        return QuestionOut(**data)
    msgs = (await db.scalars(select(QuestionMessage).where(QuestionMessage.question_id == q.id)
                             .order_by(QuestionMessage.created_at, QuestionMessage.id))).all()
    out = []
    for m in msgs:
        sender = await db.get(User, m.sender_id)
        med = await db.get(Medicine, m.medicine_id) if m.medicine_id else None
        out.append(MessageOut(id=m.id, sender=UserPublic.model_validate(sender), body=m.body, image_url=m.image_url,
                              medicine=MedicineCard(id=med.id, name=med.name, usage=med.usage) if med else None,
                              created_at=m.created_at))
    return QuestionDetail(**data, messages=out)


async def _get(db: AsyncSession, qid: uuid.UUID, user: User) -> Question:
    q = await db.get(Question, qid)
    if q is None or (q.user_id != user.id and user.role not in EXPERT_ROLES):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Savol topilmadi")
    return q


@router.get("/quota", response_model=Quota)
async def quota(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await _quota(db, user)


@router.post("", response_model=QuestionDetail, status_code=201)
async def ask(body: QuestionIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    qt = await _quota(db, user)
    if qt.remaining == 0:
        raise HTTPException(status.HTTP_402_PAYMENT_REQUIRED,
                            f"Bepul rejada oyiga {qt.limit} ta savol. Premium'da agronomga cheksiz savol berasiz.")
    if body.crop_id:
        crop = await db.get(Crop, body.crop_id)
        if crop is None or crop.user_id != user.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Ekin topilmadi")
    if body.diagnosis_id:
        d = await db.get(Diagnosis, body.diagnosis_id)
        if d is None or d.user_id != user.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Tashxis topilmadi")
        d.review_requested = True  # savolga biriktirilgan tashxis tekshirish navbatida ham birinchi turadi
    q = Question(user_id=user.id, **body.model_dump())
    db.add(q)
    await db.commit()
    await db.refresh(q)
    return await _out(db, q, detail=True)


@router.get("/mine", response_model=list[QuestionOut])
async def mine(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    rows = (await db.scalars(select(Question).where(Question.user_id == user.id).order_by(Question.updated_at.desc()))).all()
    return [await _out(db, q) for q in rows]


@router.get("", response_model=list[QuestionOut])
async def for_experts(
    status_: str = Query(default="new", alias="status", pattern=r"^(new|answered|closed|mine|closed_mine)$"),
    limit: int = Query(default=30, le=100),
    offset: int = 0,
    user: User = Depends(require_expert),
    db: AsyncSession = Depends(get_db),
):
    """Agronom uchun: yangi (hech kim javob bermagan), javob berilgan, yopilgan yoki o'zi olganlari."""
    stmt = select(Question)
    if status_ == "mine":
        stmt = stmt.where(Question.expert_id == user.id, Question.status != "closed")
    elif status_ == "closed_mine":
        stmt = stmt.where(Question.expert_id == user.id, Question.status == "closed")
    else:
        stmt = stmt.where(Question.status == status_)
    order = Question.created_at.asc() if status_ == "new" else Question.updated_at.desc()
    rows = (await db.scalars(stmt.order_by(order).limit(limit).offset(offset))).all()
    return [await _out(db, q) for q in rows]


@router.get("/{qid}", response_model=QuestionDetail)
async def read(qid: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await _out(db, await _get(db, qid, user), detail=True)


@router.post("/{qid}/messages", response_model=QuestionDetail, status_code=201)
async def send(qid: uuid.UUID, body: MessageIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    q = await _get(db, qid, user)
    if q.status == "closed":
        raise HTTPException(status.HTTP_409_CONFLICT, "Savol yopilgan")
    if not (body.body and body.body.strip()) and not body.medicine_id and not body.image_url:
        raise HTTPException(422, "Xabar bo'sh")
    if body.medicine_id and await db.get(Medicine, body.medicine_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Dori topilmadi")
    is_owner = q.user_id == user.id
    if not is_owner:
        if q.expert_id and q.expert_id != user.id and user.role == "agronomist":
            raise HTTPException(status.HTTP_409_CONFLICT, "Bu savolga boshqa agronom javob bermoqda")
        if q.expert_id is None:
            q.expert_id = user.id
        q.status = "answered"
    db.add(QuestionMessage(question_id=q.id, sender_id=user.id, body=(body.body or "").strip() or None,
                           medicine_id=body.medicine_id, image_url=body.image_url))
    q.updated_at = utcnow()
    target = q.expert_id if is_owner else q.user_id
    if target:
        await notify(db, target, "question_message", "Agronom javob berdi" if not is_owner else "Dehqon yozdi",
                     (body.body or "Dori tavsiyasi")[:140], q.id)
    await db.commit()
    return await _out(db, q, detail=True)


@router.post("/{qid}/close", response_model=QuestionOut)
async def close(qid: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    q = await _get(db, qid, user)
    if q.user_id != user.id and q.expert_id not in (None, user.id) and user.role == "agronomist":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Ruxsat yo'q")
    q.status = "closed"
    q.updated_at = utcnow()
    if q.user_id != user.id:
        await notify(db, q.user_id, "question_closed", "Savolingiz hal bo'ldi", "Agronom javobini baholang", q.id)
    await db.commit()
    return await _out(db, q)


@router.post("/{qid}/rate", response_model=QuestionOut)
async def rate(qid: uuid.UUID, body: RateIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    q = await db.get(Question, qid)
    if q is None or q.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Savol topilmadi")
    if q.expert_id is None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Hali agronom javob bermagan")
    q.rating = body.rating
    if q.status != "closed":
        q.status = "closed"
    await db.commit()
    return await _out(db, q)
