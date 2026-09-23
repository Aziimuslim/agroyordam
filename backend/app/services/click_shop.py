"""Click SHOP API — https://docs.click.uz/click-api-request

Click serveri ikki bosqichda so'rov yuboradi (application/x-www-form-urlencoded):
  Prepare  (action=0): POST /api/v1/payments/click/prepare
  Complete (action=1): POST /api/v1/payments/click/complete
Har bir so'rov md5 imzo (sign_string) bilan tekshiriladi.
"""
import hashlib
import time
import uuid
from decimal import Decimal, InvalidOperation

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models import PaymentTransaction, Subscription
from app.services.payment_service import apply_payment

SUCCESS = 0
SIGN_FAILED = -1
WRONG_AMOUNT = -2
ACTION_NOT_FOUND = -3
ALREADY_PAID = -4
ORDER_NOT_FOUND = -5
TXN_NOT_FOUND = -6
BAD_REQUEST = -8
TXN_CANCELLED = -9

NOTES = {
    SUCCESS: "Success", SIGN_FAILED: "SIGN CHECK FAILED!", WRONG_AMOUNT: "Incorrect parameter amount",
    ACTION_NOT_FOUND: "Action not found", ALREADY_PAID: "Already paid", ORDER_NOT_FOUND: "User does not exist",
    TXN_NOT_FOUND: "Transaction does not exist", BAD_REQUEST: "Error in request from click",
    TXN_CANCELLED: "Transaction cancelled",
}


def sign(f: dict, with_prepare: bool) -> str:
    parts = [f.get("click_trans_id", ""), f.get("service_id", ""), settings.CLICK_SECRET_KEY, f.get("merchant_trans_id", "")]
    if with_prepare:
        parts.append(f.get("merchant_prepare_id", ""))
    parts += [f.get("amount", ""), f.get("action", ""), f.get("sign_time", "")]
    return hashlib.md5("".join(str(x) for x in parts).encode()).hexdigest()


def reply(f: dict, error: int, **extra) -> dict:
    return {"click_trans_id": f.get("click_trans_id"), "merchant_trans_id": f.get("merchant_trans_id"),
            "error": error, "error_note": NOTES.get(error, "Error"), **extra}


async def _sub(db: AsyncSession, f: dict) -> Subscription | None:
    try:
        sub = await db.get(Subscription, uuid.UUID(str(f.get("merchant_trans_id"))))
    except ValueError:
        return None
    return sub if sub and sub.payment_provider == "click" else None


def _amount_ok(f: dict, sub: Subscription) -> bool:
    try:
        return Decimal(str(f.get("amount"))) == Decimal(sub.price)
    except (InvalidOperation, TypeError):
        return False


def _service_ok(f: dict) -> bool:
    return not settings.CLICK_SERVICE_ID or str(f.get("service_id")) == str(settings.CLICK_SERVICE_ID)


async def prepare(db: AsyncSession, f: dict) -> dict:
    if not f.get("sign_string") or f.get("sign_string") != sign(f, with_prepare=False) or not _service_ok(f):
        return reply(f, SIGN_FAILED)
    if str(f.get("action")) != "0":
        return reply(f, ACTION_NOT_FOUND)
    sub = await _sub(db, f)
    if sub is None:
        return reply(f, ORDER_NOT_FOUND)
    if sub.status == "active":
        return reply(f, ALREADY_PAID)
    if sub.status != "pending":
        return reply(f, TXN_CANCELLED)
    if not _amount_ok(f, sub):
        return reply(f, WRONG_AMOUNT)
    txn = await db.scalar(select(PaymentTransaction).where(
        PaymentTransaction.provider == "click", PaymentTransaction.provider_txn_id == str(f["click_trans_id"])))
    if txn is None:
        txn = PaymentTransaction(provider="click", provider_txn_id=str(f["click_trans_id"]), subscription_id=sub.id,
                                 amount=Decimal(sub.price), state=1, create_time=int(time.time() * 1000))
        db.add(txn)
        await db.flush()
    return reply(f, SUCCESS, merchant_prepare_id=int(f["click_trans_id"]))


async def complete(db: AsyncSession, f: dict) -> dict:
    if not f.get("sign_string") or f.get("sign_string") != sign(f, with_prepare=True) or not _service_ok(f):
        return reply(f, SIGN_FAILED)
    if str(f.get("action")) != "1":
        return reply(f, ACTION_NOT_FOUND)
    sub = await _sub(db, f)
    if sub is None:
        return reply(f, ORDER_NOT_FOUND)
    txn = await db.scalar(select(PaymentTransaction).where(
        PaymentTransaction.provider == "click", PaymentTransaction.provider_txn_id == str(f.get("click_trans_id"))))
    if txn is None or str(f.get("merchant_prepare_id")) != txn.provider_txn_id:
        return reply(f, TXN_NOT_FOUND)
    if txn.state == 2:
        return reply(f, ALREADY_PAID, merchant_confirm_id=int(txn.provider_txn_id))
    if txn.state < 0:
        return reply(f, TXN_CANCELLED)
    if not _amount_ok(f, sub):
        return reply(f, WRONG_AMOUNT)
    try:
        click_error = int(f.get("error", 0))
    except ValueError:
        return reply(f, BAD_REQUEST)
    now = int(time.time() * 1000)
    if click_error < 0:  # Click tomonida to'lov amalga oshmadi
        txn.state, txn.cancel_time = -1, now
        sub.status = "cancelled"
        await db.flush()
        return reply(f, TXN_CANCELLED)
    await apply_payment(db, sub, f"click:{txn.provider_txn_id}", "paid", sub.price)
    txn.state, txn.perform_time = 2, now
    await db.flush()
    return reply(f, SUCCESS, merchant_confirm_id=int(txn.provider_txn_id))
