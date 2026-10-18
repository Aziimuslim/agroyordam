import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, Field, field_validator

from app.schemas.common import ORMModel


def _not_future(v: date | None) -> date | None:
    # TZ S05: ekilgan sana kelajakda bo'lmaydi (kelajak ekish — alohida reja funksiyasi)
    if v is not None and v > date.today():
        raise ValueError("Ekilgan sana kelajakda bo'lishi mumkin emas")
    return v


def _strip(v: str | None) -> str | None:
    return v.strip() if isinstance(v, str) else v


class CropIn(BaseModel):
    plant_id: uuid.UUID | None = None
    name: str = Field(min_length=2, max_length=80)
    variety: str | None = Field(default=None, max_length=80)
    planting_date: date | None = None
    area: Decimal | None = Field(default=None, gt=0)
    location: str | None = Field(default=None, max_length=120)
    notes: str | None = Field(default=None, max_length=1000)

    @field_validator("name", "variety", "location", "notes", mode="before")
    @classmethod
    def strip_text(cls, v):
        return _strip(v)

    @field_validator("planting_date")
    @classmethod
    def date_not_future(cls, v):
        return _not_future(v)


class CropUpdate(BaseModel):
    plant_id: uuid.UUID | None = None
    name: str | None = Field(default=None, min_length=2, max_length=80)
    variety: str | None = Field(default=None, max_length=80)
    planting_date: date | None = None
    area: Decimal | None = Field(default=None, gt=0)
    location: str | None = Field(default=None, max_length=120)
    status: str | None = Field(default=None, pattern=r"^(active|archived)$")
    health_score: int | None = Field(default=None, ge=0, le=100)
    notes: str | None = Field(default=None, max_length=1000)

    @field_validator("name", "variety", "location", "notes", mode="before")
    @classmethod
    def strip_text(cls, v):
        return _strip(v)

    @field_validator("planting_date")
    @classmethod
    def date_not_future(cls, v):
        return _not_future(v)


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
    photo_url: str | None = None  # foydalanuvchi yuklagan ekin surati
    image_url: str | None = None  # oxirgi tashxis surati (ekin surati bo'lmasa kartada ko'rsatiladi)
    last_diagnosis_at: datetime | None = None  # yo'q bo'lsa — "Ma'lumot yetarli emas"


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
