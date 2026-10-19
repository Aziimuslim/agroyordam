import uuid
from datetime import date, datetime, time

from datetime import timedelta
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

from app.schemas.common import ORMModel

RTYPE = r"^(watering|treatment|fertilizing|recheck|other)$"


MAX_OCCURRENCES = 200


class ReminderIn(BaseModel):
    crop_id: uuid.UUID | None = None
    diagnosis_id: uuid.UUID | None = None
    title: str = Field(min_length=3, max_length=120)
    description: str | None = Field(default=None, max_length=1000)
    reminder_type: str | None = Field(default="other", pattern=RTYPE)
    reminder_date: date
    reminder_time: time | None = None  # yo'q — kun bo'yi (all-day)
    repeat: Literal["daily", "weekly", "monthly", "custom"] | None = None
    repeat_every: int | None = Field(default=None, ge=1, le=60)
    repeat_until: date | None = None
    remind_before: int | None = Field(default=None, ge=0, le=10080)

    @field_validator("title", "description", mode="before")
    @classmethod
    def strip_text(cls, v):
        return v.strip() if isinstance(v, str) else v

    @model_validator(mode="after")
    def check_repeat(self):
        if self.repeat is None:
            return self
        if self.repeat_until is None:
            raise ValueError("Takrorlash uchun tugash sanasini kiriting")
        if self.repeat_until < self.reminder_date:
            raise ValueError("Tugash sanasi boshlanish sanasidan oldin bo'lishi mumkin emas")
        if self.repeat_until > self.reminder_date + timedelta(days=366):
            raise ValueError("Takrorlash ko'pi bilan 1 yilga belgilanadi")
        if self.repeat == "custom" and not self.repeat_every:
            raise ValueError("Necha kunda takrorlanishini kiriting")
        return self


class ReminderUpdate(BaseModel):
    crop_id: uuid.UUID | None = None
    title: str | None = Field(default=None, min_length=3, max_length=120)
    description: str | None = Field(default=None, max_length=1000)
    remind_before: int | None = Field(default=None, ge=0, le=10080)
    reminder_type: str | None = Field(default=None, pattern=RTYPE)
    reminder_date: date | None = None
    reminder_time: time | None = None
    is_completed: bool | None = None


class ReminderOut(ORMModel):
    id: uuid.UUID
    crop_id: uuid.UUID | None = None
    crop_name: str | None = None
    diagnosis_id: uuid.UUID | None = None
    title: str
    description: str | None = None
    reminder_type: str | None = None
    reminder_date: date
    reminder_time: time | None = None
    is_completed: bool
    completed_at: datetime | None = None
    series_id: uuid.UUID | None = None
    repeat: str | None = None
    repeat_every: int | None = None
    repeat_until: date | None = None
    remind_before: int | None = None
    created_at: datetime | None = None


class NotificationOut(ORMModel):
    id: uuid.UUID
    type: str | None = None
    title: str | None = None
    body: str | None = None
    reference_id: uuid.UUID | None = None
    is_read: bool
    created_at: datetime | None = None
