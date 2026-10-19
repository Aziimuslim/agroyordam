import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, Integer, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, updated_at_col, uuid_pk


class AnalysisJob(Base):
    """TZ A01: AI tahlil fon jarayoni. queued → processing → done | failed | cancelled.
    (user_id, client_key) yagona — qayta yuborish (tarmoq uzilishi, ikki marta bosish) dublikat tahlil yaratmaydi."""

    __tablename__ = "analysis_jobs"
    __table_args__ = (UniqueConstraint("user_id", "client_key", name="uq_analysis_jobs_user_key"),)

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    client_key: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="queued", server_default="queued", index=True)
    image_url: Mapped[str] = mapped_column(String(255), nullable=False)
    ext: Mapped[str] = mapped_column(String(8), nullable=False)
    crop_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("crops.id", ondelete="SET NULL"))
    plant_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("plants.id", ondelete="SET NULL"))
    diagnosis_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("diagnoses.id", ondelete="SET NULL"))
    error: Mapped[str | None] = mapped_column(Text)
    error_code: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()
