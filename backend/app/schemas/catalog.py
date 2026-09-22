import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.common import ORMModel


class PlantIn(BaseModel):
    name: str = Field(max_length=100)
    scientific_name: str | None = None
    description: str | None = None
    care_info: str | None = None
    image_url: str | None = None


class PlantUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=100)
    scientific_name: str | None = None
    description: str | None = None
    care_info: str | None = None
    image_url: str | None = None


class PlantOut(ORMModel):
    id: uuid.UUID
    name: str
    scientific_name: str | None = None
    description: str | None = None
    care_info: str | None = None
    image_url: str | None = None
    created_at: datetime | None = None


RISK = r"^(low|medium|high)$"


class DiseaseIn(BaseModel):
    plant_id: uuid.UUID | None = None
    ai_label: str | None = Field(default=None, max_length=150)
    name: str = Field(max_length=150)
    description: str | None = None
    symptoms: str | None = None
    causes: str | None = None
    treatment: str | None = None
    prevention: str | None = None
    risk_level: str | None = Field(default=None, pattern=RISK)
    image_url: str | None = None


class DiseaseUpdate(BaseModel):
    plant_id: uuid.UUID | None = None
    ai_label: str | None = None
    name: str | None = None
    description: str | None = None
    symptoms: str | None = None
    causes: str | None = None
    treatment: str | None = None
    prevention: str | None = None
    risk_level: str | None = Field(default=None, pattern=RISK)
    image_url: str | None = None


class MedicineIn(BaseModel):
    name: str = Field(max_length=150)
    active_ingredient: str | None = None
    description: str | None = None
    usage: str | None = None
    precautions: str | None = None
    manufacturer: str | None = None
    image_url: str | None = None


class MedicineOut(ORMModel):
    id: uuid.UUID
    name: str
    active_ingredient: str | None = None
    description: str | None = None
    usage: str | None = None
    precautions: str | None = None
    manufacturer: str | None = None
    image_url: str | None = None


class MedicineRecommendation(MedicineOut):
    recommendation: str | None = None


class DiseaseOut(ORMModel):
    id: uuid.UUID
    plant_id: uuid.UUID | None = None
    plant_name: str | None = None
    ai_label: str | None = None
    name: str
    description: str | None = None
    symptoms: str | None = None
    causes: str | None = None
    treatment: str | None = None
    prevention: str | None = None
    risk_level: str | None = None
    image_url: str | None = None


class DiseaseDetail(DiseaseOut):
    medicines: list[MedicineRecommendation] = []


class DiseaseMedicineLink(BaseModel):
    medicine_id: uuid.UUID
    recommendation: str | None = None


class DiseaseMedicinesIn(BaseModel):
    items: list[DiseaseMedicineLink]
