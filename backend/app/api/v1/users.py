import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import Follower, Post, User
from app.schemas.user import UserMe, UserProfile, UserPublic, UserUpdate
from app.services.notification_service import notify
from app.services.storage import get_storage, read_image

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserMe)
async def me(user: User = Depends(get_current_user)):
    return user


@router.put("/me", response_model=UserMe)
async def update_me(body: UserUpdate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    data = body.model_dump(exclude_unset=True)
    if "email" in data and data["email"]:
        data["email"] = data["email"].lower()
    for k, v in data.items():
        setattr(user, k, v)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Email yoki telefon band")
    await db.refresh(user)
    return user


@router.post("/me/avatar", response_model=UserMe)
async def upload_avatar(file: UploadFile = File(...), user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    data, ext = await read_image(file)
    user.avatar_url = get_storage().save(data, ext, "avatars")
    await db.commit()
    await db.refresh(user)
    return user


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
        followers_count=await cnt(Follower.following_id == u.id),
        following_count=await cnt(Follower.follower_id == u.id),
        posts_count=await cnt(Post.user_id == u.id),
        is_following=bool(await db.scalar(select(Follower.id).where(Follower.follower_id == me_.id, Follower.following_id == u.id))),
    )


@router.post("/{user_id}/follow", status_code=204)
async def follow(user_id: uuid.UUID, me_: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if user_id == me_.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "O'zingizga obuna bo'lolmaysiz")
    await _get_user(db, user_id)
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
