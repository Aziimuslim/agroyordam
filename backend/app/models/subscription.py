import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Numeric, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, updated_at_col, uuid_pk


class Subscription(Base):
    __tablename__ = "subscriptions"
    __table_args__ = (Index("idx_subscriptions_user_status", "user_id", "status"),)

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    plan: Mapped[str] = mapped_column(String(20), nullable=False)  # monthly | yearly | lifetime
    status: Mapped[str] = mapped_column(String(20), default="active", server_default="active")  # active|expired|cancelled|trial|pending
    price: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    currency: Mapped[str] = mapped_column(String(10), default="UZS", server_default="UZS")
    payment_provider: Mapped[str | None] = mapped_column(String(30))  # payme | click | uzum
    external_txn_id: Mapped[str | None] = mapped_column(String(150))
    started_at: Mapped[datetime | None] = created_at_col()
    expires_at: Mapped[datetime | None] = mapped_column(DateTime)
    auto_renew: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()
