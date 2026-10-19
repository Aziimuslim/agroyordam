import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, ForeignKey, SmallInteger, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, uuid_pk


class AuthChallenge(Base):
    """Bir martalik kod (TZ S35): ro'yxatdan o'tish, kodli kirish yoki parolni tiklash uchun.
    Kod faqat hash ko'rinishida saqlanadi; yangi kod yuborilganda eskisi yaroqsiz bo'ladi."""

    __tablename__ = "auth_challenges"

    id: Mapped[uuid.UUID] = uuid_pk()
    purpose: Mapped[str] = mapped_column(String(20), nullable=False)  # register | login | recovery
    channel: Mapped[str] = mapped_column(String(10), nullable=False)  # sms | email
    destination: Mapped[str] = mapped_column(String(150), nullable=False, index=True)
    user_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    attempts: Mapped[int] = mapped_column(SmallInteger, default=0, server_default="0")
    resends: Mapped[int] = mapped_column(SmallInteger, default=0, server_default="0")
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    resend_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime)
    payload: Mapped[dict | None] = mapped_column(JSON)  # register: ism, parol hash'i, hudud, til, rozilik
    created_at: Mapped[datetime] = created_at_col()
