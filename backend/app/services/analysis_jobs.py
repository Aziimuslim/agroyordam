"""TZ A01: AI tahlil fon jarayoni.

So'rov rasmni tekshiradi, saqlaydi va navbatga qo'yadi (202). Worker shu jarayonda (asyncio) ishlaydi:
queued → processing → finishing → done, yoki failed / cancelled. Bekor qilish holatni shartli UPDATE bilan
o'zgartiradi, worker esa natijani yozishdan oldin "finishing"ni xuddi shunday egallaydi — shuning uchun bekor
qilingan tahlildan tashxis, bildirishnoma yoki limit sarfi qolmaydi. Server qayta ishga tushsa tugallanmagan
ishlar qayta navbatga qo'yiladi.
"""
import asyncio
import logging
import uuid

from sqlalchemy import select, update

from app.core.database import SessionLocal
from app.core.security import utcnow
from app.models import AnalysisJob, Crop, Plant, User
from app.services.ai_client import AIServiceError, get_ai_client
from app.services.diagnosis_service import CONTENT_TYPES, build_diagnosis
from app.services.storage import get_storage

log = logging.getLogger(__name__)

ACTIVE = ("queued", "processing", "finishing")
_sems: dict[int, asyncio.Semaphore] = {}
_tasks: set[asyncio.Task] = set()


def _sem() -> asyncio.Semaphore:
    """Bir vaqtda AI'ga ko'pi bilan 2 ta so'rov (har event loop uchun alohida)."""
    loop = asyncio.get_running_loop()
    return _sems.setdefault(id(loop), asyncio.Semaphore(2))


def schedule(job_id: uuid.UUID) -> None:
    t = asyncio.get_running_loop().create_task(process(job_id))
    _tasks.add(t)
    t.add_done_callback(_tasks.discard)


async def _set(db, job_id: uuid.UUID, from_status: tuple[str, ...], **values) -> bool:
    res = await db.execute(update(AnalysisJob).where(AnalysisJob.id == job_id, AnalysisJob.status.in_(from_status))
                           .values(updated_at=utcnow(), **values))
    await db.commit()
    return res.rowcount == 1


async def process(job_id: uuid.UUID) -> None:
    async with _sem():
        async with SessionLocal() as db:
            if not await _set(db, job_id, ("queued",), status="processing"):
                return  # bekor qilingan yoki boshqa worker olgan
            try:
                job = await db.get(AnalysisJob, job_id)
                user = await db.get(User, job.user_id)
                crop = await db.get(Crop, job.crop_id) if job.crop_id else None
                hint_id = crop.plant_id if crop and crop.plant_id else job.plant_id
                hint_plant = await db.get(Plant, hint_id) if hint_id else None
                data = get_storage().read(job.image_url)
                if data is None:
                    await _set(db, job_id, ("processing",), status="failed", error_code=410, error="Rasm topilmadi. Qayta yuklang.")
                    return
                try:
                    pred = await get_ai_client().predict(data, f"upload.{job.ext}", CONTENT_TYPES.get(job.ext, "image/jpeg"),
                                                         plant_hint=hint_plant.name if hint_plant else None)
                except AIServiceError:
                    await _set(db, job_id, ("processing",), status="failed", error_code=503, error="AI xizmati vaqtincha ishlamayapti")
                    return
                if not pred.is_valid_image:
                    await _set(db, job_id, ("processing",), status="failed", error_code=422,
                               error=pred.reason or "Rasm sifati past. Yorug' joyda, bargga yaqinroq qilib qayta suratga oling.")
                    return
                # Natijani yozish huquqini egallaymiz — shu paytgacha bekor qilingan bo'lsa, hech narsa yaratilmaydi
                if not await _set(db, job_id, ("processing",), status="finishing"):
                    return
                diag = await build_diagnosis(db, user, crop, hint_plant, pred, job.image_url)
                job = await db.get(AnalysisJob, job_id)
                job.status, job.diagnosis_id, job.updated_at = "done", diag.id, utcnow()
                await db.commit()
            except Exception:  # pragma: no cover - kutilmagan xato: ish osilib qolmasin
                log.exception("analysis job %s failed", job_id)
                await db.rollback()
                await _set(db, job_id, ("processing", "finishing"), status="failed", error_code=500,
                           error="Tahlilda kutilmagan xato. Qayta urinib ko'ring.")


async def cancel(db, job_id: uuid.UUID) -> bool:
    """Faqat navbatdagi yoki tahlil qilinayotgan ish bekor qilinadi; natija yozilayotgan bo'lsa — yo'q."""
    return await _set(db, job_id, ("queued", "processing"), status="cancelled")


async def resume_pending() -> None:
    """Server qayta ishga tushganda tugallanmagan ishlarni qayta navbatga qo'yadi."""
    async with SessionLocal() as db:
        await db.execute(update(AnalysisJob).where(AnalysisJob.status.in_(("processing", "finishing")))
                         .values(status="queued"))
        await db.commit()
        ids = (await db.scalars(select(AnalysisJob.id).where(AnalysisJob.status == "queued"))).all()
    for i in ids:
        schedule(i)
