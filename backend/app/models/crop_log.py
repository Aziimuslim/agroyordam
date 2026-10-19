from datetime import date, datetime
import uuid

from sqlalchemy import JSON, Date, ForeignKey, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, updated_at_col, uuid_pk


class CropLog(Base):
    __tablename__ = "crop_logs"

    id: Mapped[uuid.UUID] = uuid_pk()
    crop_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("crops.id", ondelete="CASCADE"))
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    content: Mapped[str] = mapped_column(Text, nullable=False)
    image_url: Mapped[str | None] = mapped_column(String(255))  # birinchi rasm (eski ilovalar uchun)
    images: Mapped[list | None] = mapped_column(JSON)  # A04: 5 tagacha rasm
    observed_at: Mapped[date | None] = mapped_column(Date)  # kuzatuv sanasi (yozilgan vaqtdan farqli bo'lishi mumkin)
    version: Mapped[int] = mapped_column(Integer, default=1, server_default="1")  # tahrir konflikti uchun
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()
