import uuid
from datetime import date, datetime, time
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
    disease_label: str | None = None  # bilimlar bazasidagi kasallik sinfi (ma'lumotnoma rasmi uchun)
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
    user_feedback: bool | None = None
    feedback_reason: str | None = None
    review_status: str = "pending"
    review_requested: bool = False
    expert_comment: str | None = None
    diagnosed_at: datetime | None = None


class AnalysisJobOut(ORMModel):
    """TZ A01: queued | processing | finishing | done | failed | cancelled."""
    id: uuid.UUID
    status: str
    diagnosis_id: uuid.UUID | None = None
    error: str | None = None
    error_code: int | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class ReviewRequestIn(BaseModel):
    note: str | None = Field(default=None, max_length=1000)


class FeedbackIn(BaseModel):
    correct: bool
    reason: str | None = Field(default=None, max_length=500)  # TZ S08: "Yo'q" uchun ixtiyoriy sabab


class ReplacedTask(BaseModel):
    title: str
    date: date


class ShareIn(BaseModel):
    title: str | None = Field(default=None, max_length=200)
    content: str | None = None


class CarePlanTask(BaseModel):
    day: int
    date: date
    time: time
    title: str
    description: str | None = None
    reminder_type: str


class CarePlanOut(BaseModel):
    diagnosis_id: uuid.UUID
    crop_id: uuid.UUID | None = None
    plant_id: uuid.UUID | None = None
    plant_name: str | None = None
    disease_name: str | None = None
    confidence: Decimal | None = None
    is_healthy: bool = False
    duration_days: int
    tasks: list[CarePlanTask]
    # TZ S04: rejani qayta yaratishda almashtiriladigan (hali bajarilmagan) vazifalar — farq previewi uchun
    replaces: list[ReplacedTask] = []


class CarePlanApply(BaseModel):
    """crop_id berilsa — shu ekinga, aks holda (tashxis ekinga bog'lanmagan bo'lsa) yangi ekin yaratiladi."""

    crop_id: uuid.UUID | None = None
    crop_name: str | None = Field(default=None, min_length=1, max_length=100)
    plant_id: uuid.UUID | None = None
    variety: str | None = Field(default=None, max_length=100)
    location: str | None = Field(default=None, max_length=150)


class CarePlanApplied(BaseModel):
    crop_id: uuid.UUID
    reminders_created: int
