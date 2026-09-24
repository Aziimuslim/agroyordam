"""Dataset yig'ish: foydalanuvchilar yuklagan tashxis rasmlarini mutaxassis tekshiradi va o'qitish uchun eksport qiladi.

Oqim: tashxis (ai_label) → foydalanuvchi fikri (👍/👎) → admin/moderator: tasdiqlash | to'g'rilash | rad etish →
tasdiqlanganlar ZIP (label/rasm) → ai-service/training/train_plantvillage.py --extra … → yangi model.
"""
import csv
import io
import os
import re
import tempfile
import uuid
import zipfile
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
from sqlalchemy import case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.background import BackgroundTask

from app.core.database import get_db
from app.core.deps import require_admin
from app.core.security import create_scoped_token, decode_scoped_token, utcnow
from app.models import Diagnosis, Disease, Plant, User
from app.services.ai_client import get_ai_client
from app.services.storage import get_storage

router = APIRouter(prefix="/admin/dataset", tags=["Dataset"], dependencies=[Depends(require_admin)])
download_router = APIRouter(prefix="/dataset", tags=["Dataset"])

TARGET_PER_LABEL = 200
EXPORT_SCOPE = "dataset_export"
LABEL_RE = re.compile(r"^[A-Z][A-Za-z]*_[A-Za-z0-9_]+$")
USABLE = ("confirmed", "corrected")


class DatasetItem(BaseModel):
    id: uuid.UUID
    image_url: str
    ai_label: str | None = None
    confidence: float | None = None
    plant_name: str | None = None
    disease_name: str | None = None
    user_feedback: bool | None = None
    review_status: str
    verified_label: str | None = None
    diagnosed_at: str | None = None


class ReviewIn(BaseModel):
    status: str = Field(pattern=r"^(confirmed|corrected|rejected|pending)$")
    label: str | None = Field(default=None, max_length=150)


async def _item(db: AsyncSession, d: Diagnosis) -> DatasetItem:
    plant = await db.get(Plant, d.plant_id) if d.plant_id else None
    disease = await db.get(Disease, d.disease_id) if d.disease_id else None
    return DatasetItem(
        id=d.id, image_url=d.image_url, ai_label=d.ai_label or (disease.ai_label if disease else None),
        confidence=float(d.confidence) if d.confidence is not None else None,
        plant_name=plant.name if plant else None, disease_name=disease.name if disease else None,
        user_feedback=d.user_feedback, review_status=d.review_status, verified_label=d.verified_label,
        diagnosed_at=d.diagnosed_at.isoformat() if d.diagnosed_at else None,
    )


@router.get("/labels", response_model=list[str])
async def labels(db: AsyncSession = Depends(get_db)):
    """Belgilash uchun sinflar: model biladiganlari + bilimlar bazasidagilar (masalan, hali o'qitilmagan bodring)."""
    kb = (await db.scalars(select(Disease.ai_label).where(Disease.ai_label.is_not(None)))).all()
    return sorted(set(await get_ai_client().labels()) | set(kb))


@router.get("/items", response_model=list[DatasetItem])
async def items(
    status_: str = Query(default="pending", alias="status", pattern=r"^(pending|confirmed|corrected|rejected|usable|all)$"),
    label: str | None = None,
    flagged: bool = False,
    limit: int = Query(default=30, le=100),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
):
    """Tekshiruv navbati. Foydalanuvchi "xato" deganlar birinchi, keyin yangilari."""
    stmt = select(Diagnosis)
    if status_ == "usable":
        stmt = stmt.where(Diagnosis.review_status.in_(USABLE))
    elif status_ != "all":
        stmt = stmt.where(Diagnosis.review_status == status_)
    if label:
        stmt = stmt.where(or_(Diagnosis.verified_label == label, Diagnosis.ai_label == label))
    if flagged:
        stmt = stmt.where(Diagnosis.user_feedback.is_(False))
    stmt = stmt.order_by(case((Diagnosis.user_feedback.is_(False), 0), else_=1), Diagnosis.diagnosed_at.desc())
    rows = (await db.scalars(stmt.limit(limit).offset(offset))).all()
    return [await _item(db, d) for d in rows]


@router.put("/items/{diag_id}", response_model=DatasetItem)
async def review(diag_id: uuid.UUID, body: ReviewIn, reviewer: User = Depends(require_admin),
                 db: AsyncSession = Depends(get_db)):
    d = await db.get(Diagnosis, diag_id)
    if d is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tashxis topilmadi")
    if body.status == "confirmed":
        label = d.ai_label or (await db.scalar(select(Disease.ai_label).where(Disease.id == d.disease_id)) if d.disease_id else None)
        if not label:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "AI sinfi yo'q — to'g'ri sinfni tanlab \"corrected\" qiling")
        d.verified_label = label
    elif body.status == "corrected":
        if not body.label or not LABEL_RE.match(body.label):
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Sinf nomi Ekin_Kasallik ko'rinishida bo'lsin (masalan Tomato_Late_blight)")
        d.verified_label = body.label
    else:
        d.verified_label = None
    d.review_status = body.status
    d.reviewed_by = reviewer.id if body.status != "pending" else None
    d.reviewed_at = utcnow() if body.status != "pending" else None
    await db.commit()
    return await _item(db, d)


@router.get("/stats")
async def stats(db: AsyncSession = Depends(get_db)):
    by_status = dict((await db.execute(select(Diagnosis.review_status, func.count()).group_by(Diagnosis.review_status))).all())
    feedback = dict((await db.execute(
        select(Diagnosis.user_feedback, func.count()).where(Diagnosis.user_feedback.is_not(None)).group_by(Diagnosis.user_feedback)
    )).all())
    per_label = (await db.execute(
        select(Diagnosis.verified_label, func.count()).where(Diagnosis.review_status.in_(USABLE))
        .group_by(Diagnosis.verified_label).order_by(func.count().desc())
    )).all()
    confirmed, corrected = by_status.get("confirmed", 0), by_status.get("corrected", 0)
    flagged = await db.scalar(select(func.count()).select_from(Diagnosis).where(
        Diagnosis.review_status == "pending", Diagnosis.user_feedback.is_(False))) or 0
    return {
        "pending": by_status.get("pending", 0),
        "confirmed": confirmed,
        "corrected": corrected,
        "rejected": by_status.get("rejected", 0),
        "usable": confirmed + corrected,
        "flagged_pending": flagged,
        "feedback_correct": feedback.get(True, 0),
        "feedback_wrong": feedback.get(False, 0),
        # Mutaxassis tekshirgan rasmlarda AI qanchalik to'g'ri chiqqan — dala sharoitidagi haqiqiy aniqlik
        "ai_field_accuracy": round(confirmed / (confirmed + corrected) * 100, 1) if confirmed + corrected else None,
        "target_per_label": TARGET_PER_LABEL,
        "labels": [{"label": lbl, "count": n} for lbl, n in per_label],
    }


@router.post("/export-link")
async def export_link(user: User = Depends(require_admin)):
    """Brauzerda yuklab olish uchun 10 daqiqalik havola (Authorization sarlavhasisiz)."""
    token = create_scoped_token(str(user.id), EXPORT_SCOPE, minutes=10)
    return {"url": f"/api/v1/dataset/export?token={token}"}


@download_router.get("/export")
async def export(token: str, db: AsyncSession = Depends(get_db)):
    """Tasdiqlangan rasmlar: <label>/<id>.<ext> + manifest.csv — train_plantvillage.py --extra uchun tayyor tuzilma."""
    uid = decode_scoped_token(token, EXPORT_SCOPE)
    user = await db.get(User, uuid.UUID(uid)) if uid else None
    if user is None or user.role not in ("admin", "moderator") or not user.is_active:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Havola yaroqsiz yoki muddati o'tgan")

    rows = (await db.scalars(select(Diagnosis).where(Diagnosis.review_status.in_(USABLE))
                             .order_by(Diagnosis.verified_label, Diagnosis.diagnosed_at))).all()
    storage = get_storage()
    tmp = tempfile.NamedTemporaryFile(prefix="agro-dataset-", suffix=".zip", delete=False)
    manifest = io.StringIO()
    w = csv.writer(manifest)
    w.writerow(["file", "label", "ai_label", "confidence", "review_status", "diagnosed_at"])
    written = 0
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_STORED) as zf:  # JPEG allaqachon siqilgan
        for d in rows:
            data = storage.read(d.image_url)
            if not data:
                continue
            ext = d.image_url.rsplit(".", 1)[-1].lower()
            name = f"{d.verified_label}/{d.id}.{ext}"
            zf.writestr(name, data)
            w.writerow([name, d.verified_label, d.ai_label or "", d.confidence or "", d.review_status,
                        d.diagnosed_at.isoformat() if d.diagnosed_at else ""])
            written += 1
        zf.writestr("manifest.csv", manifest.getvalue())
        zf.writestr("README.txt", (
            "AgroYordam dala dataseti (mutaxassis tasdiqlagan).\n"
            "Har bir papka — model sinfi (ai_label). Qayta o'qitish:\n"
            "  python training/train_plantvillage.py --data <PlantVillage/raw/color> --extra <shu papka>\n"
        ))
    tmp.close()
    return FileResponse(
        tmp.name, media_type="application/zip", filename=f"agroyordam-dataset-{date.today().isoformat()}.zip",
        headers={"X-Dataset-Items": str(written)}, background=BackgroundTask(os.unlink, tmp.name),
    )
