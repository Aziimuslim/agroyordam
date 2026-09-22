import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, uuid_pk


class Disease(Base):
    __tablename__ = "diseases"

    id: Mapped[uuid.UUID] = uuid_pk()
    plant_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("plants.id", ondelete="CASCADE"))
    ai_label: Mapped[str | None] = mapped_column(String(150), unique=True)
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    symptoms: Mapped[str | None] = mapped_column(Text)
    causes: Mapped[str | None] = mapped_column(Text)
    treatment: Mapped[str | None] = mapped_column(Text)
    prevention: Mapped[str | None] = mapped_column(Text)
    risk_level: Mapped[str | None] = mapped_column(String(20))  # low | medium | high
    image_url: Mapped[str | None] = mapped_column(String(255))
    created_at: Mapped[datetime] = created_at_col()
