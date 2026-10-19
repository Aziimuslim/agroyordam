import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import Comment, Follower, Like, Post, User
from app.schemas.community import CommentIn, CommentOut, CommentUpdate, PostIn, PostOut, PostUpdate
from app.services import block_service
from app.services.block_service import hidden_ids
from app.services.community_service import comment_out, post_out, remove_comment
from app.services.notification_service import notify

router = APIRouter(tags=["Community"])
MODERATORS = ("admin", "moderator")


async def get_post(db: AsyncSession, post_id: uuid.UUID) -> Post:
    p = await db.get(Post, post_id)
    if p is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Post topilmadi")
    return p


@router.get("/posts", response_model=list[PostOut])
async def list_posts(
    category: str | None = None, user_id: uuid.UUID | None = None, feed: str = Query(default="all", pattern="^(all|following)$"),
    q: str | None = None, unanswered: bool = False, limit: int = 30, offset: int = 0,
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db),
):
    """unanswered=true — agronom hali izoh yozmagan postlar (agronomlar uchun "Javobsiz" filtri)."""
    stmt = select(Post).order_by(Post.created_at.desc()).limit(min(limit, 100)).offset(offset)
    if category:
        stmt = stmt.where(Post.category == category)
    if user_id:
        stmt = stmt.where(Post.user_id == user_id)
    if q:
        stmt = stmt.where(or_(Post.title.ilike(f"%{q}%"), Post.content.ilike(f"%{q}%")))
    if unanswered:
        expert_comment = select(Comment.id).join(User, User.id == Comment.user_id).where(
            Comment.post_id == Post.id, User.role == "agronomist")
        stmt = stmt.where(~expert_comment.exists())
    if feed == "following":
        stmt = stmt.where(Post.user_id.in_(select(Follower.following_id).where(Follower.follower_id == user.id)))
    hidden = await hidden_ids(db, user.id)
    if hidden:  # A08: bloklangan foydalanuvchilar postlari ko'rinmaydi
        stmt = stmt.where(Post.user_id.not_in(hidden))
    return [await post_out(db, p, user) for p in (await db.scalars(stmt)).all()]


@router.post("/posts", response_model=PostOut, status_code=201)
async def create_post(body: PostIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    data = body.model_dump()
    images = data.pop("image_urls") or ([data["image_url"]] if data.get("image_url") else [])
    p = Post(user_id=user.id, **{**data, "image_url": images[0] if images else None, "image_urls": images or None})
    db.add(p)
    await db.commit()
    await db.refresh(p)
    return await post_out(db, p, user)


@router.get("/posts/{post_id}", response_model=PostOut)
async def read_post(post_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await post_out(db, await get_post(db, post_id), user)


@router.put("/posts/{post_id}", response_model=PostOut)
async def update_post(post_id: uuid.UUID, body: PostUpdate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p = await get_post(db, post_id)
    if p.user_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Faqat muallif tahrirlay oladi")
    data = body.model_dump(exclude_unset=True)
    if "image_urls" in data:  # yangi klient: to'liq ro'yxat
        images = data.pop("image_urls") or []
        data["image_url"], data["image_urls"] = (images[0] if images else None), (images or None)
    elif "image_url" in data:  # eski klient: bitta rasm
        data["image_urls"] = [data["image_url"]] if data["image_url"] else None
    for k, v in data.items():
        setattr(p, k, v)
    await db.commit()
    await db.refresh(p)
    return await post_out(db, p, user)


@router.delete("/posts/{post_id}", status_code=204)
async def delete_post(post_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p = await get_post(db, post_id)
    if p.user_id != user.id and user.role not in MODERATORS:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Ruxsat yo'q")
    await db.delete(p)
    await db.commit()


@router.post("/posts/{post_id}/like", response_model=PostOut)
async def like_post(post_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p = await get_post(db, post_id)
    if not await db.scalar(select(Like.id).where(Like.post_id == p.id, Like.user_id == user.id)):
        db.add(Like(post_id=p.id, user_id=user.id))
        if p.user_id != user.id:
            await notify(db, p.user_id, "like", "Yangi layk", f"{user.full_name} postingizni yoqtirdi", p.id)
        await db.commit()
    return await post_out(db, p, user)


@router.delete("/posts/{post_id}/like", response_model=PostOut)
async def unlike_post(post_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p = await get_post(db, post_id)
    like = await db.scalar(select(Like).where(Like.post_id == p.id, Like.user_id == user.id))
    if like:
        await db.delete(like)
        await db.commit()
    return await post_out(db, p, user)


@router.get("/posts/{post_id}/comments", response_model=list[CommentOut])
async def list_comments(post_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await get_post(db, post_id)
    stmt = select(Comment).where(Comment.post_id == post_id).order_by(Comment.created_at)
    hidden = await hidden_ids(db, user.id)
    if hidden:
        stmt = stmt.where(Comment.user_id.not_in(hidden))
    rows = (await db.scalars(stmt)).all()
    roots = {c.id for c in rows if c.parent_id is None}
    # javobi ota izohi ko'rinmasa (bloklangan muallif) — u ham ko'rsatilmaydi
    return [await comment_out(db, c) for c in rows if c.parent_id is None or c.parent_id in roots]


@router.post("/posts/{post_id}/comments", response_model=CommentOut, status_code=201)
async def add_comment(post_id: uuid.UUID, body: CommentIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p = await get_post(db, post_id)
    target = None
    if body.reply_to_id is not None:
        target = await db.get(Comment, body.reply_to_id)
        if target is None or target.post_id != p.id or target.deleted_at is not None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Izoh topilmadi")
        if await block_service.between(db, user.id, target.user_id):
            raise HTTPException(status.HTTP_403_FORBIDDEN, block_service.BLOCKED_MSG)
    c = Comment(post_id=p.id, user_id=user.id, content=body.content.strip(),
                parent_id=(target.parent_id or target.id) if target else None, reply_to_id=target.id if target else None)
    db.add(c)
    notified = set()
    if target is not None and target.user_id != user.id:
        await notify(db, target.user_id, "comment", "Izohingizga javob", f"{user.full_name}: {body.content[:80]}", p.id)
        notified.add(target.user_id)
    if p.user_id != user.id and p.user_id not in notified:
        await notify(db, p.user_id, "comment", "Yangi izoh", f"{user.full_name}: {body.content[:80]}", p.id)
    await db.commit()
    await db.refresh(c)
    return await comment_out(db, c)


@router.put("/comments/{comment_id}", response_model=CommentOut)
async def edit_comment(comment_id: uuid.UUID, body: CommentUpdate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """TZ S13: o'z izohini tahrirlash."""
    c = await db.get(Comment, comment_id)
    if c is None or c.deleted_at is not None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Izoh topilmadi")
    if c.user_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Faqat muallif tahrirlay oladi")
    c.content = body.content
    await db.commit()
    await db.refresh(c)
    return await comment_out(db, c)


@router.delete("/comments/{comment_id}", status_code=204)
async def delete_comment(comment_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    c = await db.get(Comment, comment_id)
    if c is None or c.deleted_at is not None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Izoh topilmadi")
    if c.user_id != user.id and user.role not in MODERATORS:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Ruxsat yo'q")
    await remove_comment(db, c)
    await db.commit()
