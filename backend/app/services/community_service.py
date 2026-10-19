from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import utcnow
from app.models import Comment, Like, Post, User
from app.schemas.community import CommentOut, PostOut
from app.schemas.user import UserPublic


def post_images(post: Post) -> list[str]:
    return list(post.image_urls or ([post.image_url] if post.image_url else []))


async def post_out(db: AsyncSession, post: Post, viewer: User) -> PostOut:
    author = await db.get(User, post.user_id)
    likes = await db.scalar(select(func.count()).select_from(Like).where(Like.post_id == post.id)) or 0
    comments = await db.scalar(select(func.count()).select_from(Comment).where(
        Comment.post_id == post.id, Comment.deleted_at.is_(None))) or 0
    liked = bool(await db.scalar(select(Like.id).where(Like.post_id == post.id, Like.user_id == viewer.id)))
    images = post_images(post)
    return PostOut(
        id=post.id, author=UserPublic.model_validate(author), diagnosis_id=post.diagnosis_id, title=post.title,
        content=post.content, image_url=images[0] if images else None, image_urls=images, category=post.category,
        likes_count=likes, comments_count=comments, liked_by_me=liked, created_at=post.created_at,
    )


async def comment_out(db: AsyncSession, c: Comment) -> CommentOut:
    deleted = c.deleted_at is not None
    author = None if deleted else await db.get(User, c.user_id)
    reply_name = None
    if c.reply_to_id is not None:
        target = await db.get(Comment, c.reply_to_id)
        if target is not None and target.deleted_at is None:
            u = await db.get(User, target.user_id)
            reply_name = u.full_name if u else None
    edited = bool(not deleted and c.created_at and c.updated_at and (c.updated_at - c.created_at).total_seconds() > 2)
    return CommentOut(
        id=c.id, post_id=c.post_id, author=UserPublic.model_validate(author) if author else None,
        content="" if deleted else c.content, parent_id=c.parent_id, reply_to_id=c.reply_to_id, reply_to_name=reply_name,
        deleted=deleted, edited=edited, created_at=c.created_at,
    )


async def remove_comment(db: AsyncSession, c: Comment) -> None:
    """TZ S13: javoblari bor izoh "Izoh o'chirilgan" bo'lib qoladi (javoblar saqlanadi), aks holda butunlay o'chadi.
    Javobi qolmagan o'chirilgan ota izoh ham tozalanadi."""
    has_replies = await db.scalar(select(Comment.id).where(Comment.parent_id == c.id, Comment.deleted_at.is_(None)).limit(1))
    parent_id = c.parent_id
    if has_replies:
        c.deleted_at = utcnow()
        c.content = ""
    else:
        await db.delete(c)
    await db.flush()
    if parent_id is not None:
        parent = await db.get(Comment, parent_id)
        if parent is not None and parent.deleted_at is not None:
            left = await db.scalar(select(Comment.id).where(Comment.parent_id == parent.id, Comment.deleted_at.is_(None)).limit(1))
            if not left:
                await db.delete(parent)
