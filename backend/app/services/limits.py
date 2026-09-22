"""Feature-gating: is_premium orqali kunlik AI limit va ekin soni limiti."""
from datetime import datetime, time

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import utcnow
from app.models import AIChatMessage, Crop, Diagnosis, User


def _today_start() -> datetime:
    return datetime.combine(utcnow().date(), time.min)


async def diagnoses_today(db: AsyncSession, user: User) -> int:
    return await db.scalar(
        select(func.count()).select_from(Diagnosis).where(Diagnosis.user_id == user.id, Diagnosis.diagnosed_at >= _today_start())
    ) or 0


async def ai_chats_today(db: AsyncSession, user: User) -> int:
    return await db.scalar(
        select(func.count()).select_from(AIChatMessage).where(
            AIChatMessage.user_id == user.id, AIChatMessage.role == "user", AIChatMessage.created_at >= _today_start()
        )
    ) or 0


async def active_crops(db: AsyncSession, user: User) -> int:
    return await db.scalar(
        select(func.count()).select_from(Crop).where(Crop.user_id == user.id, Crop.status == "active")
    ) or 0


async def ensure_can_diagnose(db: AsyncSession, user: User) -> None:
    if user.is_premium:
        return
    if await diagnoses_today(db, user) >= settings.FREE_AI_DAILY_LIMIT:
        raise HTTPException(
            status.HTTP_402_PAYMENT_REQUIRED,
            f"Bepul rejada kuniga {settings.FREE_AI_DAILY_LIMIT} ta AI tashxis. Premium'ga o'ting.",
        )


async def ensure_can_chat(db: AsyncSession, user: User) -> int | None:
    if user.is_premium:
        return None
    used = await ai_chats_today(db, user)
    if used >= settings.FREE_AI_CHAT_DAILY_LIMIT:
        raise HTTPException(status.HTTP_402_PAYMENT_REQUIRED, "AI Yordamchi uchun kunlik bepul limit tugadi. Premium'ga o'ting.")
    return settings.FREE_AI_CHAT_DAILY_LIMIT - used - 1


async def ensure_can_add_crop(db: AsyncSession, user: User) -> None:
    if user.is_premium:
        return
    if await active_crops(db, user) >= settings.FREE_CROP_LIMIT:
        raise HTTPException(
            status.HTTP_402_PAYMENT_REQUIRED,
            f"Bepul rejada {settings.FREE_CROP_LIMIT} tagacha ekin qo'shish mumkin. Premium'ga o'ting.",
        )
