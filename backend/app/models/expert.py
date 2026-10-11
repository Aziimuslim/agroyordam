import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, SmallInteger, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, updated_at_col, uuid_pk


class ExpertApplication(Base):
    """"Men agronomman" arizasi: admin tasdiqlasa foydalanuvchi roli agronomist bo'ladi."""

    __tablename__ = "expert_applications"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    specialization: Mapped[str] = mapped_column(String(200), nullable=False)
    experience_years: Mapped[int] = mapped_column(Integer, default=0)
    about: Mapped[str | None] = mapped_column(Text)
    document_url: Mapped[str | None] = mapped_column(String(255))
    status: Mapped[str] = mapped_column(String(20), default="pending", server_default="pending", index=True)  # pending|approved|rejected
    reason: Mapped[str | None] = mapped_column(String(255))
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("users.id", ondelete="SET NULL"))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime)
    created_at: Mapped[datetime] = created_at_col()


class Question(Base):
    """Dehqonning agronomga savoli (konsultatsiya)."""

    __tablename__ = "questions"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    crop_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("crops.id", ondelete="SET NULL"))
    diagnosis_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("diagnoses.id", ondelete="SET NULL"))
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str | None] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(String(255))
    status: Mapped[str] = mapped_column(String(20), default="new", server_default="new", index=True)  # new|answered|closed
    expert_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("users.id", ondelete="SET NULL"), index=True)
    rating: Mapped[int | None] = mapped_column(SmallInteger)
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()


class QuestionMessage(Base):
    __tablename__ = "question_messages"

    id: Mapped[uuid.UUID] = uuid_pk()
    question_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("questions.id", ondelete="CASCADE"), index=True)
    sender_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    body: Mapped[str | None] = mapped_column(Text)
    medicine_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("medicines.id", ondelete="SET NULL"))
    image_url: Mapped[str | None] = mapped_column(String(255))
    created_at: Mapped[datetime] = created_at_col()


class CatalogChange(Base):
    """Bilimlar bazasidagi o'zgarishlar jurnali (agronom/admin kim, nimani o'zgartirdi)."""

    __tablename__ = "catalog_changes"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("users.id", ondelete="SET NULL"), index=True)
    entity: Mapped[str] = mapped_column(String(20), nullable=False)  # plant|disease|medicine
    entity_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)
    action: Mapped[str] = mapped_column(String(20), nullable=False)  # create|update|delete
    summary: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = created_at_col()
