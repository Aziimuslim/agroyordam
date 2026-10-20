from datetime import datetime, timedelta, timezone
import re
import secrets
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
import jwt
from pydantic import EmailStr, TypeAdapter, ValidationError
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.rate_limit import client_ip, enforce
from app.core.security import (
    create_access_token, hash_password, hash_refresh_token, new_refresh_token, utcnow, verify_password,
)
from app.models import AuthChallenge, RefreshToken, User
from app.repositories.user_repo import UserRepository
from app.schemas.auth import (
    AuthOptions, ChallengeIn, ChallengeOut, ContactIn, ForgotPasswordIn, LoginIn, RecoveryResetIn, RefreshIn, RegisterIn, ResetPasswordIn, TokenPair, VerifyIn, VerifyOut,
)
from app.schemas.user import UserMe
from app.services import otp_service

router = APIRouter(prefix="/auth", tags=["Auth"])


async def issue_tokens(db: AsyncSession, user: User) -> TokenPair:
    raw, hashed = new_refresh_token()
    db.add(RefreshToken(user_id=user.id, token_hash=hashed,
                        expires_at=utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)))
    await db.commit()
    return TokenPair(
        access_token=create_access_token(user.id, user.role),
        refresh_token=raw,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


TAKEN = {
    "username": "Bu foydalanuvchi nomi allaqachon ro'yxatdan o'tgan",
    "email": "Bu email allaqachon ro'yxatdan o'tgan",
    "phone": "Bu telefon raqami allaqachon ro'yxatdan o'tgan",
}


async def unique_username(db: AsyncSession, base: str) -> str:
    """Forma username so'ramaydi (TZ S34): ism yoki emaildan lotin harflarida yasaladi va noyob qilinadi."""
    stem = re.sub(r"[^a-z0-9_]", "", base.lower().replace(" ", "_"))[:20].strip("_") or "fermer"
    if len(stem) < 3:
        stem = f"fermer_{stem}"
    candidate = stem
    repo = UserRepository(db)
    while await repo.exists(username=candidate):
        candidate = f"{stem}_{secrets.randbelow(10_000):04d}"
    return candidate


@router.post("/register", response_model=TokenPair, status_code=201)
async def register(body: RegisterIn, request: Request, db: AsyncSession = Depends(get_db)):
    """To'g'ridan-to'g'ri ro'yxatdan o'tish — kod yuborish kanali ulanmagan bo'lsa (va eski ilovalar uchun)."""
    await enforce(f"register:{client_ip(request)}", 10)
    repo = UserRepository(db)
    email = body.email.lower() if body.email else None
    taken = await repo.exists(username=body.username, email=email, phone=body.phone)
    if taken:
        raise HTTPException(status.HTTP_409_CONFLICT, TAKEN[taken])
    username = body.username or await unique_username(db, (email or "").split("@")[0] or body.full_name)
    user = await repo.create(
        full_name=body.full_name.strip(), username=username, email=email, phone=body.phone,
        password_hash=hash_password(body.password), region=body.region, language=body.language,
    )
    if body.accept_terms:
        user.terms_version, user.terms_accepted_at = settings.TERMS_VERSION, utcnow()
    return await issue_tokens(db, user)


@router.post("/login", response_model=TokenPair)
async def login(body: LoginIn, request: Request, db: AsyncSession = Depends(get_db)):
    await enforce(f"login:{client_ip(request)}", settings.LOGIN_RATE_LIMIT_PER_MINUTE)
    user = await UserRepository(db).by_login(body.login)
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Login yoki parol noto'g'ri")
    if not user.is_active:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Hisob bloklangan")
    return await issue_tokens(db, user)


@router.post("/refresh", response_model=TokenPair)
async def refresh(body: RefreshIn, db: AsyncSession = Depends(get_db)):
    token = await db.scalar(select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(body.refresh_token)))
    if token is None or token.revoked or token.expires_at < utcnow():
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Refresh token yaroqsiz")
    user = await db.get(User, token.user_id)
    if user is None or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Foydalanuvchi faol emas")
    token.revoked = True  # rotatsiya
    return await issue_tokens(db, user)


@router.post("/logout", status_code=204)
async def logout(body: RefreshIn | None = None, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = update(RefreshToken).where(RefreshToken.user_id == user.id)
    if body is not None:
        stmt = stmt.where(RefreshToken.token_hash == hash_refresh_token(body.refresh_token))
    await db.execute(stmt.values(revoked=True))
    await db.commit()


def _reset_token(user: User) -> str:
    exp = datetime.now(timezone.utc) + timedelta(minutes=30)
    # parol hash'ining bir qismi tokenni bir martalik qiladi
    return jwt.encode({"sub": str(user.id), "type": "reset", "ph": user.password_hash[-12:], "exp": exp},
                      settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


@router.post("/forgot-password")
async def forgot_password(body: ForgotPasswordIn, request: Request, db: AsyncSession = Depends(get_db)):
    await enforce(f"forgot:{client_ip(request)}", 5)
    user = await UserRepository(db).by_login(body.login)
    resp: dict = {"detail": "Agar hisob mavjud bo'lsa, tiklash havolasi yuborildi"}
    if user is not None:
        token = _reset_token(user)
        # TODO: email/SMS provayder ulanganda token shu yerda yuboriladi
        if settings.ENVIRONMENT != "production":
            resp["dev_reset_token"] = token
    return resp


@router.post("/reset-password")
async def reset_password(body: ResetPasswordIn, db: AsyncSession = Depends(get_db)):
    try:
        payload = jwt.decode(body.token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
    except jwt.PyJWTError:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Token yaroqsiz yoki muddati o'tgan")
    user = await db.get(User, uuid.UUID(payload["sub"])) if payload.get("type") == "reset" else None
    if user is None or user.password_hash[-12:] != payload.get("ph"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Token yaroqsiz yoki allaqachon ishlatilgan")
    user.password_hash = hash_password(body.new_password)
    await db.execute(update(RefreshToken).where(RefreshToken.user_id == user.id).values(revoked=True))
    await db.commit()
    return {"detail": "Parol yangilandi"}


# ---------- Bir martalik kod (TZ S33–S36) ----------

@router.get("/options", response_model=AuthOptions)
async def auth_options():
    """Ilova qaysi oqimlarni ko'rsatishini shu javobga qarab hal qiladi: kanal yo'q bo'lsa kodli tugmalar chiqmaydi."""
    return AuthOptions(channels=otp_service.available_channels(), dev_codes=otp_service.dev_codes(),
                       terms_version=settings.TERMS_VERSION, otp_ttl=settings.OTP_TTL_SECONDS,
                       otp_resend=settings.OTP_RESEND_SECONDS)


def _normalize(channel: str, destination: str) -> str:
    d = destination.strip()
    if channel == "sms":
        d = re.sub(r"[\s\-()]", "", d)
        if not re.fullmatch(r"\+[1-9]\d{7,14}", d):
            raise HTTPException(422, "Telefon raqami +998901234567 ko'rinishida bo'lsin")
        return d
    try:
        return str(TypeAdapter(EmailStr).validate_python(d)).lower()
    except ValidationError:
        raise HTTPException(422, "Email noto'g'ri")


def _out(ch: AuthChallenge, code: str) -> ChallengeOut:
    now = utcnow()
    return ChallengeOut(
        challenge_id=str(ch.id), purpose=ch.purpose, channel=ch.channel,
        destination_masked=otp_service.mask(ch.channel, ch.destination),
        expires_in=max(0, int((ch.expires_at - now).total_seconds())),
        resend_in=max(0, int((ch.resend_at - now).total_seconds())),
        attempts_left=max(0, settings.OTP_MAX_ATTEMPTS - ch.attempts),
        dev_code=code if otp_service.dev_codes() else None,
    )


@router.post("/challenges", response_model=ChallengeOut, status_code=201)
async def create_challenge(body: ChallengeIn, request: Request, db: AsyncSession = Depends(get_db)):
    if body.channel not in otp_service.available_channels():
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Kod yuborish xizmati hozircha ulanmagan")
    dest = _normalize(body.channel, body.destination)
    await enforce(f"otp:{client_ip(request)}", 10)
    await enforce(f"otp-dest:{dest}", 5, 600)
    repo = UserRepository(db)
    user = await repo.by_login(dest)
    payload = None
    if body.purpose == "register":
        if body.signup is None:
            raise HTTPException(422, "Ro'yxatdan o'tish ma'lumotlari kerak")
        if not body.signup.accept_terms:
            raise HTTPException(422, "Qoidalarga rozilik kerak")
        if user is not None:
            raise HTTPException(status.HTTP_409_CONFLICT, TAKEN["phone" if body.channel == "sms" else "email"])
        r = body.signup
        payload = {"full_name": r.full_name.strip(), "password_hash": hash_password(r.password), "region": r.region,
                   "language": r.language, "terms_version": settings.TERMS_VERSION}
        user = None
    elif user is not None and not user.is_active:
        user = None  # bloklangan hisob — tashqi javob bir xil, kod hech narsa bermaydi
    # login/recovery: hisob bo'lmasa ham bir xil javob (mavjudligi oshkor qilinmaydi)
    ch = AuthChallenge(id=uuid.uuid4(), purpose=body.purpose, channel=body.channel, destination=dest,
                       user_id=user.id if user else None, payload=payload, code_hash="", resend_at=utcnow(), expires_at=utcnow())
    code = otp_service.set_code(ch)
    db.add(ch)
    await db.commit()
    if user is not None or body.purpose == "register":
        otp_service.deliver(body.channel, dest, code)
    return _out(ch, code)


async def _challenge(db: AsyncSession, cid: uuid.UUID) -> AuthChallenge:
    ch = await db.get(AuthChallenge, cid)
    if ch is None or ch.consumed_at is not None:
        raise HTTPException(status.HTTP_410_GONE, "Kod muddati tugagan. Yangi kod so'rang.")
    return ch


@router.post("/challenges/{cid}/resend", response_model=ChallengeOut)
async def resend_challenge(cid: uuid.UUID, db: AsyncSession = Depends(get_db)):
    ch = await _challenge(db, cid)
    wait = int((ch.resend_at - utcnow()).total_seconds())
    if wait > 0:  # server soati bo'yicha — qurilma soatini o'zgartirish yordam bermaydi
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Kodni qayta yuborish uchun biroz kuting",
                            headers={"Retry-After": str(wait)})
    if ch.resends >= settings.OTP_MAX_RESENDS:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Juda ko'p urinish. Birozdan so'ng qayta urinib ko'ring.",
                            headers={"Retry-After": "600"})
    ch.resends += 1
    code = otp_service.set_code(ch)
    await db.commit()
    if ch.user_id is not None or ch.purpose == "register":
        otp_service.deliver(ch.channel, ch.destination, code)
    return _out(ch, code)


def _recovery_token(user: User, cid: uuid.UUID) -> str:
    exp = datetime.now(timezone.utc) + timedelta(minutes=settings.RECOVERY_TOKEN_MINUTES)
    # "recovery" turi access sifatida qabul qilinmaydi; parol hash'i bo'lagi uni bir martalik qiladi
    return jwt.encode({"sub": str(user.id), "type": "recovery", "cid": str(cid), "ph": user.password_hash[-12:], "exp": exp},
                      settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


@router.post("/challenges/{cid}/verify", response_model=VerifyOut)
async def verify_challenge(cid: uuid.UUID, body: VerifyIn, request: Request, db: AsyncSession = Depends(get_db)):
    await enforce(f"otp-verify:{client_ip(request)}", 30)
    ch = await _challenge(db, cid)
    if ch.purpose == "contact":  # kontakt kodi faqat o'z (avtorizatsiyali) endpointida tekshiriladi
        raise HTTPException(status.HTTP_410_GONE, "Kod muddati tugagan. Yangi kod so'rang.")
    if ch.expires_at < utcnow():
        raise HTTPException(status.HTTP_410_GONE, "Kod muddati tugagan. Yangi kod so'rang.")
    if ch.attempts >= settings.OTP_MAX_ATTEMPTS:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Urinishlar tugadi. Yangi kod so'rang.",
                            headers={"Retry-After": str(max(0, int((ch.resend_at - utcnow()).total_seconds())))})
    ok = otp_service.check(ch, body.code)
    # Hisob yo'q (login/recovery) — kod to'g'ri bo'lsa ham hech narsa berilmaydi
    if not ok or (ch.purpose != "register" and ch.user_id is None):
        ch.attempts += 1
        left = max(0, settings.OTP_MAX_ATTEMPTS - ch.attempts)
        await db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Kod noto'g'ri", headers={"X-Attempts-Left": str(left)})
    ch.consumed_at = utcnow()  # kod bir marta ishlaydi

    if ch.purpose == "register":
        p = ch.payload or {}
        repo = UserRepository(db)
        field = "phone" if ch.channel == "sms" else "email"
        if await repo.exists(**{field: ch.destination}):
            await db.commit()
            raise HTTPException(status.HTTP_409_CONFLICT, TAKEN[field])
        user = await repo.create(
            full_name=p["full_name"], username=await unique_username(db, ch.destination.split("@")[0] if field == "email" else p["full_name"]),
            password_hash=p["password_hash"], region=p.get("region"), language=p.get("language") or "uz",
            **{field: ch.destination},
        )
        user.terms_version, user.terms_accepted_at = p.get("terms_version"), utcnow()
        tokens = await issue_tokens(db, user)
        return VerifyOut(result="session", **tokens.model_dump(exclude={"token_type"}))

    user = await db.get(User, ch.user_id)
    if user is None or not user.is_active:
        await db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Kod noto'g'ri", headers={"X-Attempts-Left": "0"})
    if ch.purpose == "login":
        tokens = await issue_tokens(db, user)
        return VerifyOut(result="session", **tokens.model_dump(exclude={"token_type"}))
    await db.commit()
    return VerifyOut(result="recovery", recovery_token=_recovery_token(user, ch.id), expires_in=settings.RECOVERY_TOKEN_MINUTES * 60)


@router.post("/contact", response_model=ChallengeOut, status_code=201)
async def request_contact_change(body: ContactIn, request: Request, user: User = Depends(get_current_user),
                                 db: AsyncSession = Depends(get_db)):
    """TZ S24: telefon/email o'zgarishi yangi manzilga yuborilgan kod bilan tasdiqlanadi (S35 qoidalari: TTL, qayta
    yuborish — /auth/challenges/{id}/resend, urinishlar)."""
    if body.channel not in otp_service.available_channels():
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Kod yuborish xizmati hozircha ulanmagan")
    dest = _normalize(body.channel, body.destination)
    field = "phone" if body.channel == "sms" else "email"
    if (getattr(user, field) or "").lower() == dest.lower():
        raise HTTPException(status.HTTP_409_CONFLICT, "Bu manzil allaqachon profilingizda")
    await enforce(f"otp:{client_ip(request)}", 10)
    await enforce(f"otp-dest:{dest}", 5, 600)
    if await UserRepository(db).by_login(dest) is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, TAKEN[field])
    ch = AuthChallenge(id=uuid.uuid4(), purpose="contact", channel=body.channel, destination=dest, user_id=user.id,
                       code_hash="", resend_at=utcnow(), expires_at=utcnow())
    code = otp_service.set_code(ch)
    db.add(ch)
    await db.commit()
    otp_service.deliver(body.channel, dest, code)
    return _out(ch, code)


@router.post("/contact/{cid}/verify", response_model=UserMe)
async def verify_contact_change(cid: uuid.UUID, body: VerifyIn, request: Request, user: User = Depends(get_current_user),
                                db: AsyncSession = Depends(get_db)):
    await enforce(f"otp-verify:{client_ip(request)}", 30)
    ch = await _challenge(db, cid)
    if ch.purpose != "contact" or ch.user_id != user.id or ch.expires_at < utcnow():
        raise HTTPException(status.HTTP_410_GONE, "Kod muddati tugagan. Yangi kod so'rang.")
    if ch.attempts >= settings.OTP_MAX_ATTEMPTS:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Urinishlar tugadi. Yangi kod so'rang.",
                            headers={"Retry-After": str(max(0, int((ch.resend_at - utcnow()).total_seconds())))})
    if not otp_service.check(ch, body.code):
        ch.attempts += 1
        await db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Kod noto'g'ri",
                            headers={"X-Attempts-Left": str(max(0, settings.OTP_MAX_ATTEMPTS - ch.attempts))})
    ch.consumed_at = utcnow()
    field = "phone" if ch.channel == "sms" else "email"
    if await UserRepository(db).by_login(ch.destination) is not None:
        await db.commit()
        raise HTTPException(status.HTTP_409_CONFLICT, TAKEN[field])
    setattr(user, field, ch.destination)
    await db.commit()
    await db.refresh(user)
    return user


@router.post("/recovery/reset")
async def recovery_reset(body: RecoveryResetIn, db: AsyncSession = Depends(get_db)):
    """S36: yangi parol faqat recovery token bilan; muvaffaqiyatda barcha seanslar tugatiladi."""
    try:
        payload = jwt.decode(body.recovery_token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
    except jwt.PyJWTError:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Havola yaroqsiz yoki muddati o'tgan")
    user = await db.get(User, uuid.UUID(payload["sub"])) if payload.get("type") == "recovery" else None
    if user is None or user.password_hash[-12:] != payload.get("ph"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Havola yaroqsiz, ishlatilgan yoki muddati o'tgan")
    user.password_hash = hash_password(body.new_password)
    await db.execute(update(RefreshToken).where(RefreshToken.user_id == user.id).values(revoked=True))
    await db.commit()
    return {"detail": "Parol yangilandi"}


@router.get("/me", response_model=UserMe, include_in_schema=False)
async def auth_me(user: User = Depends(get_current_user)):
    return user
