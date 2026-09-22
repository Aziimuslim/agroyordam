import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, Field

from app.schemas.common import ORMModel


class CropIn(BaseModel):
    plant_id: uuid.UUID | None = None
    name: str = Field(min_length=1, max_length=100)
    variety: str | None = None
    planting_date: date | None = None
    area: Decimal | None = Field(default=None, ge=0)
    location: str | None = None
    notes: str | None = None


class CropUpdate(BaseModel):
    plant_id: uuid.UUID | None = None
    name: str | None = Field(default=None, min_length=1, max_length=100)
    variety: str | None = None
    planting_date: date | None = None
    area: Decimal | None = Field(default=None, ge=0)
    location: str | None = None
    status: str | None = Field(default=None, pattern=r"^(active|archived)$")
    health_score: int | None = Field(default=None, ge=0, le=100)
    notes: str | None = None


class CropOut(ORMModel):
    id: uuid.UUID
    plant_id: uuid.UUID | None = None
    plant_name: str | None = None
    name: str
    variety: str | None = None
    planting_date: date | None = None
    area: Decimal | None = None
    location: str | None = None
    status: str
    health_score: int
    notes: str | None = None
    created_at: datetime | None = None
    last_disease: str | None = None


class CropLogIn(BaseModel):
    content: str = Field(min_length=1)
    image_url: str | None = None


class CropLogOut(ORMModel):
    id: uuid.UUID
    crop_id: uuid.UUID
    content: str
    image_url: str | None = None
    created_at: datetime | None = None


class HealthPoint(BaseModel):
    date: datetime
    health_score: int
    disease: str | None = None
    diagnosis_id: uuid.UUID | None = None
