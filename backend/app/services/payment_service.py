"""Payme / Click / Uzum Bank integratsiyasi.

Barcha provayder webhooklari bir xil normallashtirilgan formatda qabul qilinadi va
HMAC-SHA256 imzo (X-Signature sarlavhasi) bilan tekshiriladi. Real merchant API
kalitlari .env orqali beriladi; PAYMENT_MODE=sandbox bo'lganda ilova ichida
simulyatsiya qilingan to'lov oynasi ishlaydi.
"""
import base64
import hashlib
import hmac
import uuid
from dataclasses import dataclass
from datetime import timedelta
from decimal import Decimal
from urllib.parse import urlencode

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import utcnow
from app.models import Subscription, User
from app.services.notification_service import notify


@dataclass(frozen=True)
class Plan:
    code: str
    title: str
    price: Decimal
    duration_days: int | None
    features: tuple[str, ...]


PREMIUM_FEATURES = (
    "AI tashxis — cheksiz",
    "\"Mening bog'im\" — cheksiz ekin",
    "AI Yordamchi — cheksiz va ustuvor javob",
    "Batafsil sog'liq tarixi",
)
PLANS: dict[str, Plan] = {
    "monthly": Plan("monthly", "Premium — 1 oy", Decimal("25000"), 30, PREMIUM_FEATURES),
    "yearly": Plan("yearly", "Premium — 1 yil", Decimal("250000"), 365, PREMIUM_FEATURES),
    "lifetime": Plan("lifetime", "Premium — umrbod", Decimal("590000"), None, PREMIUM_FEATURES),
}


def provider_secret(provider: str) -> str:
    secrets_map = {
        "payme": settings.PAYME_SECRET_KEY,
        "click": settings.CLICK_SECRET_KEY,
        "uzum": settings.UZUM_SECRET_KEY,
    }
    if provider not in secrets_map:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Noma'lum to'lov provayderi")
    return secrets_map[provider]


def sign(provider: str, body: bytes) -> str:
    return hmac.new(provider_secret(provider).encode(), body, hashlib.sha256).hexdigest()


def verify_signature(provider: str, body: bytes, signature: str | None) -> None:
    if not signature or not hmac.compare_digest(sign(provider, body), signature):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Webhook imzosi noto'g'ri")


def payment_url(provider: str, sub: Subscription) -> str:
    amount = int(sub.price or 0)
    if settings.PAYMENT_MODE == "sandbox":
        return f"{settings.PAYMENT_RETURN_URL}?sandbox=1&subscription_id={sub.id}&provider={provider}"
    if provider == "payme":
        raw = f"m={settings.PAYME_MERCHANT_ID};ac.{settings.PAYME_ACCOUNT_FIELD}={sub.id};a={amount * 100};c={settings.PAYMENT_RETURN_URL}"
        return settings.PAYME_CHECKOUT_URL.rstrip("/") + "/" + base64.b64encode(raw.encode()).decode()
    if provider == "click":
        q = urlencode({
            "service_id": settings.CLICK_SERVICE_ID, "merchant_id": settings.CLICK_MERCHANT_ID,
            "amount": amount, "transaction_param": str(sub.id), "return_url": settings.PAYMENT_RETURN_URL,
        })
        return f"https://my.click.uz/services/pay?{q}"
    q = urlencode({"merchantId": settings.UZUM_MERCHANT_ID, "amount": amount * 100, "orderId": str(sub.id)})
    return f"https://www.uzumbank.uz/open-service?{q}"


async def create_checkout(db: AsyncSession, user: User, plan_code: str, provider: str) -> Subscription:
    plan = PLANS[plan_code]
    sub = Subscription(
        user_id=user.id, plan=plan.code, status="pending", price=plan.price, currency="UZS",
        payment_provider=provider, auto_renew=plan.code != "lifetime",
    )
    db.add(sub)
    await db.flush()
    return sub


async def revoke_payment(db: AsyncSession, sub: Subscription) -> None:
    """To'lov qaytarilganda (refund) obunani bekor qiladi va Premium'ni olib tashlaydi."""
    sub.status = "cancelled"
    sub.auto_renew = False
    user = await db.get(User, sub.user_id)
    other = await db.scalar(select(Subscription).where(
        Subscription.user_id == user.id, Subscription.status == "active", Subscription.id != sub.id).limit(1))
    if other is None:
        user.is_premium = False
        user.premium_until = None
    await db.flush()


async def apply_payment(db: AsyncSession, sub: Subscription, txn_id: str, pay_status: str, amount: Decimal) -> Subscription:
    """Idempotent: bir xil tranzaksiya qayta kelsa holat o'zgarmaydi."""
    if sub.status == "active" and sub.external_txn_id == txn_id:
        return sub
    if pay_status != "paid":
        sub.status = "cancelled"
        sub.external_txn_id = txn_id
        await db.flush()
        return sub
    if sub.price is not None and Decimal(amount) != Decimal(sub.price):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "To'lov summasi mos emas")

    user = await db.get(User, sub.user_id)
    plan = PLANS[sub.plan]
    now = utcnow()
    base = user.premium_until if (user.premium_until and user.premium_until > now) else now
    sub.status = "active"
    sub.external_txn_id = txn_id
    sub.started_at = now
    sub.expires_at = base + timedelta(days=plan.duration_days) if plan.duration_days else None
    user.is_premium = True
    user.premium_until = sub.expires_at or (now + timedelta(days=365 * 100))
    await db.flush()
    await notify(db, user.id, "subscription", "Premium faollashtirildi!", f"{plan.title} muvaffaqiyatli to'landi", sub.id)
    return sub


def new_sandbox_txn() -> str:
    return f"sandbox-{uuid.uuid4().hex[:12]}"
