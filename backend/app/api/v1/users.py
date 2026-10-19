import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.rate_limit import enforce
from app.core.security import hash_password, hash_refresh_token, verify_password
from app.models import Follower, Post, RefreshToken, User, UserBlock
from app.schemas.user import EXPERT_FIELDS, UserMe, UserProfile, UserPublic, UserUpdate
from app.services import block_service
from app.services.notification_service import notify
from app.services.storage import get_storage, read_image

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserMe)
async def me(user: User = Depends(get_current_user)):
    return user


@router.put("/me", response_model=UserMe)
async def update_me(body: UserUpdate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    data = body.model_dump(exclude_unset=True)
    if data.get("full_name") is None:
        data.pop("full_name", None)  # ismni o'chirib bo'lmaydi
    if "email" in data and data["email"]:
        data["email"] = data["email"].lower()
    if user.role != "agronomist":
        for k in EXPERT_FIELDS:
            data.pop(k, None)
    for k, v in data.items():
        if isinstance(v, str):
            v = v.strip() or None  # bo'sh matn = ko'rsatilmagan
        if isinstance(v, list):
            v = list(dict.fromkeys(v)) or None  # takrorlarsiz
        if k == "full_name" and not v:
            continue
        setattr(user, k, v)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Email yoki telefon band")
    await db.refresh(user)
    return user


class PasswordChangeIn(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)
    refresh_token: str | None = None  # joriy seans saqlanadi
    # TZ S28: boshqa seanslardan chiqish — ixtiyoriy. Maydon yuborilmasa (eski ilova) avvalgidek chiqariladi.
    logout_others: bool | None = None


@router.put("/me/password", status_code=204)
async def change_password(body: PasswordChangeIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if not verify_password(body.current_password, user.password_hash):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Joriy parol noto'g'ri")
    if body.new_password == body.current_password:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Yangi parol eskisidan farq qilishi kerak")
    user.password_hash = hash_password(body.new_password)
    if body.logout_others is not False:
        stmt = update(RefreshToken).where(RefreshToken.user_id == user.id)
        if body.refresh_token:
            stmt = stmt.where(RefreshToken.token_hash != hash_refresh_token(body.refresh_token))
        await db.execute(stmt.values(revoked=True))
    await db.commit()


@router.post("/me/avatar", response_model=UserMe)
async def upload_avatar(file: UploadFile = File(...), user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    data, ext = await read_image(file)
    user.avatar_url = get_storage().save(data, ext, "avatars")
    await db.commit()
    await db.refresh(user)
    return user


@router.get("/search", response_model=list[UserPublic])
async def search_users(q: str = "", me_: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """A07: ism yoki foydalanuvchi nomi bo'yicha (kamida 2 belgi). Telefon/email bo'yicha qidirilmaydi;
    bloklangan va faol bo'lmagan hisoblar chiqmaydi. Faqat ommaviy minimal profil."""
    term = q.strip().lstrip("@")
    if len(term) < 2:
        return []
    await enforce(f"user-search:{me_.id}", 60)
    like = f"%{term.replace('%', '').replace('_', '')}%"
    hidden = await block_service.hidden_ids(db, me_.id)
    stmt = (select(User).where(User.is_active.is_(True), User.id != me_.id,
                               or_(User.full_name.ilike(like), User.username.ilike(like)))
            .order_by(User.full_name).limit(20))
    if hidden:
        stmt = stmt.where(User.id.not_in(hidden))
    return list((await db.scalars(stmt)).all())


@router.get("/me/blocks", response_model=list[UserPublic])
async def my_blocks(me_: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(User).join(UserBlock, UserBlock.blocked_id == User.id).where(UserBlock.blocker_id == me_.id).order_by(UserBlock.created_at.desc())
    return list((await db.scalars(stmt)).all())


async def _get_user(db: AsyncSession, user_id: uuid.UUID) -> User:
    u = await db.get(User, user_id)
    if u is None or not u.is_active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Foydalanuvchi topilmadi")
    return u


@router.get("/{user_id}", response_model=UserProfile)
async def get_user(user_id: uuid.UUID, me_: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    u = await _get_user(db, user_id)
    cnt = lambda *w: db.scalar(select(func.count()).where(*w))  # noqa: E731
    return UserProfile(
        **UserPublic.model_validate(u).model_dump(),
        about=u.about,
        district=u.district,
        followers_count=await cnt(Follower.following_id == u.id),
        following_count=await cnt(Follower.follower_id == u.id),
        posts_count=await cnt(Post.user_id == u.id),
        is_following=bool(await db.scalar(select(Follower.id).where(Follower.follower_id == me_.id, Follower.following_id == u.id))),
        is_blocked=await block_service.i_blocked(db, me_.id, u.id),
    )


@router.post("/{user_id}/block", status_code=204)
async def block_user(user_id: uuid.UUID, me_: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """A08: postlar, izohlar va qidiruvda bir-birini ko'rmaydi; yozishma va obuna to'xtaydi."""
    if user_id == me_.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "O'zingizni bloklab bo'lmaydi")
    await _get_user(db, user_id)
    if not await block_service.i_blocked(db, me_.id, user_id):
        db.add(UserBlock(blocker_id=me_.id, blocked_id=user_id))
        await db.execute(delete(Follower).where(or_(
            (Follower.follower_id == me_.id) & (Follower.following_id == user_id),
            (Follower.follower_id == user_id) & (Follower.following_id == me_.id))))
        await db.commit()


@router.delete("/{user_id}/block", status_code=204)
async def unblock_user(user_id: uuid.UUID, me_: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await db.execute(delete(UserBlock).where(UserBlock.blocker_id == me_.id, UserBlock.blocked_id == user_id))
    await db.commit()


@router.post("/{user_id}/follow", status_code=204)
async def follow(user_id: uuid.UUID, me_: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if user_id == me_.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "O'zingizga obuna bo'lolmaysiz")
    await _get_user(db, user_id)
    if await block_service.between(db, me_.id, user_id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Bu foydalanuvchiga obuna bo'lib bo'lmaydi")
    exists = await db.scalar(select(Follower.id).where(Follower.follower_id == me_.id, Follower.following_id == user_id))
    if not exists:
        db.add(Follower(follower_id=me_.id, following_id=user_id))
        await notify(db, user_id, "follow", "Yangi obunachi", f"{me_.full_name} sizga obuna bo'ldi", me_.id)
        await db.commit()


@router.delete("/{user_id}/follow", status_code=204)
async def unfollow(user_id: uuid.UUID, me_: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    f = await db.scalar(select(Follower).where(Follower.follower_id == me_.id, Follower.following_id == user_id))
    if f:
        await db.delete(f)
        await db.commit()


@router.get("/{user_id}/followers", response_model=list[UserPublic])
async def followers(user_id: uuid.UUID, _: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(User).join(Follower, Follower.follower_id == User.id).where(Follower.following_id == user_id)
    return list((await db.scalars(stmt)).all())


@router.get("/{user_id}/following", response_model=list[UserPublic])
async def following(user_id: uuid.UUID, _: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(User).join(Follower, Follower.following_id == User.id).where(Follower.follower_id == user_id)
    return list((await db.scalars(stmt)).all())
