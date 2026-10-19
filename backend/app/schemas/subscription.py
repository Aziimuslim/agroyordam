import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, computed_field

from app.schemas.common import ORMModel


class PlanOut(BaseModel):
    code: str
    title: str
    price: Decimal
    currency: str = "UZS"
    duration_days: int | None
    features: list[str]


class CheckoutIn(BaseModel):
    plan: str = Field(pattern=r"^(monthly|yearly|lifetime)$")
    provider: str = Field(pattern=r"^(payme|click|uzum)$")


class CheckoutOut(BaseModel):
    subscription_id: uuid.UUID
    provider: str
    amount: Decimal
    payment_url: str
    sandbox: bool


class SubscriptionOut(ORMModel):
    id: uuid.UUID
    plan: str
    status: str
    price: Decimal | None = None
    currency: str
    payment_provider: str | None = None
    external_txn_id: str | None = None
    started_at: datetime | None = None
    expires_at: datetime | None = None
    auto_renew: bool
    created_at: datetime | None = None
    paid_at: datetime | None = None
    refunded_at: datetime | None = None

    @computed_field
    @property
    def payment_status(self) -> str:
        """To'lov natijasi obuna holatidan alohida (TZ S30): paid | pending | failed | refunded."""
        if self.refunded_at:
            return "refunded"
        if self.paid_at:
            return "paid"
        return "pending" if self.status == "pending" else "failed"


class MySubscription(BaseModel):
    is_premium: bool
    premium_until: datetime | None = None
    active: SubscriptionOut | None = None
    ai_used_today: int
    ai_daily_limit: int | None
    crops_used: int
    crop_limit: int | None


class WebhookIn(BaseModel):
    subscription_id: uuid.UUID
    transaction_id: str
    status: str = Field(pattern=r"^(paid|cancelled|failed)$")
    amount: Decimal
