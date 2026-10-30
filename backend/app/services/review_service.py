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
# "Rasm yetarli emas" sabablari → dehqonga aniq qayta surat ko'rsatmasi (Agronom TZ Y02)
RETAKE_REASONS = {
    "blurry": "Rasm xira chiqqan",
    "far": "Juda uzoqdan olingan",
    "wrong_part": "Noto'g'ri organ yoki ekin suratga olingan",
    "no_context": "Tashxis uchun kontekst yetarli emas",
    "other": "Boshqa sabab",
}


async def apply_review(db: AsyncSession, d: Diagnosis, status_: str, label: str | None, reviewer: User,
                       comment: str | None = None, notify_owner: bool = False, source: str | None = None,
                       retake_reason: str | None = None) -> None:
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
    d.expert_source = (source or "").strip() or None if status_ != "pending" else None
    d.retake_reason = retake_reason if status_ == "rejected" else None
    d.review_claimed_by = d.review_claimed_at = None

    if notify_owner and status_ != "pending" and d.user_id != reviewer.id:
        title = {"confirmed": "Agronom tashxisni tasdiqladi", "corrected": "Agronom tashxisni tuzatdi",
                 "rejected": "Agronom: rasmni qayta oling"}[status_]
        body = d.expert_comment
        if status_ == "rejected" and d.retake_reason in RETAKE_REASONS:
            body = f"{RETAKE_REASONS[d.retake_reason]}. {d.expert_comment or ''}".strip()
        await notify(db, d.user_id, "diagnosis_reviewed", title, body, d.id)


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
