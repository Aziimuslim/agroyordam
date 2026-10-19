import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, updated_at_col, uuid_pk


class AIConversation(Base):
    """TZ S09/S10: foydalanuvchining alohida AI suhbatlari (nomlash, qidirish, o'chirish)."""

    __tablename__ = "ai_conversations"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()


class AIChatMessage(Base):
    """AI suhbat xabari. Assistent javobi `reply_to_id` bilan savolga bog'lanadi (qayta javob shu savolga);
    oqim to'xtatilsa yoki uzilsa javob `partial` bo'lib saqlanadi — tugallangan deb ko'rsatilmaydi."""

    __tablename__ = "ai_chat_messages"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    conversation_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("ai_conversations.id", ondelete="CASCADE"), index=True)
    reply_to_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("ai_chat_messages.id", ondelete="SET NULL"))
    role: Mapped[str] = mapped_column(String(20), nullable=False)  # user | assistant
    content: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="done", server_default="done")  # done | partial
    created_at: Mapped[datetime] = created_at_col()
