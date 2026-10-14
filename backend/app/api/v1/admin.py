import secrets
import uuid
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import require_admin, require_superadmin
from app.core.security import hash_password, utcnow
from app.models import CatalogChange, RefreshToken, Comment, Crop, Diagnosis, Disease, ExpertApplication, Post, Question, Report, Subscription, User
from app.api.v1.experts import ApplicationOut
from app.schemas.user import UserMe
from app.services.app_settings import audit
from app.services.notification_service import notify

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


class AdminUserOut(UserMe):
    diagnoses: int = 0
    crops: int = 0


async def _user_out(db: AsyncSession, u: User) -> AdminUserOut:
    return AdminUserOut(**UserMe.model_validate(u).model_dump(), diagnoses=await _count(db, Diagnosis, Diagnosis.user_id == u.id),
                        crops=await _count(db, Crop, Crop.user_id == u.id))


@router.get("/users", response_model=list[AdminUserOut])
async def list_users(q: str | None = None, role: str | None = Query(default=None, pattern=r"^(user|agronomist|moderator|admin)$"),
                     blocked: bool = False, limit: int = Query(default=50, le=200), offset: int = 0,
                     db: AsyncSession = Depends(get_db)):
    stmt = select(User).order_by(User.created_at.desc()).limit(limit).offset(offset)
    if role:
        stmt = stmt.where(User.role == role)
    if blocked:
        stmt = stmt.where(User.is_active.is_(False))
    if q:
        stmt = stmt.where(or_(User.full_name.ilike(f"%{q}%"), User.username.ilike(f"%{q}%"), User.region.ilike(f"%{q}%"),
                              User.email.ilike(f"%{q}%"), User.phone.ilike(f"%{q}%")))
    return [await _user_out(db, u) for u in (await db.scalars(stmt)).all()]


@router.get("/users/count")
async def users_count(db: AsyncSession = Depends(get_db)):
    return {"total": await _count(db, User), "blocked": await _count(db, User, User.is_active.is_(False))}


@router.put("/users/{user_id}/block", response_model=AdminUserOut)
async def toggle_block(user_id: uuid.UUID, blocked: bool = True, reason: str | None = Query(default=None, max_length=255),
                       admin: User = Depends(require_superadmin), db: AsyncSession = Depends(get_db)):
    u = await db.get(User, user_id)
    if u is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Foydalanuvchi topilmadi")
    if u.role == "admin":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Adminni bloklab bo'lmaydi")
    u.is_active = not blocked
    await audit(db, admin, "block" if blocked else "unblock",
                f"«{u.full_name}» {'bloklandi' + (': ' + reason if reason else '') if blocked else 'blokdan chiqarildi'}", u.id)
    await db.commit()
    await db.refresh(u)
    return await _user_out(db, u)


# Chalkashtiriladigan belgilarsiz (0/O, 1/l/I): telefonda aytib berish oson
_PW_ALPHABET = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def temp_password() -> str:
    part = lambda: "".join(secrets.choice(_PW_ALPHABET) for _ in range(4))  # noqa: E731
    return f"{part()}-{part()}-{part()}"


@router.post("/users/{user_id}/reset-password")
async def reset_password(user_id: uuid.UUID, admin: User = Depends(require_superadmin), db: AsyncSession = Depends(get_db)):
    """Vaqtinchalik parol: faqat shu javobda bir marta ko'rsatiladi, bazada hash holida.
    Foydalanuvchining barcha seanslari tugatiladi."""
    u = await db.get(User, user_id)
    if u is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Foydalanuvchi topilmadi")
    if u.id == admin.id or u.role == "admin":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Admin parolini faqat serverdan (create_admin) almashtirish mumkin")
    password = temp_password()
    u.password_hash = hash_password(password)
    await db.execute(update(RefreshToken).where(RefreshToken.user_id == u.id).values(revoked=True))
    await notify(db, u.id, "password_reset", "Parolingiz yangilandi",
                 "Administrator sizga vaqtinchalik parol berdi. Kirgach, Profil → «Parolni o'zgartirish» orqali o'zingiznikini qo'ying.")
    await audit(db, admin, "password_reset", f"«{u.full_name}» (@{u.username}) uchun vaqtinchalik parol berildi", u.id)
    await db.commit()
    return {"username": u.username, "full_name": u.full_name, "password": password}


class RoleIn(BaseModel):
    role: str = Field(pattern=r"^(user|agronomist|moderator|admin)$")


@router.put("/users/{user_id}/role", response_model=UserMe)
async def set_role(user_id: uuid.UUID, body: RoleIn, admin: User = Depends(require_superadmin), db: AsyncSession = Depends(get_db)):
    u = await db.get(User, user_id)
    if u is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Foydalanuvchi topilmadi")
    if u.id == admin.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "O'z rolingizni o'zgartira olmaysiz")
    old = u.role
    u.role = body.role
    await audit(db, admin, "role", f"«{u.full_name}»: rol {old} → {body.role}", u.id)
    await db.commit()
    await db.refresh(u)
    return u


# ---------- Agronom arizalari ----------
class RejectIn(BaseModel):
    reason: str = Field(min_length=3, max_length=255)


class ApplicationAdminOut(ApplicationOut):
    full_name: str
    region: str | None = None
    phone: str | None = None


async def _app_out(db: AsyncSession, a: ExpertApplication) -> ApplicationAdminOut:
    u = await db.get(User, a.user_id)
    return ApplicationAdminOut(**ApplicationOut.model_validate(a).model_dump(), full_name=u.full_name, region=u.region, phone=u.phone)


async def _pending_app(db: AsyncSession, app_id: uuid.UUID) -> ExpertApplication:
    a = await db.get(ExpertApplication, app_id)
    if a is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Ariza topilmadi")
    if a.status != "pending":
        raise HTTPException(status.HTTP_409_CONFLICT, "Ariza allaqachon ko'rib chiqilgan")
    return a


@router.get("/expert-applications", response_model=list[ApplicationAdminOut])
async def expert_applications(status_: str = Query(default="pending", alias="status", pattern=r"^(pending|approved|rejected|all)$"),
                              db: AsyncSession = Depends(get_db)):
    stmt = select(ExpertApplication).order_by(ExpertApplication.created_at.asc())
    if status_ != "all":
        stmt = stmt.where(ExpertApplication.status == status_)
    return [await _app_out(db, a) for a in (await db.scalars(stmt)).all()]


@router.post("/expert-applications/{app_id}/approve", response_model=ApplicationAdminOut)
async def approve_application(app_id: uuid.UUID, admin: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    a = await _pending_app(db, app_id)
    u = await db.get(User, a.user_id)
    a.status, a.reviewed_by, a.reviewed_at = "approved", admin.id, utcnow()
    if u.role == "user":
        u.role = "agronomist"
    u.specialization = a.specialization
    # Arizadagi ma'lumotlar agronom profiliga o'tadi (agar u o'zi to'ldirmagan bo'lsa)
    u.about = u.about or a.about
    if u.experience_years is None:
        u.experience_years = a.experience_years
    await notify(db, u.id, "expert_approved", "Siz endi agronomsiz",
                 "Ilovani qayta oching — agronom rejimi yoqildi.", a.id)
    await audit(db, admin, "expert_approve", f"«{u.full_name}» agronom bo'ldi ({a.specialization})", u.id)
    await db.commit()
    return await _app_out(db, a)


@router.post("/expert-applications/{app_id}/reject", response_model=ApplicationAdminOut)
async def reject_application(app_id: uuid.UUID, body: RejectIn, admin: User = Depends(require_admin),
                             db: AsyncSession = Depends(get_db)):
    a = await _pending_app(db, app_id)
    a.status, a.reason, a.reviewed_by, a.reviewed_at = "rejected", body.reason, admin.id, utcnow()
    await notify(db, a.user_id, "expert_rejected", "Agronom arizangiz rad etildi", body.reason, a.id)
    u = await db.get(User, a.user_id)
    await audit(db, admin, "expert_reject", f"«{u.full_name if u else '?'}» arizasi rad etildi: {body.reason}", a.user_id)
    await db.commit()
    return await _app_out(db, a)


# ---------- Bilimlar bazasi jurnali va agronomlar ko'rsatkichlari ----------
class CatalogChangeOut(BaseModel):
    id: uuid.UUID
    user_name: str | None = None
    user_role: str | None = None
    entity: str
    entity_id: uuid.UUID | None = None
    action: str
    summary: str
    created_at: str | None = None
    revertible: bool = False
    reverted: bool = False


@router.get("/catalog-changes", response_model=list[CatalogChangeOut])
async def catalog_changes(limit: int = Query(default=50, le=200), db: AsyncSession = Depends(get_db)):
    rows = (await db.scalars(select(CatalogChange).order_by(CatalogChange.created_at.desc()).limit(limit))).all()
    out = []
    for c in rows:
        u = await db.get(User, c.user_id) if c.user_id else None
        out.append(CatalogChangeOut(id=c.id, user_name=u.full_name if u else None, user_role=u.role if u else None,
                                    entity=c.entity, entity_id=c.entity_id, action=c.action, summary=c.summary,
                                    created_at=c.created_at.isoformat() if c.created_at else None,
                                    revertible=bool(c.before) and c.reverted_at is None, reverted=c.reverted_at is not None))
    return out


@router.get("/stats/experts")
async def expert_stats(db: AsyncSession = Depends(get_db)):
    stale = utcnow() - timedelta(hours=4)
    reviewed = (Diagnosis.review_status.in_(("confirmed", "corrected")), Diagnosis.reviewed_by.is_not(None))
    confirmed = await _count(db, Diagnosis, Diagnosis.review_status == "confirmed", Diagnosis.reviewed_by.is_not(None))
    total = await _count(db, Diagnosis, *reviewed)
    return {
        "agronomists": await _count(db, User, User.role == "agronomist"),
        "applications_pending": await _count(db, ExpertApplication, ExpertApplication.status == "pending"),
        "queue_pending": await _count(db, Diagnosis, Diagnosis.review_status == "pending"),
        "queue_requested": await _count(db, Diagnosis, Diagnosis.review_status == "pending", Diagnosis.review_requested.is_(True)),
        "questions_new": await _count(db, Question, Question.status == "new"),
        "questions_stale": await _count(db, Question, Question.status == "new", Question.created_at < stale),
        "ai_agreement": round(confirmed / total * 100) if total else None,
    }
