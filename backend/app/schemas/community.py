import uuid
from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.schemas.common import ORMModel
from app.schemas.user import UserPublic

CATEGORY = r"^(disease|question|experience|advice)$"


def _strip(v):
    return v.strip() if isinstance(v, str) else v


MAX_POST_IMAGES = 5


def _images(v):
    """TZ S12: 0–5 rasm; bo'sh/takror URL olib tashlanadi."""
    if v is None:
        return v
    out: list[str] = []
    for u in v:
        u = (u or "").strip()
        if u and u not in out:
            if len(u) > 255:
                raise ValueError("Rasm manzili juda uzun")
            out.append(u)
    if len(out) > MAX_POST_IMAGES:
        raise ValueError(f"Ko'pi bilan {MAX_POST_IMAGES} ta rasm")
    return out


class PostIn(BaseModel):
    # TZ S12: sarlavha 3–100, matn ≤ 3000 (min 10 — ilovada; eski klientlar matnsiz post yuborishi mumkin)
    title: str = Field(min_length=3, max_length=100)
    content: str | None = Field(default=None, max_length=3000)
    image_url: str | None = None
    image_urls: list[str] | None = None
    category: str | None = Field(default=None, pattern=CATEGORY)
    diagnosis_id: uuid.UUID | None = None

    @field_validator("title", "content", mode="before")
    @classmethod
    def strip_text(cls, v):
        return _strip(v)

    @field_validator("image_urls")
    @classmethod
    def check_images(cls, v):
        return _images(v)


class PostUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=3, max_length=100)
    content: str | None = Field(default=None, max_length=3000)
    image_url: str | None = None
    image_urls: list[str] | None = None
    category: str | None = Field(default=None, pattern=CATEGORY)

    @field_validator("image_urls")
    @classmethod
    def check_images(cls, v):
        return _images(v)


class PostOut(ORMModel):
    id: uuid.UUID
    author: UserPublic
    diagnosis_id: uuid.UUID | None = None
    title: str
    content: str | None = None
    image_url: str | None = None
    image_urls: list[str] = []
    category: str | None = None
    likes_count: int = 0
    comments_count: int = 0
    liked_by_me: bool = False
    created_at: datetime | None = None


class CommentIn(BaseModel):
    content: str = Field(min_length=1, max_length=1000)  # TZ S13; bo'sh joylardan iborat izoh qabul qilinmaydi
    reply_to_id: uuid.UUID | None = None  # TZ S13: javob berilayotgan izoh

    @field_validator("content", mode="before")
    @classmethod
    def strip_content(cls, v):
        return _strip(v)


class CommentUpdate(BaseModel):
    content: str = Field(min_length=1, max_length=1000)

    @field_validator("content", mode="before")
    @classmethod
    def strip_content(cls, v):
        return _strip(v)


class CommentOut(ORMModel):
    id: uuid.UUID
    post_id: uuid.UUID
    author: UserPublic | None = None  # o'chirilgan izohda yo'q
    content: str
    parent_id: uuid.UUID | None = None
    reply_to_id: uuid.UUID | None = None
    reply_to_name: str | None = None
    deleted: bool = False
    edited: bool = False
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
