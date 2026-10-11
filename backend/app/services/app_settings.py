"""Admin paneldan o'zgartiriladigan sozlamalar: tariflar va bepul limitlar.

Bazada qiymat bo'lmasa — config (.env) dagi standart qiymat ishlatiladi.
"""
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models import AppSetting, AuditLog, User

# kalit → (sarlavha, standart qiymat, min, max)
EDITABLE: dict[str, tuple[str, int, int, int]] = {
    "price_monthly": ("Premium — 1 oy, so'm", 25000, 1000, 10_000_000),
    "price_yearly": ("Premium — 1 yil, so'm", 250000, 1000, 100_000_000),
    "price_lifetime": ("Premium — umrbod, so'm", 590000, 1000, 100_000_000),
    "free_ai_daily": ("Bepul: AI tashxis kuniga", settings.FREE_AI_DAILY_LIMIT, 0, 100),
    "free_questions_month": ("Bepul: agronomga savol oyiga", settings.FREE_QUESTIONS_PER_MONTH, 0, 100),
}


async def get_int(db: AsyncSession, key: str) -> int:
    row = await db.get(AppSetting, key)
    if row is not None:
        try:
            return int(row.value)
        except ValueError:
            pass
    return EDITABLE[key][1]


async def plan_price(db: AsyncSession, plan_code: str, default: Decimal) -> Decimal:
    key = f"price_{plan_code}"
    return Decimal(await get_int(db, key)) if key in EDITABLE else default


async def all_settings(db: AsyncSession) -> list[dict]:
    return [{"key": k, "title": t, "value": await get_int(db, k), "default": d, "min": lo, "max": hi}
            for k, (t, d, lo, hi) in EDITABLE.items()]


async def audit(db: AsyncSession, actor: User | None, action: str, summary: str, target_id=None) -> None:
    """Admin harakatini jurnalga yozadi (commit chaqiruvchida)."""
    db.add(AuditLog(actor_id=actor.id if actor else None, action=action, target_id=target_id, summary=summary[:500]))
