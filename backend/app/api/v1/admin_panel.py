"""Admin web panel (/admin) uchun: boshqaruv paneli, agronomlar, AI va dataset, bilimlar bazasini qaytarish,
moderatsiya, to'lovlar va sozlamalar, tizim (zaxira), ommaviy xabar, harakatlar jurnali."""
import shutil
import uuid
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.deps import require_admin, require_superadmin
from app.core.security import utcnow
from app.models import (
    AppSetting, AuditLog, CatalogChange, Comment, Diagnosis, Disease, DiseaseMedicine, ExpertApplication, Medicine, Message, Plant, Post,
    Question, QuestionMessage, Report, Subscription, User,
)
from app.api.v1.dataset import field_split
from app.services import model_ops
from app.services.ai_client import AIServiceError, get_ai_client
from app.services.review_service import USABLE
from app.services.app_settings import EDITABLE, all_settings, audit, get_int
from app.services.community_service import remove_comment
from app.services.notification_service import notify

router = APIRouter(prefix="/admin", tags=["Admin panel"], dependencies=[Depends(require_admin)])
REVIEWED = ("confirmed", "corrected")


async def _count(db: AsyncSession, model, *where) -> int:
    return await db.scalar(select(func.count()).select_from(model).where(*where)) or 0


def _daily(stamps: list[datetime], start: datetime, days: int) -> list[dict]:
    c = Counter(s.date() for s in stamps if s)
    return [{"date": (start + timedelta(days=i + 1)).date().isoformat(), "count": c.get((start + timedelta(days=i + 1)).date(), 0)}
            for i in range(days)]


async def _agreement(db: AsyncSession, *where) -> tuple[int | None, int]:
    rows = dict((await db.execute(select(Diagnosis.review_status, func.count()).where(
        Diagnosis.review_status.in_(REVIEWED), Diagnosis.reviewed_by.is_not(None), *where).group_by(Diagnosis.review_status))).all())
    total = rows.get("confirmed", 0) + rows.get("corrected", 0)
    return (round(rows.get("confirmed", 0) / total * 100) if total else None), total


# ---------- Boshqaruv paneli ----------
@router.get("/dashboard")
async def dashboard(days: int = Query(default=30, ge=7, le=180), db: AsyncSession = Depends(get_db)):
    now = utcnow()
    start, prev = now - timedelta(days=days), now - timedelta(days=2 * days)
    diag_stamps = (await db.scalars(select(Diagnosis.diagnosed_at).where(Diagnosis.diagnosed_at >= start))).all()
    user_stamps = (await db.scalars(select(User.created_at).where(User.created_at >= start))).all()
    agree, reviewed = await _agreement(db, Diagnosis.reviewed_at >= start)
    agree_prev, _ = await _agreement(db, Diagnosis.reviewed_at >= prev, Diagnosis.reviewed_at < start)

    regions = Counter(dict((await db.execute(select(User.region, func.count()).group_by(User.region))).all()))
    top = [(r or "Ko'rsatilmagan", n) for r, n in regions.most_common(7)]
    rest = sum(regions.values()) - sum(n for _, n in top)
    if rest > 0:
        top.append(("Boshqalar", rest))

    per_crop: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for name, st, n in (await db.execute(
            select(Plant.name, Diagnosis.review_status, func.count()).join(Plant, Plant.id == Diagnosis.plant_id)
            .where(Diagnosis.review_status.in_(REVIEWED), Diagnosis.reviewed_by.is_not(None))
            .group_by(Plant.name, Diagnosis.review_status))).all():
        per_crop[name][0 if st == "confirmed" else 1] += n
    crop_acc = sorted(({"crop": k, "accuracy": round(c / (c + x) * 100), "reviewed": c + x} for k, (c, x) in per_crop.items()),
                      key=lambda r: -r["accuracy"])

    oldest_app = await db.scalar(select(func.min(ExpertApplication.created_at)).where(ExpertApplication.status == "pending"))
    return {
        "days": days,
        "users_new": len(user_stamps),
        "users_new_prev": await _count(db, User, User.created_at >= prev, User.created_at < start),
        "users_total": await _count(db, User),
        "diagnoses": len(diag_stamps),
        "diagnoses_prev": await _count(db, Diagnosis, Diagnosis.diagnosed_at >= prev, Diagnosis.diagnosed_at < start),
        "diagnoses_daily": _daily(diag_stamps, start, days),
        "users_daily": _daily(user_stamps, start, days),
        "ai_agreement": agree,
        "ai_agreement_prev": agree_prev,
        "reviewed": reviewed,
        "premium_active": await _count(db, User, User.is_premium.is_(True)),
        "premium_new": await _count(db, Subscription, Subscription.status == "active", Subscription.created_at >= start),
        "payment_mode": settings.PAYMENT_MODE,
        "regions": [{"region": r, "count": n} for r, n in top],
        "crop_accuracy": crop_acc,
        "attention": {
            "applications": await _count(db, ExpertApplication, ExpertApplication.status == "pending"),
            "oldest_application_hours": int((now - oldest_app).total_seconds() // 3600) if oldest_app else None,
            "questions_stale": await _count(db, Question, Question.status == "new", Question.created_at < now - timedelta(hours=4)),
            # shikoyat qilingan post/izohlar soni (bitta postga bir nechta shikoyat — bitta ish)
            "reports": len(await reports(db)),  # moderatsiya ro'yxati bilan bir xil hisob (o'chirilgan post sanalmaydi)
            "queue": await _count(db, Diagnosis, Diagnosis.review_status == "pending", Diagnosis.review_requested.is_(True)),
            "backup": _backup_info(brief=True),
        },
    }


# ---------- Agronomlar faolligi ----------
@router.get("/experts")
async def experts(db: AsyncSession = Depends(get_db)):
    month = utcnow() - timedelta(days=30)
    out = []
    for u in (await db.scalars(select(User).where(User.role == "agronomist").order_by(User.full_name))).all():
        answered = await db.scalar(select(func.count(func.distinct(QuestionMessage.question_id))).where(
            QuestionMessage.sender_id == u.id, QuestionMessage.created_at >= month)) or 0
        rating = await db.scalar(select(func.avg(Question.rating)).where(Question.expert_id == u.id, Question.rating.is_not(None)))
        first = (await db.execute(
            select(Question.created_at, func.min(QuestionMessage.created_at))
            .join(QuestionMessage, QuestionMessage.question_id == Question.id)
            .where(Question.expert_id == u.id, QuestionMessage.sender_id == u.id)
            .group_by(Question.id, Question.created_at))).all()
        waits = [(b - a).total_seconds() / 60 for a, b in first if a and b]
        agree, reviewed = await _agreement(db, Diagnosis.reviewed_by == u.id)
        out.append({
            "id": u.id, "full_name": u.full_name, "username": u.username, "region": u.region, "specialization": u.specialization,
            "accepting_questions": u.accepting_questions, "answers_30d": answered,
            "rating": round(float(rating), 1) if rating is not None else None,
            "avg_answer_minutes": round(sum(waits) / len(waits)) if waits else None,
            "reviewed": reviewed, "ai_agreement": agree,
            "reviewed_30d": await _count(db, Diagnosis, Diagnosis.reviewed_by == u.id, Diagnosis.reviewed_at >= month),
        })
    return out


# ---------- AI va dataset ----------
@router.get("/ai")
async def ai_overview(db: AsyncSession = Depends(get_db)):
    month = utcnow() - timedelta(days=30)
    by_status = dict((await db.execute(select(Diagnosis.review_status, func.count()).group_by(Diagnosis.review_status))).all())
    pairs = (await db.execute(
        select(Diagnosis.ai_label, Diagnosis.verified_label, func.count().label("n"))
        .where(Diagnosis.review_status == "corrected", Diagnosis.ai_label.is_not(None), Diagnosis.verified_label.is_not(None),
               Diagnosis.reviewed_at >= utcnow() - timedelta(days=90))
        .group_by(Diagnosis.ai_label, Diagnosis.verified_label).order_by(func.count().desc()).limit(8))).all()
    names = dict((await db.execute(select(Disease.ai_label, Disease.name).where(Disease.ai_label.is_not(None)))).all())

    def nm(lbl: str) -> str:
        return names.get(lbl) or ("Sog'lom" if lbl.endswith("healthy") else lbl)

    agree, reviewed = await _agreement(db)
    return {
        "total": sum(by_status.values()),
        "new_30d": await _count(db, Diagnosis, Diagnosis.diagnosed_at >= month),
        "pending": by_status.get("pending", 0),
        "confirmed": by_status.get("confirmed", 0),
        "corrected": by_status.get("corrected", 0),
        "rejected": by_status.get("rejected", 0),
        "field_accuracy": agree,
        "reviewed": reviewed,
        "pairs": [{"ai_label": a, "ai_name": nm(a), "label": b, "name": nm(b), "count": n} for a, b, n in pairs],
        "model": await get_ai_client().health(),
    }


# ---------- Model versiyalari va qayta o'qitish ----------
@router.get("/ai/models")
async def ai_models():
    """GitHub'dagi model-vN versiyalari, dala rasmlari testi natijalari va qaysi biri ishlayapti."""
    active = await get_ai_client().model()
    active_tag = (active or {}).get("model_tag")
    try:
        rels = await model_ops.releases()
        error = None
    except model_ops.GitHubError as exc:
        rels, error = [], str(exc)
    for r in rels:
        r["active"] = r["tag"] == active_tag
        r["can_activate"], r["reason"], r["can_force"] = model_ops.can_activate(r, active_tag)
    return {"active_tag": active_tag, "active": active, "models": rels, "error": error}


class ActivateIn(BaseModel):
    force: bool = False


@router.post("/ai/models/{tag}/activate")
async def ai_activate(tag: str, body: ActivateIn | None = None, admin: User = Depends(require_superadmin),
                      db: AsyncSession = Depends(get_db)):
    if not model_ops.TAG_RE.match(tag):
        raise HTTPException(422, "Noto'g'ri versiya nomi")
    active_tag = ((await get_ai_client().model()) or {}).get("model_tag")
    try:
        rel = next((r for r in await model_ops.releases() if r["tag"] == tag), None)
    except model_ops.GitHubError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, str(exc)) from exc
    if rel is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bunday versiya yo'q")
    ok, reason, can_force = model_ops.can_activate(rel, active_tag)
    if not ok and not (can_force and body and body.force):
        raise HTTPException(status.HTTP_409_CONFLICT, reason)
    try:
        info = await get_ai_client().activate(tag)
    except AIServiceError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, str(exc)) from exc
    rollback = active_tag and model_ops.version(tag) < model_ops.version(active_tag)
    await audit(db, admin, "model_activate", f"AI model: {active_tag or '—'} → {tag}"
                + (" (qaytarildi)" if rollback else f", dala testi {model_ops.pct(rel['field_test_accuracy'])}")
                + (" — dala testisiz, majburan" if not ok else ""))
    await db.commit()
    return info


@router.get("/ai/training")
async def ai_training():
    try:
        runs, error = await model_ops.runs(), None
    except model_ops.GitHubError as exc:
        runs, error = [], str(exc)
    return {"configured": bool(settings.GITHUB_TRAIN_TOKEN and model_ops.public_url()), "runs": runs, "error": error,
            "repo": settings.GITHUB_REPO}


@router.post("/ai/training")
async def ai_train(admin: User = Depends(require_superadmin), db: AsyncSession = Depends(get_db)):
    """Qayta o'qitishni boshlash: GitHub Actions bir martalik havoladan datasetni oladi va model-vN nomzodini chiqaradi."""
    base = model_ops.public_url()
    if not settings.GITHUB_TRAIN_TOKEN or not base:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE,
                            "Qayta o'qitish sozlanmagan: serverda deploy/enable-training.sh ni ishga tushiring")
    try:
        if any(r["status"] != "completed" for r in await model_ops.runs()):
            raise HTTPException(status.HTTP_409_CONFLICT, "O'qitish allaqachon ketyapti")
    except model_ops.GitHubError:
        pass
    usable = await _count(db, Diagnosis, Diagnosis.review_status.in_(USABLE))
    ticket = await model_ops.new_ticket(db)
    await db.commit()
    active_tag = ((await get_ai_client().model()) or {}).get("model_tag")
    try:
        await model_ops.dispatch(f"{base}/api/v1/dataset/ticket/{ticket}" if usable else "", active_tag)
    except model_ops.GitHubError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, str(exc)) from exc
    await audit(db, admin, "model_train", f"Qayta o'qitish boshlandi: {usable} ta tasdiqlangan dala rasmi, solishtirish — {active_tag or 'model-v1'}")
    await db.commit()
    return {"ok": True, "field_images": usable}


@router.get("/ai/coverage")
async def ai_coverage(db: AsyncSession = Depends(get_db)):
    """Har sinf bo'yicha tasdiqlangan dala rasmlari (o'qitish / test) va model bu sinfni biladimi."""
    known = set(await get_ai_client().labels())
    counts: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for did, lbl in (await db.execute(select(Diagnosis.id, Diagnosis.verified_label)
                                      .where(Diagnosis.review_status.in_(USABLE)))).all():
        counts[lbl][0 if field_split(did) == "train" else 1] += 1
    kb = (await db.execute(select(Disease.ai_label, Disease.name, Plant.name).outerjoin(Plant, Plant.id == Disease.plant_id)
                           .where(Disease.ai_label.is_not(None)))).all()
    names = {lbl: (n, p) for lbl, n, p in kb}
    prefix_plant = {lbl.split("_")[0]: p for lbl, (_, p) in names.items() if p}  # Tomato → Pomidor (sog'lom sinflar uchun)
    labels = set(names) | set(counts) | known
    rows = []
    for lbl in labels:
        n, p = names.get(lbl, ("Sog'lom" if lbl.endswith("healthy") else lbl, prefix_plant.get(lbl.split("_")[0])))
        tr, te = counts.get(lbl, [0, 0])
        rows.append({"label": lbl, "name": n, "plant": p, "train": tr, "test": te, "in_model": lbl in known})
    # Avval model bilmaydigan sinflar (masalan bodring), keyin rasmi kamlar
    rows.sort(key=lambda r: (r["in_model"], r["train"] + r["test"], r["label"]))
    return {"target": 200, "classes": rows}


# ---------- Bilimlar bazasi ----------
@router.get("/kb/diseases")
async def kb_diseases(db: AsyncSession = Depends(get_db)):
    meds = dict((await db.execute(select(DiseaseMedicine.disease_id, func.count()).group_by(DiseaseMedicine.disease_id))).all())
    rows = (await db.execute(select(Disease, Plant.name).outerjoin(Plant, Plant.id == Disease.plant_id).order_by(Disease.name))).all()
    return [{"id": d.id, "name": d.name, "plant_name": p, "ai_label": d.ai_label, "risk_level": d.risk_level,
             "image_url": d.image_url, "medicines": meds.get(d.id, 0)} for d, p in rows]


_ENTITIES = {"plant": Plant, "disease": Disease, "medicine": Medicine}


@router.post("/catalog-changes/{change_id}/revert")
async def revert_change(change_id: uuid.UUID, admin: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    """Agronom kiritgan o'zgarishni qaytarish: oldingi qiymatlar qayta yoziladi va tarixga yangi yozuv tushadi."""
    c = await db.get(CatalogChange, change_id)
    if c is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "O'zgarish topilmadi")
    if c.reverted_at is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Bu o'zgarish allaqachon qaytarilgan")
    if not c.before or c.action != "update" or c.entity not in _ENTITIES or c.entity_id is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Bu o'zgarishni qaytarib bo'lmaydi")
    obj = await db.get(_ENTITIES[c.entity], c.entity_id)
    if obj is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Yozuv o'chirilgan")
    before = dict(c.before)
    links = before.pop("medicines", None)
    for k, v in before.items():
        if k == "plant_id" and v is not None:
            v = uuid.UUID(v)
        setattr(obj, k, v)
    if links is not None:
        await db.execute(delete(DiseaseMedicine).where(DiseaseMedicine.disease_id == obj.id))
        for item in links:
            db.add(DiseaseMedicine(disease_id=obj.id, medicine_id=uuid.UUID(item["medicine_id"]), recommendation=item.get("recommendation")))
    c.reverted_at = utcnow()
    summary = f"Qaytarildi: {c.summary}"
    db.add(CatalogChange(user_id=admin.id, entity=c.entity, entity_id=c.entity_id, action="revert", summary=summary[:255]))
    await audit(db, admin, "catalog_revert", summary, c.entity_id)
    await db.commit()
    return {"ok": True, "summary": summary}


# ---------- Jamoat moderatsiyasi ----------
@router.get("/reports")
async def reports(db: AsyncSession = Depends(get_db)):
    groups: dict[tuple, dict] = {}
    for r in (await db.scalars(select(Report).where(Report.status == "pending").order_by(Report.created_at.desc()))).all():
        key = ("comment", r.comment_id) if r.comment_id else ("message", r.message_id) if r.message_id else ("post", r.post_id)
        g = groups.get(key)
        if g is None:
            target = await db.get(_MODEL[key[0]], key[1])
            if target is None:
                continue
            owner = target.sender_id if key[0] == "message" else target.user_id
            author = await db.get(User, owner)
            text = (target.content or ("📷" if key[0] == "message" else "")) if key[0] != "post" else " — ".join(x for x in (target.title, target.content) if x)
            g = groups[key] = {"kind": key[0], "target_id": key[1], "text": (text or "")[:400], "author": author.full_name if author else None,
                               "author_id": owner, "reasons": [], "count": 0, "last_at": r.created_at}
        g["count"] += 1
        if r.reason and r.reason not in g["reasons"]:
            g["reasons"].append(r.reason)
    return sorted(groups.values(), key=lambda g: -g["count"])


_MODEL = {"post": Post, "comment": Comment, "message": Message}
_REPORT_COL = {"post": Report.post_id, "comment": Report.comment_id, "message": Report.message_id}
_WHAT = {"post": ("postingiz", "post"), "comment": ("izohingiz", "izoh"), "message": ("chatdagi xabaringiz", "chat xabari")}


class ModerateIn(BaseModel):
    kind: str = Field(pattern=r"^(post|comment|message)$")
    target_id: uuid.UUID


@router.post("/reports/hide")
async def hide_reported(body: ModerateIn, admin: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    target = await db.get(_MODEL[body.kind], body.target_id)
    if target is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Topilmadi")
    author_id = target.sender_id if body.kind == "message" else target.user_id
    what, noun = _WHAT[body.kind]
    await db.execute(delete(Report).where(_REPORT_COL[body.kind] == target.id))
    if isinstance(target, Comment):
        await remove_comment(db, target)  # javoblari bo'lsa "Izoh o'chirilgan" bo'lib qoladi
    else:
        await db.delete(target)
    await notify(db, author_id, "moderation", f"Jamoatdagi {what} olib tashlandi" if body.kind != "message" else "Chatdagi xabaringiz olib tashlandi", "Jamoat qoidalariga mos kelmadi.")
    await audit(db, admin, "report_hide", f"Shikoyat bo'yicha {noun} olib tashlandi", author_id)
    await db.commit()
    return {"ok": True}


@router.post("/reports/dismiss")
async def dismiss_reports(body: ModerateIn, admin: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    col = _REPORT_COL[body.kind]
    n = 0
    for r in (await db.scalars(select(Report).where(col == body.target_id, Report.status == "pending"))).all():
        r.status, r.reviewed_at = "dismissed", utcnow()
        n += 1
    await audit(db, admin, "report_dismiss", f"{n} ta shikoyat rad etildi", body.target_id)
    await db.commit()
    return {"ok": True, "dismissed": n}


# ---------- To'lovlar va sozlamalar ----------
PAID = ("active", "expired", "cancelled")


@router.get("/payments")
async def payments(db: AsyncSession = Depends(get_db)):
    now = utcnow()
    month_start = datetime(now.year, now.month, 1)
    paid = (Subscription.status.in_(PAID), Subscription.external_txn_id.is_not(None))
    rows = (await db.execute(select(Subscription.created_at, Subscription.price).where(*paid,
                             Subscription.created_at >= month_start - timedelta(days=170)))).all()
    by_month: dict[str, float] = {}
    y, m = now.year, now.month
    for _ in range(6):
        by_month[f"{y}-{m:02d}"] = 0.0
        y, m = (y, m - 1) if m > 1 else (y - 1, 12)
    for ts, price in rows:
        k = f"{ts.year}-{ts.month:02d}"
        if k in by_month:
            by_month[k] += float(price or 0)
    users_total = await _count(db, User)
    active = dict((await db.execute(select(Subscription.plan, func.count()).where(Subscription.status == "active")
                                    .group_by(Subscription.plan))).all())
    txns = []
    for s, name in (await db.execute(select(Subscription, User.full_name).join(User, User.id == Subscription.user_id)
                                     .order_by(Subscription.created_at.desc()).limit(30))).all():
        txns.append({"id": s.id, "user": name, "plan": s.plan, "provider": s.payment_provider, "amount": float(s.price or 0),
                     "status": s.status, "paid": s.external_txn_id is not None, "created_at": s.created_at})
    return {
        "mode": settings.PAYMENT_MODE,
        "revenue_month": by_month[f"{now.year}-{now.month:02d}"],
        "active": sum(active.values()),
        "active_by_plan": active,
        "premium_share": round(await _count(db, User, User.is_premium.is_(True)) / users_total * 100, 1) if users_total else 0,
        "cancelled_30d": await _count(db, Subscription, Subscription.status == "cancelled", Subscription.updated_at >= now - timedelta(days=30)),
        "monthly": [{"month": k, "amount": v} for k, v in reversed(by_month.items())],
        "transactions": txns,
        "settings": await all_settings(db),
    }


@router.put("/settings")
async def save_settings(body: dict[str, int], admin: User = Depends(require_superadmin), db: AsyncSession = Depends(get_db)):
    changed = []
    for k, v in body.items():
        if k not in EDITABLE:
            raise HTTPException(422, f"Noma'lum sozlama: {k}")
        title, _, lo, hi = EDITABLE[k]
        if not lo <= v <= hi:
            raise HTTPException(422, f"{title}: {lo}–{hi} oralig'ida bo'lsin")
        if await get_int(db, k) == v:
            continue
        row = await db.get(AppSetting, k)
        if row is None:
            db.add(AppSetting(key=k, value=str(v)))
        else:
            row.value = str(v)
        changed.append(f"{title} = {v}")
    if changed:
        await audit(db, admin, "settings", "Sozlamalar: " + "; ".join(changed))
    await db.commit()
    return await all_settings(db)


# ---------- Tizim ----------
def _backup_info(brief: bool = False) -> dict:
    d = Path(settings.BACKUP_DIR)
    if not d.is_dir():
        return {"available": False}
    status_txt = (d / "status").read_text().strip() if (d / "status").exists() else None
    last_ok = None
    try:
        last_ok = datetime.fromtimestamp(int((d / ".last_ok").read_text().strip()), timezone.utc).replace(tzinfo=None)
    except (OSError, ValueError):
        pass
    info = {"available": True, "status": status_txt, "ok": bool(status_txt and status_txt.startswith("ok")),
            "last_ok": last_ok, "offsite": bool(status_txt and "tashqi" in status_txt),
            "requested": (d / "req" / "now").exists()}
    if not brief:
        files = []
        for f in sorted(d.glob("agroyordam-*.sql.gz"), reverse=True)[:10]:
            stamp = f.name.removeprefix("agroyordam-").removesuffix(".sql.gz")
            media = d / f"media-{stamp}.tar.gz"
            files.append({"name": stamp, "db_mb": round(f.stat().st_size / 1e6, 1),
                          "media_mb": round(media.stat().st_size / 1e6, 1) if media.exists() else None})
        info["files"] = files
    return info


@router.get("/system")
async def system(db: AsyncSession = Depends(get_db)):
    try:
        await db.execute(select(1))
        db_ok = True
    except Exception:  # pragma: no cover
        db_ok = False
    du = shutil.disk_usage("/")
    return {
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT,
        "payment_mode": settings.PAYMENT_MODE,
        "database": db_ok,
        "ai": await get_ai_client().health(),
        "disk": {"used_pct": round(du.used / du.total * 100), "free_gb": round(du.free / 1e9, 1)},
        "backup": _backup_info(),
        "users": await _count(db, User),
    }


@router.post("/system/backup-now")
async def backup_now(admin: User = Depends(require_superadmin), db: AsyncSession = Depends(get_db)):
    req = Path(settings.BACKUP_DIR) / "req"
    if not req.is_dir():
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Zaxira servisi ulanmagan (serverda ishlaydi)")
    (req / "now").write_text(utcnow().isoformat())
    await audit(db, admin, "backup_now", "Zaxira so'raldi (1–5 daqiqada boshlanadi)")
    await db.commit()
    return {"ok": True}


# ---------- Ommaviy xabar ----------
async def _audience(db: AsyncSession, key: str):
    q = select(User.id).where(User.is_active.is_(True))
    if key == "farmers":
        q = q.where(User.role == "user")
    elif key == "agronomists":
        q = q.where(User.role == "agronomist")
    elif key == "premium":
        q = q.where(User.is_premium.is_(True))
    elif key.startswith("region:"):
        q = q.where(User.region == key.removeprefix("region:"))
    elif key != "all":
        raise HTTPException(422, "Noma'lum auditoriya")
    return q


@router.get("/broadcast/audiences")
async def audiences(db: AsyncSession = Depends(get_db)):
    out = []
    for key, title in (("all", "Barcha foydalanuvchilar"), ("farmers", "Dehqonlar"), ("agronomists", "Agronomlar"), ("premium", "Premium")):
        out.append({"key": key, "title": title, "count": await db.scalar(select(func.count()).select_from((await _audience(db, key)).subquery()))})
    for region, n in (await db.execute(select(User.region, func.count()).where(User.is_active.is_(True), User.region.is_not(None))
                                       .group_by(User.region).order_by(func.count().desc()).limit(14))).all():
        out.append({"key": f"region:{region}", "title": region, "count": n})
    return out


class BroadcastIn(BaseModel):
    audience: str = Field(max_length=120)
    title: str = Field(min_length=3, max_length=150)
    body: str = Field(min_length=3, max_length=1000)


@router.post("/broadcast")
async def broadcast(body: BroadcastIn, admin: User = Depends(require_superadmin), db: AsyncSession = Depends(get_db)):
    ids = (await db.scalars(await _audience(db, body.audience))).all()
    for uid in ids:
        await notify(db, uid, "broadcast", body.title, body.body)
    await audit(db, admin, "broadcast", f"Ommaviy xabar ({len(ids)} kishi, {body.audience}): {body.title}")
    await db.commit()
    return {"sent": len(ids)}


# ---------- Harakatlar jurnali ----------
@router.get("/audit")
async def audit_log(limit: int = Query(default=50, le=200), db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(AuditLog, User.full_name).outerjoin(User, User.id == AuditLog.actor_id)
                             .order_by(AuditLog.created_at.desc()).limit(limit))).all()
    return [{"id": a.id, "actor": name or "Tizim", "action": a.action, "summary": a.summary, "created_at": a.created_at}
            for a, name in rows]
