import uuid
from datetime import date, datetime, time

from sqlalchemy import Boolean, Date, ForeignKey, Index, String, Text, Time, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, uuid_pk


class Reminder(Base):
    __tablename__ = "reminders"
    __table_args__ = (Index("idx_reminders_user_date", "user_id", "reminder_date"),)

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    crop_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("crops.id", ondelete="SET NULL"))
    diagnosis_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("diagnoses.id", ondelete="SET NULL"))
    title: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    reminder_type: Mapped[str | None] = mapped_column(String(30))  # watering|treatment|fertilizing|recheck|other
    reminder_date: Mapped[date] = mapped_column(Date, nullable=False)
    reminder_time: Mapped[time | None] = mapped_column(Time)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    created_at: Mapped[datetime] = created_at_col()
