import uuid
from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.schemas.common import ORMModel
from app.schemas.user import UserPublic


class ConversationIn(BaseModel):
    user_id: uuid.UUID


MAX_MESSAGE_IMAGES = 5


class MessageIn(BaseModel):
    content: str | None = Field(default=None, max_length=4000)
    image_url: str | None = None
    image_urls: list[str] | None = None  # TZ S16: 5 tagacha

    @field_validator("image_urls")
    @classmethod
    def check_images(cls, v):
        if v is None:
            return v
        out = [u.strip() for u in v if (u or "").strip()]
        if len(out) > MAX_MESSAGE_IMAGES:
            raise ValueError(f"Ko'pi bilan {MAX_MESSAGE_IMAGES} ta rasm")
        if any(len(u) > 255 for u in out):
            raise ValueError("Rasm manzili juda uzun")
        return list(dict.fromkeys(out))

    @field_validator("content", mode="before")
    @classmethod
    def strip_content(cls, v):
        v = v.strip() if isinstance(v, str) else v
        return v or None


class MessageOut(ORMModel):
    id: uuid.UUID
    conversation_id: uuid.UUID
    sender_id: uuid.UUID
    content: str | None = None
    image_url: str | None = None
    image_urls: list[str] = []
    delivered: bool = False  # faqat server event (qabul qiluvchi qurilmasi oldi)
    is_read: bool
    created_at: datetime | None = None

    @classmethod
    def of(cls, m) -> "MessageOut":
        urls = list(m.image_urls or ([m.image_url] if m.image_url else []))
        return cls(id=m.id, conversation_id=m.conversation_id, sender_id=m.sender_id, content=m.content,
                   image_url=urls[0] if urls else None, image_urls=urls,
                   delivered=bool(m.delivered_at) or bool(m.is_read), is_read=m.is_read, created_at=m.created_at)


class ConversationOut(BaseModel):
    id: uuid.UUID
    participants: list[UserPublic]
    last_message: MessageOut | None = None
    unread_count: int = 0
    updated_at: datetime | None = None
    blocked: bool = False  # A08: bloklash bor — yozib bo'lmaydi
    muted: bool = False  # TZ S15: ovozsiz — bildirishnoma kelmaydi
