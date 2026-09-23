import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import BigInteger, ForeignKey, Integer, Numeric, String, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, updated_at_col, uuid_pk


class PaymentTransaction(Base):
    """To'lov provayderi tranzaksiyasi (Payme/Click holat mashinasi uchun).

    state: 1 — yaratilgan, 2 — bajarilgan, -1 — bajarilmasdan bekor, -2 — bajarilgandan keyin bekor.
    Vaqtlar Payme talabiga ko'ra millisekundlarda saqlanadi.
    """

    __tablename__ = "payment_transactions"
    __table_args__ = (UniqueConstraint("provider", "provider_txn_id"),)

    id: Mapped[uuid.UUID] = uuid_pk()
    provider: Mapped[str] = mapped_column(String(20), nullable=False)
    provider_txn_id: Mapped[str] = mapped_column(String(100), nullable=False)
    subscription_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("subscriptions.id", ondelete="CASCADE"), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)  # so'mda
    state: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    reason: Mapped[int | None] = mapped_column(Integer)
    provider_time: Mapped[int | None] = mapped_column(BigInteger)
    create_time: Mapped[int] = mapped_column(BigInteger, nullable=False)
    perform_time: Mapped[int] = mapped_column(BigInteger, default=0, server_default="0")
    cancel_time: Mapped[int] = mapped_column(BigInteger, default=0, server_default="0")
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()
