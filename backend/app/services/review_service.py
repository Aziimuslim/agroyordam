"""Tashxisni mutaxassis tekshiruvi — admin dataset bo'limi va agronom navbati uchun umumiy mantiq."""
import re

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import utcnow
from app.models import Diagnosis, Disease, User
from app.services.diagnosis_service import is_healthy_label
from app.services.notification_service import notify

LABEL_RE = re.compile(r"^[A-Z][A-Za-z]*_[A-Za-z0-9_]+$")
USABLE = ("confirmed", "corrected")


async def apply_review(db: AsyncSession, d: Diagnosis, status_: str, label: str | None, reviewer: User,
                       comment: str | None = None, notify_owner: bool = False) -> None:
    """status_: confirmed | corrected | rejected | pending. Tuzatilganda dehqonning tashxisi ham yangilanadi."""
    if status_ == "confirmed":
        label = d.ai_label or (await db.scalar(select(Disease.ai_label).where(Disease.id == d.disease_id)) if d.disease_id else None)
        if not label:
            raise HTTPException(422, "AI sinfi yo'q — to'g'ri sinfni tanlab \"corrected\" qiling")
        d.verified_label = label
    elif status_ == "corrected":
        if not label or not LABEL_RE.match(label):
            raise HTTPException(422, "Sinf nomi Ekin_Kasallik ko'rinishida bo'lsin (masalan Tomato_Late_blight)")
        d.verified_label = label
        await _relabel(db, d, label)
    else:
        d.verified_label = None
    d.review_status = status_
    d.reviewed_by = reviewer.id if status_ != "pending" else None
    d.reviewed_at = utcnow() if status_ != "pending" else None
    if comment is not None:
        d.expert_comment = comment.strip() or None

    if notify_owner and status_ != "pending" and d.user_id != reviewer.id:
        title = {"confirmed": "Agronom tashxisni tasdiqladi", "corrected": "Agronom tashxisni tuzatdi",
                 "rejected": "Agronom: rasmni qayta oling"}[status_]
        await notify(db, d.user_id, "diagnosis_reviewed", title, d.expert_comment, d.id)


async def _relabel(db: AsyncSession, d: Diagnosis, label: str) -> None:
    """Dehqon ko'radigan tashxisni agronom tanlagan kasallikka almashtiradi (asl AI javobi ai_label'da qoladi)."""
    if is_healthy_label(label):
        d.disease_id, d.risk_level, d.symptoms, d.causes = None, "low", None, None
        d.recommendations = "O'simlik sog'lom. Parvarishni davom ettiring."
        return
    disease = await db.scalar(select(Disease).where(Disease.ai_label == label))
    if disease is None:
        return  # bilimlar bazasida yo'q sinf (dataset uchun baribir saqlanadi)
    d.disease_id, d.risk_level = disease.id, disease.risk_level
    d.symptoms, d.causes, d.recommendations = disease.symptoms, disease.causes, disease.treatment
    if disease.plant_id:
        d.plant_id = disease.plant_id
