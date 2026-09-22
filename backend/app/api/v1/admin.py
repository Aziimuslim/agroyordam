import uuid
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import require_admin, require_superadmin
from app.core.security import utcnow
from app.models import Comment, Crop, Diagnosis, Disease, Post, Report, Subscription, User
from app.schemas.user import UserMe

router = APIRouter(prefix="/admin", tags=["Admin"], dependencies=[Depends(require_admin)])


async def _count(db: AsyncSession, model, *where) -> int:
    return await db.scalar(select(func.count()).select_from(model).where(*where)) or 0


@router.get("/stats/platform")
async def platform_stats(db: AsyncSession = Depends(get_db)):
    week = utcnow() - timedelta(days=7)
    return {
        "users_total": await _count(db, User),
        "users_new_7d": await _count(db, User, User.created_at >= week),
        "premium_users": await _count(db, User, User.is_premium.is_(True)),
        "crops_total": await _count(db, Crop),
        "posts_total": await _count(db, Post),
        "comments_total": await _count(db, Comment),
        "reports_pending": await _count(db, Report, Report.status == "pending"),
    }


@router.get("/stats/ai")
async def ai_stats(db: AsyncSession = Depends(get_db)):
    week = utcnow() - timedelta(days=7)
    total = await _count(db, Diagnosis)
    avg_conf = await db.scalar(select(func.avg(Diagnosis.confidence)))
    top = (await db.execute(
        select(Disease.name, func.count(Diagnosis.id).label("n")).join(Diagnosis, Diagnosis.disease_id == Disease.id)
        .group_by(Disease.name).order_by(func.count(Diagnosis.id).desc()).limit(5)
    )).all()
    return {
        "diagnoses_total": total,
        "diagnoses_7d": await _count(db, Diagnosis, Diagnosis.diagnosed_at >= week),
        "unrecognized": await _count(db, Diagnosis, Diagnosis.disease_id.is_(None)),
        "avg_confidence": round(float(avg_conf or 0), 2),
        "top_diseases": [{"name": n, "count": c} for n, c in top],
    }


@router.get("/stats/revenue")
async def revenue_stats(db: AsyncSession = Depends(get_db)):
    paid = (Subscription.status.in_(("active", "expired", "cancelled")), Subscription.external_txn_id.is_not(None))
    total = await db.scalar(select(func.coalesce(func.sum(Subscription.price), 0)).where(*paid))
    by_provider = (await db.execute(
        select(Subscription.payment_provider, func.count(), func.coalesce(func.sum(Subscription.price), 0))
        .where(*paid).group_by(Subscription.payment_provider)
    )).all()
    return {
        "revenue_total": float(total or 0),
        "currency": "UZS",
        "active_subscriptions": await _count(db, Subscription, Subscription.status == "active"),
        "by_provider": [{"provider": p, "count": c, "amount": float(a)} for p, c, a in by_provider],
    }


@router.get("/users", response_model=list[UserMe])
async def list_users(q: str | None = None, limit: int = Query(default=50, le=200), offset: int = 0,
                     db: AsyncSession = Depends(get_db)):
    stmt = select(User).order_by(User.created_at.desc()).limit(limit).offset(offset)
    if q:
        stmt = stmt.where(or_(User.full_name.ilike(f"%{q}%"), User.username.ilike(f"%{q}%"),
                              User.email.ilike(f"%{q}%"), User.phone.ilike(f"%{q}%")))
    return list((await db.scalars(stmt)).all())


@router.put("/users/{user_id}/block", response_model=UserMe, dependencies=[Depends(require_superadmin)])
async def toggle_block(user_id: uuid.UUID, blocked: bool = True, db: AsyncSession = Depends(get_db)):
    u = await db.get(User, user_id)
    if u is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Foydalanuvchi topilmadi")
    if u.role == "admin":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Adminni bloklab bo'lmaydi")
    u.is_active = not blocked
    await db.commit()
    await db.refresh(u)
    return u
