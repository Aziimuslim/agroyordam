import uuid
from datetime import date, datetime, time

from pydantic import BaseModel, Field

from app.schemas.common import ORMModel

RTYPE = r"^(watering|treatment|fertilizing|recheck|other)$"


class ReminderIn(BaseModel):
    crop_id: uuid.UUID | None = None
    diagnosis_id: uuid.UUID | None = None
    title: str = Field(min_length=1, max_length=150)
    description: str | None = None
    reminder_type: str | None = Field(default="other", pattern=RTYPE)
    reminder_date: date
    reminder_time: time | None = None


class ReminderUpdate(BaseModel):
    crop_id: uuid.UUID | None = None
    title: str | None = Field(default=None, min_length=1, max_length=150)
    description: str | None = None
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
    created_at: datetime | None = None


class NotificationOut(ORMModel):
    id: uuid.UUID
    type: str | None = None
    title: str | None = None
    body: str | None = None
    reference_id: uuid.UUID | None = None
    is_read: bool
    created_at: datetime | None = None
