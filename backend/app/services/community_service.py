from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Comment, Like, Post, User
from app.schemas.community import CommentOut, PostOut
from app.schemas.user import UserPublic


async def post_out(db: AsyncSession, post: Post, viewer: User) -> PostOut:
    author = await db.get(User, post.user_id)
    likes = await db.scalar(select(func.count()).select_from(Like).where(Like.post_id == post.id)) or 0
    comments = await db.scalar(select(func.count()).select_from(Comment).where(Comment.post_id == post.id)) or 0
    liked = bool(await db.scalar(select(Like.id).where(Like.post_id == post.id, Like.user_id == viewer.id)))
    return PostOut(
        id=post.id, author=UserPublic.model_validate(author), diagnosis_id=post.diagnosis_id, title=post.title,
        content=post.content, image_url=post.image_url, category=post.category, likes_count=likes,
        comments_count=comments, liked_by_me=liked, created_at=post.created_at,
    )


async def comment_out(db: AsyncSession, c: Comment) -> CommentOut:
    author = await db.get(User, c.user_id)
    return CommentOut(id=c.id, post_id=c.post_id, author=UserPublic.model_validate(author), content=c.content, created_at=c.created_at)
