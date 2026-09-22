import json
import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import Subscription, User
from app.schemas.subscription import (
    CheckoutIn, CheckoutOut, MySubscription, PlanOut, SubscriptionOut, WebhookIn,
)
from app.services import limits
from app.services.payment_service import (
    PLANS, apply_payment, create_checkout, new_sandbox_txn, payment_url, verify_signature,
)

router = APIRouter(prefix="/subscriptions", tags=["Subscriptions"])


@router.get("/plans", response_model=list[PlanOut])
async def plans():
    return [PlanOut(code=p.code, title=p.title, price=p.price, duration_days=p.duration_days, features=list(p.features))
            for p in PLANS.values()]


@router.post("/checkout", response_model=CheckoutOut, status_code=201)
async def checkout(body: CheckoutIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    sub = await create_checkout(db, user, body.plan, body.provider)
    await db.commit()
    return CheckoutOut(subscription_id=sub.id, provider=body.provider, amount=sub.price,
                       payment_url=payment_url(body.provider, sub), sandbox=settings.PAYMENT_MODE == "sandbox")


@router.post("/webhook/{provider}")
async def webhook(provider: str, request: Request, x_signature: str | None = Header(default=None),
                  db: AsyncSession = Depends(get_db)):
    raw = await request.body()
    verify_signature(provider, raw, x_signature)
    try:
        body = WebhookIn.model_validate(json.loads(raw))
    except (ValueError, ValidationError):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Noto'g'ri webhook formati")
    sub = await db.get(Subscription, body.subscription_id)
    if sub is None or sub.payment_provider != provider:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Obuna topilmadi")
    await apply_payment(db, sub, body.transaction_id, body.status, body.amount)
    await db.commit()
    return {"ok": True, "status": sub.status}


@router.post("/sandbox/confirm/{sub_id}", response_model=SubscriptionOut, include_in_schema=settings.PAYMENT_MODE == "sandbox")
async def sandbox_confirm(sub_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Faqat sandbox rejimi: ilovadagi simulyatsiya to'lovini tasdiqlaydi."""
    if settings.PAYMENT_MODE != "sandbox":
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Not found")
    sub = await db.get(Subscription, sub_id)
    if sub is None or sub.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Obuna topilmadi")
    await apply_payment(db, sub, new_sandbox_txn(), "paid", sub.price)
    await db.commit()
    await db.refresh(sub)
    return sub


@router.get("/me", response_model=MySubscription)
async def my_subscription(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    active = await db.scalar(select(Subscription).where(Subscription.user_id == user.id, Subscription.status == "active")
                             .order_by(Subscription.created_at.desc()).limit(1))
    return MySubscription(
        is_premium=user.is_premium, premium_until=user.premium_until,
        active=SubscriptionOut.model_validate(active) if active else None,
        ai_used_today=await limits.diagnoses_today(db, user),
        ai_daily_limit=None if user.is_premium else settings.FREE_AI_DAILY_LIMIT,
        crops_used=await limits.active_crops(db, user),
        crop_limit=None if user.is_premium else settings.FREE_CROP_LIMIT,
    )


@router.post("/cancel", response_model=SubscriptionOut)
async def cancel(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Avto-yangilanishni o'chiradi; Premium joriy muddat oxirigacha saqlanadi."""
    active = await db.scalar(select(Subscription).where(Subscription.user_id == user.id, Subscription.status == "active")
                             .order_by(Subscription.created_at.desc()).limit(1))
    if active is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Faol obuna yo'q")
    active.auto_renew = False
    active.status = "cancelled"
    await db.commit()
    await db.refresh(active)
    return active


@router.get("/history", response_model=list[SubscriptionOut])
async def history(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(Subscription).where(Subscription.user_id == user.id, Subscription.status != "pending").order_by(Subscription.created_at.desc())
    return list((await db.scalars(stmt)).all())
