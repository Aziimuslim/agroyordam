"""Payme Merchant API (JSON-RPC 2.0) — https://developer.help.paycom.uz

Payme serveri bizning `POST /api/v1/payments/payme` manzilimizga quyidagi metodlarni yuboradi:
CheckPerformTransaction, CreateTransaction, PerformTransaction, CancelTransaction,
CheckTransaction, GetStatement. Summalar tiyinda, vaqtlar millisekundlarda.
"""
import base64
import binascii
import time
import uuid
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models import PaymentTransaction, Subscription
from app.services.payment_service import apply_payment, revoke_payment

# Payme xato kodlari
AUTH_FAILED = -32504
METHOD_NOT_FOUND = -32601
INVALID_REQUEST = -32600
WRONG_AMOUNT = -31001
TXN_NOT_FOUND = -31003
CANT_CANCEL = -31007
CANT_PERFORM = -31008
ORDER_NOT_FOUND = -31050
ORDER_BUSY = -31051  # buyurtma uchun boshqa tranzaksiya mavjud yoki allaqachon to'langan

MESSAGES = {
    AUTH_FAILED: ("Avtorizatsiya xatosi", "Недостаточно привилегий", "Insufficient privilege"),
    METHOD_NOT_FOUND: ("Metod topilmadi", "Метод не найден", "Method not found"),
    INVALID_REQUEST: ("Noto'g'ri so'rov", "Неверный запрос", "Invalid request"),
    WRONG_AMOUNT: ("Noto'g'ri summa", "Неверная сумма", "Incorrect amount"),
    TXN_NOT_FOUND: ("Tranzaksiya topilmadi", "Транзакция не найдена", "Transaction not found"),
    CANT_CANCEL: ("Tranzaksiyani bekor qilib bo'lmaydi", "Невозможно отменить транзакцию", "Unable to cancel"),
    CANT_PERFORM: ("Amalni bajarib bo'lmaydi", "Невозможно выполнить операцию", "Unable to perform operation"),
    ORDER_NOT_FOUND: ("Buyurtma topilmadi", "Заказ не найден", "Order not found"),
    ORDER_BUSY: ("Buyurtma band yoki to'langan", "Заказ уже оплачивается или оплачен", "Order is busy or already paid"),
}


class PaymeError(Exception):
    def __init__(self, code: int, data: str | None = None) -> None:
        self.code, self.data = code, data


def now_ms() -> int:
    return int(time.time() * 1000)


def check_auth(header: str | None) -> bool:
    if not header or not header.startswith("Basic "):
        return False
    try:
        login, _, key = base64.b64decode(header[6:]).decode().partition(":")
    except (binascii.Error, UnicodeDecodeError):
        return False
    return login == "Paycom" and key == settings.PAYME_SECRET_KEY


def error_response(req_id, code: int, data: str | None = None) -> dict:
    uz, ru, en = MESSAGES.get(code, ("Xatolik", "Ошибка", "Error"))
    err = {"code": code, "message": {"uz": uz, "ru": ru, "en": en}}
    if data:
        err["data"] = data
    return {"jsonrpc": "2.0", "id": req_id, "error": err}


def _tiyin(sub: Subscription) -> int:
    return int(Decimal(sub.price or 0) * 100)


async def _order(db: AsyncSession, account: dict | None, amount) -> Subscription:
    field = settings.PAYME_ACCOUNT_FIELD
    try:
        sub = await db.get(Subscription, uuid.UUID(str((account or {}).get(field))))
    except (ValueError, TypeError):
        sub = None
    if sub is None or sub.payment_provider != "payme":
        raise PaymeError(ORDER_NOT_FOUND, field)
    if sub.status != "pending":
        raise PaymeError(ORDER_BUSY, field)
    if not isinstance(amount, int) or amount != _tiyin(sub):
        raise PaymeError(WRONG_AMOUNT)
    return sub


async def _txn(db: AsyncSession, payme_id) -> PaymentTransaction:
    txn = await db.scalar(select(PaymentTransaction).where(
        PaymentTransaction.provider == "payme", PaymentTransaction.provider_txn_id == str(payme_id)))
    if txn is None:
        raise PaymeError(TXN_NOT_FOUND)
    return txn


async def _expire_if_needed(db: AsyncSession, txn: PaymentTransaction) -> bool:
    if txn.state == 1 and now_ms() - txn.create_time > settings.PAYME_TIMEOUT_MS:
        txn.state, txn.reason, txn.cancel_time = -1, 4, now_ms()
        sub = await db.get(Subscription, txn.subscription_id)
        sub.status = "cancelled"
        await db.commit()  # xato javobi qaytsa ham bekor qilish saqlanib qolishi kerak
        return True
    return False


async def check_perform(db: AsyncSession, p: dict) -> dict:
    await _order(db, p.get("account"), p.get("amount"))
    return {"allow": True}


async def create(db: AsyncSession, p: dict) -> dict:
    existing = await db.scalar(select(PaymentTransaction).where(
        PaymentTransaction.provider == "payme", PaymentTransaction.provider_txn_id == str(p.get("id"))))
    if existing:
        if existing.state != 1 or await _expire_if_needed(db, existing):
            raise PaymeError(CANT_PERFORM)
        return {"create_time": existing.create_time, "transaction": str(existing.id), "state": existing.state}
    sub = await _order(db, p.get("account"), p.get("amount"))
    busy = await db.scalar(select(PaymentTransaction.id).where(
        PaymentTransaction.subscription_id == sub.id, PaymentTransaction.state == 1))
    if busy:
        raise PaymeError(ORDER_BUSY, settings.PAYME_ACCOUNT_FIELD)
    txn = PaymentTransaction(provider="payme", provider_txn_id=str(p["id"]), subscription_id=sub.id,
                             amount=Decimal(p["amount"]) / 100, state=1, provider_time=p.get("time"), create_time=now_ms())
    db.add(txn)
    await db.flush()
    return {"create_time": txn.create_time, "transaction": str(txn.id), "state": 1}


async def perform(db: AsyncSession, p: dict) -> dict:
    txn = await _txn(db, p.get("id"))
    if txn.state == 1:
        if await _expire_if_needed(db, txn):
            raise PaymeError(CANT_PERFORM)
        sub = await db.get(Subscription, txn.subscription_id)
        await apply_payment(db, sub, f"payme:{txn.provider_txn_id}", "paid", sub.price)
        txn.state, txn.perform_time = 2, now_ms()
        await db.flush()
    elif txn.state != 2:
        raise PaymeError(CANT_PERFORM)
    return {"transaction": str(txn.id), "perform_time": txn.perform_time, "state": txn.state}


async def cancel(db: AsyncSession, p: dict) -> dict:
    txn = await _txn(db, p.get("id"))
    sub = await db.get(Subscription, txn.subscription_id)
    if txn.state == 1:
        txn.state = -1
        sub.status = "cancelled"
    elif txn.state == 2:
        txn.state = -2
        await revoke_payment(db, sub)
    if txn.cancel_time == 0:
        txn.cancel_time, txn.reason = now_ms(), p.get("reason")
    await db.flush()
    return {"transaction": str(txn.id), "cancel_time": txn.cancel_time, "state": txn.state}


async def check(db: AsyncSession, p: dict) -> dict:
    txn = await _txn(db, p.get("id"))
    return {"create_time": txn.create_time, "perform_time": txn.perform_time, "cancel_time": txn.cancel_time,
            "transaction": str(txn.id), "state": txn.state, "reason": txn.reason}


async def statement(db: AsyncSession, p: dict) -> dict:
    rows = (await db.scalars(select(PaymentTransaction).where(
        PaymentTransaction.provider == "payme",
        PaymentTransaction.provider_time >= p.get("from", 0),
        PaymentTransaction.provider_time <= p.get("to", 0),
    ).order_by(PaymentTransaction.provider_time))).all()
    return {"transactions": [{
        "id": t.provider_txn_id, "time": t.provider_time, "amount": int(Decimal(t.amount) * 100),
        "account": {settings.PAYME_ACCOUNT_FIELD: str(t.subscription_id)},
        "create_time": t.create_time, "perform_time": t.perform_time, "cancel_time": t.cancel_time,
        "transaction": str(t.id), "state": t.state, "reason": t.reason,
    } for t in rows]}


METHODS = {
    "CheckPerformTransaction": check_perform,
    "CreateTransaction": create,
    "PerformTransaction": perform,
    "CancelTransaction": cancel,
    "CheckTransaction": check,
    "GetStatement": statement,
}
