import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import Comment, Follower, Like, Post, User
from app.schemas.community import CommentIn, CommentOut, PostIn, PostOut, PostUpdate
from app.services.community_service import comment_out, post_out
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
    q: str | None = None, limit: int = 30, offset: int = 0,
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db),
):
    stmt = select(Post).order_by(Post.created_at.desc()).limit(min(limit, 100)).offset(offset)
    if category:
        stmt = stmt.where(Post.category == category)
    if user_id:
        stmt = stmt.where(Post.user_id == user_id)
    if q:
        stmt = stmt.where(or_(Post.title.ilike(f"%{q}%"), Post.content.ilike(f"%{q}%")))
    if feed == "following":
        stmt = stmt.where(Post.user_id.in_(select(Follower.following_id).where(Follower.follower_id == user.id)))
    return [await post_out(db, p, user) for p in (await db.scalars(stmt)).all()]


@router.post("/posts", response_model=PostOut, status_code=201)
async def create_post(body: PostIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p = Post(user_id=user.id, **body.model_dump())
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
    for k, v in body.model_dump(exclude_unset=True).items():
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
async def list_comments(post_id: uuid.UUID, _: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await get_post(db, post_id)
    stmt = select(Comment).where(Comment.post_id == post_id).order_by(Comment.created_at)
    return [await comment_out(db, c) for c in (await db.scalars(stmt)).all()]


@router.post("/posts/{post_id}/comments", response_model=CommentOut, status_code=201)
async def add_comment(post_id: uuid.UUID, body: CommentIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    p = await get_post(db, post_id)
    c = Comment(post_id=p.id, user_id=user.id, content=body.content.strip())
    db.add(c)
    if p.user_id != user.id:
        await notify(db, p.user_id, "comment", "Yangi izoh", f"{user.full_name}: {body.content[:80]}", p.id)
    await db.commit()
    await db.refresh(c)
    return await comment_out(db, c)


@router.delete("/comments/{comment_id}", status_code=204)
async def delete_comment(comment_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    c = await db.get(Comment, comment_id)
    if c is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Izoh topilmadi")
    if c.user_id != user.id and user.role not in MODERATORS:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Ruxsat yo'q")
    await db.delete(c)
    await db.commit()
