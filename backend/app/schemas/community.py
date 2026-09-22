import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.common import ORMModel
from app.schemas.user import UserPublic

CATEGORY = r"^(disease|question|experience|advice)$"


class PostIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    content: str | None = None
    image_url: str | None = None
    category: str | None = Field(default=None, pattern=CATEGORY)
    diagnosis_id: uuid.UUID | None = None


class PostUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    content: str | None = None
    image_url: str | None = None
    category: str | None = Field(default=None, pattern=CATEGORY)


class PostOut(ORMModel):
    id: uuid.UUID
    author: UserPublic
    diagnosis_id: uuid.UUID | None = None
    title: str
    content: str | None = None
    image_url: str | None = None
    category: str | None = None
    likes_count: int = 0
    comments_count: int = 0
    liked_by_me: bool = False
    created_at: datetime | None = None


class CommentIn(BaseModel):
    content: str = Field(min_length=1, max_length=2000)


class CommentOut(ORMModel):
    id: uuid.UUID
    post_id: uuid.UUID
    author: UserPublic
    content: str
    created_at: datetime | None = None


class ReportIn(BaseModel):
    post_id: uuid.UUID | None = None
    comment_id: uuid.UUID | None = None
    reason: str = Field(max_length=100)
    description: str | None = None


class ReportOut(ORMModel):
    id: uuid.UUID
    reporter_id: uuid.UUID
    post_id: uuid.UUID | None = None
    comment_id: uuid.UUID | None = None
    reason: str | None = None
    description: str | None = None
    status: str
    created_at: datetime | None = None
    reviewed_at: datetime | None = None
