from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from jose import JWTError, jwt
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.rate_limit import client_ip, enforce
from app.core.security import (
    create_access_token, hash_password, hash_refresh_token, new_refresh_token, utcnow, verify_password,
)
from app.models import RefreshToken, User
from app.repositories.user_repo import UserRepository
from app.schemas.auth import ForgotPasswordIn, LoginIn, RefreshIn, RegisterIn, ResetPasswordIn, TokenPair
from app.schemas.user import UserMe

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


@router.post("/register", response_model=TokenPair, status_code=201)
async def register(body: RegisterIn, request: Request, db: AsyncSession = Depends(get_db)):
    await enforce(f"register:{client_ip(request)}", 10)
    repo = UserRepository(db)
    email = body.email.lower() if body.email else None
    taken = await repo.exists(username=body.username, email=email, phone=body.phone)
    if taken:
        labels = {"username": "Bu foydalanuvchi nomi", "email": "Bu email", "phone": "Bu telefon raqami"}
        raise HTTPException(status.HTTP_409_CONFLICT, f"{labels[taken]} allaqachon ro'yxatdan o'tgan")
    user = await repo.create(
        full_name=body.full_name.strip(), username=body.username, email=email, phone=body.phone,
        password_hash=hash_password(body.password), region=body.region, language=body.language,
    )
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
    except JWTError:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Token yaroqsiz yoki muddati o'tgan")
    import uuid

    user = await db.get(User, uuid.UUID(payload["sub"])) if payload.get("type") == "reset" else None
    if user is None or user.password_hash[-12:] != payload.get("ph"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Token yaroqsiz yoki allaqachon ishlatilgan")
    user.password_hash = hash_password(body.new_password)
    await db.execute(update(RefreshToken).where(RefreshToken.user_id == user.id).values(revoked=True))
    await db.commit()
    return {"detail": "Parol yangilandi"}


@router.get("/me", response_model=UserMe, include_in_schema=False)
async def auth_me(user: User = Depends(get_current_user)):
    return user
