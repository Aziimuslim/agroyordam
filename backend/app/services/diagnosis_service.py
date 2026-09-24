"""Tashxis pipeline: rasm → validatsiya → AI → Knowledge Base → diagnoses saqlash."""
import uuid
from decimal import Decimal

from fastapi import HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models import Crop, Diagnosis, Disease, Plant, User
from app.repositories.catalog_repo import DiseaseRepository
from app.schemas.catalog import MedicineRecommendation
from app.schemas.diagnosis import DiagnosisOut
from app.services.ai_client import AIServiceError, get_ai_client
from app.services.limits import ensure_can_diagnose
from app.services.notification_service import notify
from app.services.storage import get_storage, read_image

RISK_PENALTY = {"low": 20, "medium": 40, "high": 60}
CONTENT_TYPES = {"jpg": "image/jpeg", "png": "image/png", "webp": "image/webp"}


def is_healthy_label(label: str | None) -> bool:
    return bool(label) and label.lower().endswith("healthy")


def health_from(disease: Disease | None, healthy: bool, confidence: float) -> int | None:
    if healthy:
        return 100
    if disease is None:
        return None
    penalty = RISK_PENALTY.get(disease.risk_level or "medium", 40)
    return max(5, round(100 - penalty * confidence / 100))


async def run_diagnosis(db: AsyncSession, user: User, upload: UploadFile, crop_id: uuid.UUID | None,
                        plant_id: uuid.UUID | None = None) -> DiagnosisOut:
    await ensure_can_diagnose(db, user)

    crop = None
    if crop_id:
        crop = await db.get(Crop, crop_id)
        if crop is None or crop.user_id != user.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Ekin topilmadi")

    data, ext = await read_image(upload)
    hint_id = crop.plant_id if crop and crop.plant_id else plant_id
    hint_plant = await db.get(Plant, hint_id) if hint_id else None
    try:
        pred = await get_ai_client().predict(data, f"upload.{ext}", CONTENT_TYPES[ext],
                                             plant_hint=hint_plant.name if hint_plant else None)
    except AIServiceError as exc:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "AI xizmati vaqtincha ishlamayapti") from exc

    if not pred.is_valid_image:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            pred.reason or "Rasm sifati past. Yorug' joyda, bargga yaqinroq qilib qayta suratga oling.",
        )

    image_url = get_storage().save(data, ext, "diagnoses")
    repo = DiseaseRepository(db)
    healthy = is_healthy_label(pred.ai_label)
    low_conf = pred.confidence < settings.AI_MIN_CONFIDENCE
    # Ishonch past bo'lsa ham eng ehtimoliy kasallik ko'rsatiladi (UI uni 'taxminiy' deb belgilaydi)
    disease = None if (healthy or not pred.ai_label) else await repo.by_ai_label(pred.ai_label)
    plant_id = (disease.plant_id if disease else None) or (hint_plant.id if hint_plant else None)

    diag = Diagnosis(
        user_id=user.id,
        crop_id=crop.id if crop else None,
        plant_id=plant_id,
        disease_id=disease.id if disease else None,
        image_url=image_url,
        confidence=Decimal(str(round(pred.confidence, 2))),
        risk_level=disease.risk_level if disease else ("low" if healthy else None),
        symptoms=disease.symptoms if disease else None,
        causes=disease.causes if disease else None,
        recommendations=(disease.treatment if disease else ("O'simlik sog'lom. Parvarishni davom ettiring." if healthy else None)),
    )
    db.add(diag)

    if crop and not low_conf:
        score = health_from(disease, healthy, pred.confidence)
        if score is not None:
            crop.health_score = score

    await db.flush()
    title = "Tashxis tayyor"
    body = f"{disease.name} {'(taxminiy) ' if low_conf else ''}aniqlandi ({pred.confidence:.0f}%)" if disease else ("O'simlik sog'lom" if healthy else "Natija aniq emas")
    await notify(db, user.id, "diagnosis_ready", title, body, diag.id)
    await db.commit()
    return await to_out(db, diag, ai_label=pred.ai_label)


async def to_out(db: AsyncSession, diag: Diagnosis, ai_label: str | None = None) -> DiagnosisOut:
    disease = await db.get(Disease, diag.disease_id) if diag.disease_id else None
    plant = await db.get(Plant, diag.plant_id) if diag.plant_id else None
    meds: list[MedicineRecommendation] = []
    if disease:
        for m, rec in await DiseaseRepository(db).medicines_for(disease.id):
            meds.append(MedicineRecommendation.model_validate(m).model_copy(update={"recommendation": rec}))
    conf = float(diag.confidence or 0)
    healthy = diag.disease_id is None and diag.risk_level == "low"
    return DiagnosisOut(
        id=diag.id,
        crop_id=diag.crop_id,
        plant_id=diag.plant_id,
        plant_name=plant.name if plant else None,
        disease_id=diag.disease_id,
        disease_name=disease.name if disease else None,
        ai_label=ai_label or (disease.ai_label if disease else None),
        image_url=diag.image_url,
        confidence=diag.confidence,
        risk_level=diag.risk_level,
        symptoms=diag.symptoms,
        causes=diag.causes,
        treatment=disease.treatment if disease else None,
        prevention=disease.prevention if disease else None,
        recommendations=diag.recommendations,
        is_healthy=healthy,
        low_confidence=(not healthy and disease is None) or conf < settings.AI_MIN_CONFIDENCE,
        medicines=meds,
        diagnosed_at=diag.diagnosed_at,
    )
