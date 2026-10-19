"""Bir martalik kodlar (TZ S35). Kod tasodifiy 6 raqam, bazada faqat HMAC-hash saqlanadi va logga yozilmaydi.

Yetkazish: SMS/email provayder hali ulanmagan — `deliver()` False qaytaradi va productionda kanallar e'lon
qilinmaydi (ilova kodli tugmalarni ko'rsatmaydi). Development/test'da kod javobda `dev_code` sifatida qaytadi.
Provayder ulanganda faqat `deliver()` va `available_channels()` o'zgaradi."""
import hashlib
import hmac
import secrets
from datetime import timedelta

from app.core.config import settings
from app.core.security import utcnow
from app.models import AuthChallenge


def dev_codes() -> bool:
    return settings.OTP_DEV_CODES if settings.OTP_DEV_CODES is not None else settings.ENVIRONMENT != "production"


def available_channels() -> list[str]:
    # Haqiqiy provayder yo'q: faqat sinov rejimida ikkala kanal (kod javobda qaytadi)
    return ["sms", "email"] if dev_codes() else []


def deliver(channel: str, destination: str, code: str) -> bool:  # noqa: ARG001 — provayder ulanganda ishlatiladi
    """SMS/email yuborish. Hozircha provayder yo'q."""
    return False


def new_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def code_hash(challenge_id: str, code: str) -> str:
    return hmac.new(settings.SECRET_KEY.encode(), f"{challenge_id}:{code}".encode(), hashlib.sha256).hexdigest()


def set_code(ch: AuthChallenge) -> str:
    """Yangi kod beradi: eski kod yaroqsiz, urinishlar va muddatlar qaytadan."""
    code = new_code()
    now = utcnow()
    ch.code_hash = code_hash(str(ch.id), code)
    ch.attempts = 0
    ch.expires_at = now + timedelta(seconds=settings.OTP_TTL_SECONDS)
    ch.resend_at = now + timedelta(seconds=settings.OTP_RESEND_SECONDS)
    return code


def check(ch: AuthChallenge, code: str) -> bool:
    return hmac.compare_digest(ch.code_hash, code_hash(str(ch.id), code.strip()))


def mask(channel: str, destination: str) -> str:
    if channel == "email":
        name, _, domain = destination.partition("@")
        return f"{name[:2]}{'•' * max(1, len(name) - 2)}@{domain}"
    return f"{destination[:4]} ••• •• {destination[-2:]}" if len(destination) > 6 else destination
