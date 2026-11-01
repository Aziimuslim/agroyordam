"""Admin panel (Tabiiy Agro dizayni) uchun qo'shimcha ma'lumotlar.

Hamma raqamlar bazadan hisoblanadi — maketdagi namuna qiymatlar ishlatilmaydi. Ma'lumot bo'lmasa `None` qaytadi
va panel uni "Noma'lum" / "—" deb ko'rsatadi.
"""
import os
import re
import time
import uuid
from datetime import timedelta
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.alphabet import search_variants
from app.core.config import settings
from app.core.database import get_db
from app.core.deps import require_admin
from app.core.security import utcnow
from app.models import (
    AnalysisJob,
    AuditLog,
    CatalogChange,
    Comment,
    Crop,
    Diagnosis,
    Disease,
    DiseaseMedicine,
    ExpertApplication,
    Medicine,
    Message,
    Plant,
    Post,
    Question,
    RefreshToken,
    Report,
    Subscription,
    User,
)
from app.services.app_settings import audit

router = APIRouter(prefix="/admin", tags=["Admin panel"], dependencies=[Depends(require_admin)])


async def _count(db: AsyncSession, model, *where) -> int:
    return await db.scalar(select(func.count()).select_from(model).where(*where)) or 0


def mask_phone(p: str | None) -> str | None:
    """+998 90 123 45 67 → +998 90 *** ** 67"""
    if not p:
        return None
    d = re.sub(r"\D", "", p)
    return f"+{d[:5]} *** ** {d[-2:]}" if len(d) >= 9 else "***"


def mask_email(e: str | None) -> str | None:
    if not e or "@" not in e:
        return None
    name, dom = e.split("@", 1)
    return f"{name[:1]}***@{dom}"


def _is_sandbox(s: Subscription) -> bool:
    return bool(s.external_txn_id and s.external_txn_id.startswith("sandbox-"))


# ---------- Foydalanuvchilar ----------
_last_active = select(RefreshToken.user_id, func.max(RefreshToken.created_at).label("at")).group_by(RefreshToken.user_id).subquery()


@router.get("/users/stats")
async def users_stats(db: AsyncSession = Depends(get_db)):
    """Jami, faol (30 kunda kirgan), nofaol, yangi (30 kun, oldingi 30 kun bilan) va bloklanganlar; filtr uchun viloyatlar."""
    now = utcnow()
    m30, m60 = now - timedelta(days=30), now - timedelta(days=60)
    total = await _count(db, User)
    active = await db.scalar(select(func.count()).select_from(_last_active).where(_last_active.c.at >= m30)) or 0
    regions = [r for (r,) in (await db.execute(select(User.region).where(User.region.is_not(None)).distinct().order_by(User.region))).all()]
    return {
        "total": total, "active": active, "inactive": max(0, total - active),
        "new": await _count(db, User, User.created_at >= m30), "new_prev": await _count(db, User, User.created_at >= m60, User.created_at < m30),
        "blocked": await _count(db, User, User.is_active.is_(False)), "regions": regions,
    }


@router.get("/users/page")
async def users_page(q: str | None = Query(default=None, max_length=100),
                     role: str | None = Query(default=None, pattern=r"^(user|agronomist|moderator|admin)$"),
                     state: str = Query(default="all", pattern=r"^(all|active|inactive|blocked)$"),
                     region: str | None = Query(default=None, max_length=100),
                     plan: str = Query(default="all", pattern=r"^(all|premium|free)$"),
                     sort: str = Query(default="new", pattern=r"^(new|old|name|active)$"),
                     limit: int = Query(default=25, ge=1, le=100), offset: int = Query(default=0, ge=0),
                     db: AsyncSession = Depends(get_db)):
    """Sahifalangan ro'yxat (25/50/100) va filtrlangan jami soni. Telefon/email niqoblangan."""
    m30 = utcnow() - timedelta(days=30)
    stmt = select(User, _last_active.c.at).outerjoin(_last_active, _last_active.c.user_id == User.id)
    if role:
        stmt = stmt.where(User.role == role)
    if state == "blocked":
        stmt = stmt.where(User.is_active.is_(False))
    elif state == "active":
        stmt = stmt.where(User.is_active.is_(True), _last_active.c.at >= m30)
    elif state == "inactive":
        stmt = stmt.where(User.is_active.is_(True), or_(_last_active.c.at.is_(None), _last_active.c.at < m30))
    if region:
        stmt = stmt.where(User.region == region)
    if plan != "all":
        stmt = stmt.where(User.is_premium.is_(plan == "premium"))
    if q:
        like = f"%{q.strip()}%"
        stmt = stmt.where(or_(*[User.full_name.ilike(f"%{v}%") for v in search_variants(q.strip())], User.username.ilike(like), User.region.ilike(like),
                              User.email.ilike(like), User.phone.ilike(like)))
    total = await db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    order = {"new": User.created_at.desc(), "old": User.created_at.asc(), "name": User.full_name.asc(),
             "active": _last_active.c.at.desc().nulls_last()}[sort]
    rows = (await db.execute(stmt.order_by(order, User.id).limit(limit).offset(offset))).all()
    ids = [u.id for u, _ in rows]
    diag = dict((await db.execute(select(Diagnosis.user_id, func.count()).where(Diagnosis.user_id.in_(ids))
                                  .group_by(Diagnosis.user_id))).all()) if ids else {}
    sandbox_premium = set()
    if ids:
        for uid, txn in (await db.execute(select(Subscription.user_id, Subscription.external_txn_id)
                                          .where(Subscription.user_id.in_(ids), Subscription.status == "active"))).all():
            if txn and txn.startswith("sandbox-"):
                sandbox_premium.add(uid)
    items = []
    for u, last in rows:
        items.append({
            "id": u.id, "full_name": u.full_name, "username": u.username, "avatar_url": u.avatar_url,
            "phone_masked": mask_phone(u.phone), "email_masked": mask_email(u.email),
            "region": u.region, "district": u.district, "role": u.role, "is_active": u.is_active,
            "is_premium": u.is_premium,
            "premium_source": None if not u.is_premium else ("sandbox" if u.id in sandbox_premium else "paid"),
            "diagnoses": diag.get(u.id, 0), "created_at": u.created_at, "last_active": last,
        })
    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.get("/users/{user_id}/detail")
async def user_detail(user_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """Profil drawer: umumiy, faollik, obuna, cheklovlar va audit. Parol hech qachon qaytarilmaydi."""
    u = await db.get(User, user_id)
    if u is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Foydalanuvchi topilmadi")
    last = await db.scalar(select(func.max(RefreshToken.created_at)).where(RefreshToken.user_id == u.id))
    subs = (await db.scalars(select(Subscription).where(Subscription.user_id == u.id).order_by(Subscription.created_at.desc()).limit(20))).all()
    audit_rows = (await db.execute(select(AuditLog, User.full_name).outerjoin(User, User.id == AuditLog.actor_id)
                                   .where(AuditLog.target_id == u.id).order_by(AuditLog.created_at.desc()).limit(30))).all()
    app = await db.scalar(select(ExpertApplication).where(ExpertApplication.user_id == u.id).order_by(ExpertApplication.created_at.desc()).limit(1))
    reports_against = 0
    for col, model in ((Report.post_id, Post), (Report.comment_id, Comment)):
        reports_against += await db.scalar(select(func.count()).select_from(Report).join(model, model.id == col)
                                           .where(model.user_id == u.id)) or 0
    return {
        "id": u.id, "full_name": u.full_name, "username": u.username, "avatar_url": u.avatar_url,
        "phone": u.phone, "email": u.email, "phone_masked": mask_phone(u.phone), "email_masked": mask_email(u.email),
        "region": u.region, "district": u.district, "role": u.role, "is_active": u.is_active,
        "is_premium": u.is_premium, "premium_until": u.premium_until, "farm_type": u.farm_type, "farm_area": u.farm_area,
        "main_crops": u.main_crops or [], "specialization": u.specialization, "experience_years": u.experience_years,
        "language": u.language, "created_at": u.created_at, "last_active": last,
        "activity": {
            "diagnoses": await _count(db, Diagnosis, Diagnosis.user_id == u.id),
            "crops": await _count(db, Crop, Crop.user_id == u.id),
            "posts": await _count(db, Post, Post.user_id == u.id),
            "comments": await _count(db, Comment, Comment.user_id == u.id, Comment.deleted_at.is_(None)),
            "questions": await _count(db, Question, Question.user_id == u.id),
            "reports_against": reports_against,
        },
        "subscriptions": [{"id": s.id, "plan": s.plan, "status": s.status, "price": float(s.price or 0), "currency": s.currency,
                           "provider": s.payment_provider, "sandbox": _is_sandbox(s), "paid": s.external_txn_id is not None,
                           "created_at": s.created_at, "expires_at": s.expires_at} for s in subs],
        "expert_application": {"status": app.status, "specialization": app.specialization, "created_at": app.created_at,
                               "reason": app.reason} if app else None,
        "audit": [{"actor": n or "Tizim", "action": a.action, "summary": a.summary, "created_at": a.created_at} for a, n in audit_rows],
    }


# ---------- Tashxislar (boshqaruv paneli, AI tekshiruv navbati) ----------
@router.get("/diagnoses")
async def diagnoses_list(scope: str = Query(default="recent", pattern=r"^(recent|queue)$"),
                         limit: int = Query(default=8, ge=1, le=60), db: AsyncSession = Depends(get_db)):
    """recent — so'nggi tashxislar; queue — dehqon agronom tekshiruvini so'ragan, hali ko'rilmagan tashxislar."""
    stmt = (select(Diagnosis, Disease.name, Plant.name, User.region, User.full_name)
            .outerjoin(Disease, Disease.id == Diagnosis.disease_id).outerjoin(Plant, Plant.id == Diagnosis.plant_id)
            .join(User, User.id == Diagnosis.user_id).where(Diagnosis.hidden_at.is_(None)))
    where = (Diagnosis.review_status == "pending", Diagnosis.review_requested.is_(True))
    if scope == "queue":
        stmt = stmt.where(*where).order_by(Diagnosis.diagnosed_at.asc())
    else:
        stmt = stmt.order_by(Diagnosis.diagnosed_at.desc())
    out = []
    for d, dn, pn, region, uname in (await db.execute(stmt.limit(limit))).all():
        out.append({"id": d.id, "image_url": d.image_url, "disease": dn or ("Sog'lom" if (d.ai_label or "").endswith("healthy") else None),
                    "ai_label": d.ai_label, "confidence": float(d.confidence) if d.confidence is not None else None,
                    "plant": pn, "region": region, "user": uname, "review_status": d.review_status,
                    "review_requested": d.review_requested, "user_feedback": d.user_feedback, "review_note": d.review_note,
                    "verified_label": d.verified_label, "created_at": d.diagnosed_at})
    return {"items": out, "queue_total": await _count(db, Diagnosis, *where, Diagnosis.hidden_at.is_(None))}


# ---------- Bilimlar bazasi: to'liqlik va oxirgi o'zgarish ----------
_KB = {
    "diseases": (Disease, (("description", "Tavsif"), ("symptoms", "Belgilar"), ("treatment", "Davolash"), ("prevention", "Oldini olish"))),
    "plants": (Plant, (("description", "Tavsif"), ("care_info", "Parvarish"))),
    "medicines": (Medicine, (("active_ingredient", "Faol modda"), ("usage", "Qo'llash"), ("precautions", "Ehtiyot choralari"))),
}
_KB_ENTITY = {"diseases": "disease", "plants": "plant", "medicines": "medicine"}
# Ilovaga o'rnatilgan katalog rasmlari (mobile/assets/catalog/<ai_label>.jpg) — image_url bo'lmasa ham rasm bor
CATALOG_IMAGES = frozenset({
    "Apple_Black_rot", "Apple_Cedar_rust", "Apple_Scab", "Apple_healthy",
    "Cherry_Powdery_mildew", "Cherry_healthy", "Corn_Common_rust", "Corn_Gray_leaf_spot",
    "Corn_Northern_Leaf_Blight", "Corn_healthy", "Grape_Black_rot", "Grape_Esca",
    "Grape_Leaf_blight", "Grape_healthy", "Peach_Bacterial_spot", "Peach_healthy",
    "Pepper_Bacterial_spot", "Pepper_healthy", "Potato_Early_blight", "Potato_Late_blight",
    "Potato_healthy", "Squash_Powdery_mildew", "Strawberry_Leaf_scorch", "Strawberry_healthy",
    "Tomato_Bacterial_spot", "Tomato_Early_blight", "Tomato_Late_blight", "Tomato_Leaf_Mold",
    "Tomato_Septoria_leaf_spot", "Tomato_Spider_mites", "Tomato_Target_Spot", "Tomato_Yellow_Leaf_Curl_Virus",
    "Tomato_healthy", "Tomato_mosaic_virus",
})


@router.get("/kb/list/{kind}")
async def kb_list(kind: str, db: AsyncSession = Depends(get_db)):
    """Har yozuv: rasmi bormi, yetishmayotgan majburiy maydonlar, holat va oxirgi o'zgarish (kim, qachon)."""
    if kind not in _KB:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Noma'lum bo'lim")
    model, fields = _KB[kind]
    last: dict = {}
    for c, name in (await db.execute(select(CatalogChange, User.full_name).outerjoin(User, User.id == CatalogChange.user_id)
                                      .where(CatalogChange.entity == _KB_ENTITY[kind]).order_by(CatalogChange.created_at.desc()))).all():
        last.setdefault(c.entity_id, {"by": name, "at": c.created_at, "summary": c.summary})
    plants = dict((await db.execute(select(Plant.id, Plant.name))).all())
    meds = dict((await db.execute(select(DiseaseMedicine.disease_id, func.count()).group_by(DiseaseMedicine.disease_id))).all()) if kind == "diseases" else {}
    used = dict((await db.execute(select(DiseaseMedicine.medicine_id, func.count()).group_by(DiseaseMedicine.medicine_id))).all()) if kind == "medicines" else {}
    out = []
    for o in (await db.scalars(select(model).order_by(model.name))).all():
        missing = [t for f, t in fields if not (getattr(o, f) or "").strip()]
        if kind == "diseases" and not meds.get(o.id):
            missing.append("Dorilar")
        has_image = bool(o.image_url) or (kind == "diseases" and o.ai_label in CATALOG_IMAGES)
        lc = last.get(o.id) or {}
        row = {"id": o.id, "name": o.name, "image_url": o.image_url, "has_image": has_image, "missing": missing,
               "state": "no_image" if not has_image else "incomplete" if missing else "complete",
               "updated_at": lc.get("at") or getattr(o, "updated_at", None) or o.created_at, "updated_by": lc.get("by"),
               "source": getattr(o, "source", None)}
        if kind == "diseases":
            row |= {"plant": plants.get(o.plant_id), "ai_label": o.ai_label, "risk_level": o.risk_level, "medicines": meds.get(o.id, 0),
                    "description": o.description, "symptoms": o.symptoms, "treatment": o.treatment, "prevention": o.prevention}
        elif kind == "plants":
            row |= {"scientific_name": o.scientific_name, "category": o.category, "description": o.description, "care_info": o.care_info}
        else:
            row |= {"active_ingredient": o.active_ingredient, "category": o.category, "label_verified": o.label_verified,
                    "used_in": used.get(o.id, 0), "usage": o.usage, "precautions": o.precautions, "manufacturer": o.manufacturer}
        out.append(row)
    summary = {s: sum(1 for r in out if r["state"] == s) for s in ("complete", "incomplete", "no_image")}
    return {"items": out, "summary": summary, "total": len(out)}


# ---------- Jamoat moderatsiyasi ----------
_KIND_MODEL = {"post": Post, "comment": Comment, "message": Message}


def _key(r: Report) -> tuple[str, uuid.UUID]:
    return ("comment", r.comment_id) if r.comment_id else ("message", r.message_id) if r.message_id else ("post", r.post_id)


@router.get("/moderation")
async def moderation(tab: str = Query(default="open", pattern=r"^(open|review|closed)$"), db: AsyncSession = Depends(get_db)):
    """Ochiq (pending), Ko'rib chiqilmoqda (reviewing) va Yopilgan (jurnaldagi qarorlar). Shikoyatchi da'vosi alohida."""
    counts = {"open": 0, "review": 0, "closed": await _count(db, AuditLog, AuditLog.action.in_(("report_hide", "report_dismiss")))}
    groups: dict[tuple, dict] = {}
    want = {"open": "pending", "review": "reviewing"}.get(tab)
    for r in (await db.scalars(select(Report).where(Report.status.in_(("pending", "reviewing"))).order_by(Report.created_at.desc()))).all():
        key = _key(r)
        g = groups.get(key)
        if g is None:
            target = await db.get(_KIND_MODEL[key[0]], key[1])
            if target is None or (key[0] == "comment" and target.deleted_at is not None):
                continue
            owner = target.sender_id if key[0] == "message" else target.user_id
            author = await db.get(User, owner)
            title = target.title if key[0] == "post" else None
            body = target.content or ""
            image = None
            if key[0] == "post":
                image = (target.image_urls or [None])[0] if target.image_urls else target.image_url
            elif key[0] == "message":
                image = getattr(target, "image_url", None)
            g = groups[key] = {"kind": key[0], "target_id": key[1], "title": title, "text": body[:600], "image_url": image,
                               "author": author.full_name if author else None, "author_id": owner,
                               "created_at": getattr(target, "created_at", None), "reasons": {}, "claims": [], "count": 0,
                               "first_at": r.created_at, "last_at": r.created_at, "status": "pending", "reviewed_at": None}
        g["count"] += 1
        g["first_at"] = min(g["first_at"], r.created_at)
        reason = r.reason or "Ko'rsatilmagan"
        g["reasons"][reason] = g["reasons"].get(reason, 0) + 1
        if r.description and len(g["claims"]) < 5:
            g["claims"].append(r.description[:300])
        if r.status == "reviewing":
            g["status"] = "reviewing"
            g["reviewed_at"] = r.reviewed_at
    for g in groups.values():
        counts["open" if g["status"] == "pending" else "review"] += 1
        g["reasons"] = [{"reason": k, "count": v} for k, v in sorted(g["reasons"].items(), key=lambda kv: -kv[1])]
    if tab == "closed":
        rows = (await db.execute(select(AuditLog, User.full_name).outerjoin(User, User.id == AuditLog.actor_id)
                                 .where(AuditLog.action.in_(("report_hide", "report_dismiss"))).order_by(AuditLog.created_at.desc()).limit(100))).all()
        items = [{"id": a.id, "decision": "hidden" if a.action == "report_hide" else "dismissed", "summary": a.summary,
                  "moderator": n or "Tizim", "created_at": a.created_at} for a, n in rows]
    else:
        items = sorted((g for g in groups.values() if g["status"] == want), key=lambda g: g["last_at"], reverse=True)
    return {"tab": tab, "counts": counts, "items": items}


class ReviewIn(BaseModel):
    kind: str = Field(pattern=r"^(post|comment|message)$")
    target_id: uuid.UUID


_RCOL = {"post": Report.post_id, "comment": Report.comment_id, "message": Report.message_id}


@router.post("/moderation/start")
async def moderation_start(body: ReviewIn, admin: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    """Shikoyatni "Ko'rib chiqilmoqda" holatiga o'tkazadi (boshqa moderatorlar ko'radi)."""
    n = 0
    for r in (await db.scalars(select(Report).where(_RCOL[body.kind] == body.target_id, Report.status == "pending"))).all():
        r.status, r.reviewed_at = "reviewing", utcnow()
        n += 1
    if not n:
        raise HTTPException(status.HTTP_409_CONFLICT, "Ochiq shikoyat topilmadi (allaqachon ko'rib chiqilayotgan bo'lishi mumkin)")
    await audit(db, admin, "report_review", f"Shikoyat ko'rib chiqila boshlandi ({n} ta)", body.target_id)
    await db.commit()
    return {"ok": True, "reports": n}


# ---------- To'lovlar: tranzaksiyalar va obunalar ----------
@router.get("/payments/list")
async def payments_list(limit: int = Query(default=200, ge=1, le=500), db: AsyncSession = Depends(get_db)):
    """Barcha obuna/to'lov yozuvlari (muhit — sinov yoki haqiqiy), KPI'lar shu ro'yxatdan hisoblanadi."""
    now = utcnow()
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    rows = (await db.execute(select(Subscription, User.full_name, User.username).join(User, User.id == Subscription.user_id)
                             .order_by(Subscription.created_at.desc()).limit(limit))).all()
    items = []
    for s, name, uname in rows:
        items.append({"id": s.id, "order": str(s.id)[:8].upper(), "user": name, "username": uname, "user_id": s.user_id,
                      "plan": s.plan, "status": s.status, "amount": float(s.price or 0), "currency": s.currency,
                      "provider": s.payment_provider, "paid": s.external_txn_id is not None, "sandbox": _is_sandbox(s),
                      "created_at": s.created_at, "paid_at": s.paid_at, "expires_at": s.expires_at, "refunded_at": s.refunded_at,
                      "auto_renew": s.auto_renew})
    live_paid = [i for i in items if i["paid"] and not i["sandbox"] and i["status"] in ("active", "expired") and not i["refunded_at"]]
    return {
        "mode": settings.PAYMENT_MODE,
        "kpi": {
            "live_revenue_month": sum(i["amount"] for i in live_paid if i["created_at"] and i["created_at"] >= month_start),
            "live_revenue_total": sum(i["amount"] for i in live_paid),
            "sandbox_active": sum(1 for i in items if i["status"] == "active" and i["sandbox"]),
            "live_active": sum(1 for i in items if i["status"] == "active" and i["paid"] and not i["sandbox"]),
            "cancelled_30d": await _count(db, Subscription, Subscription.status == "cancelled", Subscription.updated_at >= now - timedelta(days=30)),
        },
        "items": items,
    }


# ---------- Tizim monitoringi ----------
def _read(path: str) -> str | None:
    try:
        return Path(path).read_text()
    except OSError:
        return None


def _host() -> dict:
    """CPU (1 daqiqalik yuklama / yadro), xotira va uptime — /proc dan; o'qib bo'lmasa None."""
    out: dict = {"cpu_pct": None, "mem_pct": None, "mem_total_gb": None, "uptime_s": None}
    try:
        out["cpu_pct"] = min(100, round(os.getloadavg()[0] / (os.cpu_count() or 1) * 100))
    except (OSError, AttributeError):
        pass
    mi = _read("/proc/meminfo")
    if mi:
        kv = {k: int(v.split()[0]) for k, v in (ln.split(":", 1) for ln in mi.splitlines() if ":" in ln) if v.split()}
        if kv.get("MemTotal") and kv.get("MemAvailable") is not None:
            out["mem_pct"] = round((1 - kv["MemAvailable"] / kv["MemTotal"]) * 100)
            out["mem_total_gb"] = round(kv["MemTotal"] / 1048576, 1)
    up = _read("/proc/uptime")
    if up:
        out["uptime_s"] = int(float(up.split()[0]))
    return out


@router.get("/system/monitor")
async def system_monitor(db: AsyncSession = Depends(get_db)):
    """Server, ma'lumotlar bazasi va fon ishlari holati. Har qiymat real manbadan; bo'lmasa None."""
    t0 = time.perf_counter()
    db_info: dict = {"ok": False, "dialect": db.bind.dialect.name if db.bind else None, "version": None, "size_bytes": None,
                     "tables": None, "connections": None, "max_connections": None, "latency_ms": None}
    try:
        await db.execute(select(1))
        db_info["ok"] = True
        db_info["latency_ms"] = round((time.perf_counter() - t0) * 1000, 1)
        if db_info["dialect"] == "postgresql":
            db_info["version"] = (await db.scalar(text("SHOW server_version"))) or None
            db_info["size_bytes"] = await db.scalar(text("SELECT pg_database_size(current_database())"))
            db_info["tables"] = await db.scalar(text("SELECT count(*) FROM information_schema.tables WHERE table_schema='public'"))
            db_info["connections"] = await db.scalar(text("SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()"))
            db_info["max_connections"] = int(await db.scalar(text("SHOW max_connections")))
        elif db_info["dialect"] == "sqlite":
            db_info["version"] = "SQLite " + (await db.scalar(text("select sqlite_version()")) or "")
            db_info["tables"] = await db.scalar(text("SELECT count(*) FROM sqlite_master WHERE type='table'"))
            path = settings.DATABASE_URL.split("///", 1)[-1]
            db_info["size_bytes"] = Path(path).stat().st_size if path and Path(path).exists() else None
    except Exception:  # noqa: BLE001 — monitoring hech qachon 500 bermasin
        pass
    jobs = dict((await db.execute(select(AnalysisJob.status, func.count()).group_by(AnalysisJob.status))).all()) if db_info["ok"] else {}
    import shutil
    du = shutil.disk_usage("/")
    return {
        "checked_at": utcnow(), "version": settings.APP_VERSION, "environment": settings.ENVIRONMENT,
        "host": _host() | {"disk_pct": round(du.used / du.total * 100), "disk_free_gb": round(du.free / 1e9, 1), "disk_total_gb": round(du.total / 1e9, 1)},
        "database": db_info,
        "jobs": {"queued": jobs.get("queued", 0), "processing": jobs.get("processing", 0) + jobs.get("finishing", 0), "failed": jobs.get("failed", 0),
                 "done": jobs.get("done", 0)},
    }


# ---------- Harakatlar jurnali (sahifalangan, filtr bilan) ----------
@router.get("/audit/page")
async def audit_page(q: str | None = Query(default=None, max_length=100), action: str | None = Query(default=None, max_length=40),
                     limit: int = Query(default=25, ge=1, le=100), offset: int = Query(default=0, ge=0), db: AsyncSession = Depends(get_db)):
    stmt = select(AuditLog, User.full_name).outerjoin(User, User.id == AuditLog.actor_id)
    if action:
        stmt = stmt.where(AuditLog.action == action)
    if q:
        stmt = stmt.where(or_(AuditLog.summary.ilike(f"%{q}%"), User.full_name.ilike(f"%{q}%")))
    total = await db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = (await db.execute(stmt.order_by(AuditLog.created_at.desc()).limit(limit).offset(offset))).all()
    actions = [a for (a,) in (await db.execute(select(AuditLog.action).distinct().order_by(AuditLog.action))).all()]
    return {"items": [{"id": a.id, "actor": n or "Tizim", "action": a.action, "target_id": a.target_id, "summary": a.summary,
                       "created_at": a.created_at} for a, n in rows], "total": total, "actions": actions}
