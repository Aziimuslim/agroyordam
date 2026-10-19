"""A08 Bloklash: kim kimni bloklagan bo'lsa ham ikkalasi bir-birini ko'rmaydi va yozisha olmaydi."""
import uuid

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import UserBlock

BLOCKED_MSG = "Bu foydalanuvchi bilan yozishib bo'lmaydi"


async def hidden_ids(db: AsyncSession, user_id: uuid.UUID) -> set[uuid.UUID]:
    """Men bloklaganlar va meni bloklaganlar."""
    rows = await db.execute(select(UserBlock.blocker_id, UserBlock.blocked_id).where(
        or_(UserBlock.blocker_id == user_id, UserBlock.blocked_id == user_id)))
    return {b if a == user_id else a for a, b in rows.all()}


async def between(db: AsyncSession, a: uuid.UUID, b: uuid.UUID) -> bool:
    return bool(await db.scalar(select(UserBlock.id).where(or_(
        (UserBlock.blocker_id == a) & (UserBlock.blocked_id == b),
        (UserBlock.blocker_id == b) & (UserBlock.blocked_id == a),
    )).limit(1)))


async def i_blocked(db: AsyncSession, me: uuid.UUID, other: uuid.UUID) -> bool:
    return bool(await db.scalar(select(UserBlock.id).where(UserBlock.blocker_id == me, UserBlock.blocked_id == other)))
