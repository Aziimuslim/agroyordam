import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, String, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, uuid_pk


class Bookmark(Base):
    """A02 Saqlanganlar: post, o'simlik, kasallik yoki vosita. Obyekt o'chirilsa yozuv qoladi —
    ilova "o'chirilgan" deb ko'rsatadi va foydalanuvchi o'zi olib tashlaydi."""

    __tablename__ = "bookmarks"
    __table_args__ = (UniqueConstraint("user_id", "kind", "target_id"),)

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    kind: Mapped[str] = mapped_column(String(10), nullable=False)  # post | plant | disease | medicine
    target_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    created_at: Mapped[datetime] = created_at_col()
