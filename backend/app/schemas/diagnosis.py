import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field

from app.schemas.catalog import MedicineRecommendation
from app.schemas.common import ORMModel


class DiagnosisOut(ORMModel):
    id: uuid.UUID
    crop_id: uuid.UUID | None = None
    plant_id: uuid.UUID | None = None
    plant_name: str | None = None
    disease_id: uuid.UUID | None = None
    disease_name: str | None = None
    ai_label: str | None = None
    image_url: str
    confidence: Decimal | None = None
    risk_level: str | None = None
    symptoms: str | None = None
    causes: str | None = None
    treatment: str | None = None
    prevention: str | None = None
    recommendations: str | None = None
    is_healthy: bool = False
    low_confidence: bool = False
    medicines: list[MedicineRecommendation] = []
    diagnosed_at: datetime | None = None


class ShareIn(BaseModel):
    title: str | None = Field(default=None, max_length=200)
    content: str | None = None
