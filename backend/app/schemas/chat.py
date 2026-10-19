import uuid
from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.schemas.common import ORMModel
from app.schemas.user import UserPublic


class ConversationIn(BaseModel):
    user_id: uuid.UUID


class MessageIn(BaseModel):
    content: str | None = Field(default=None, max_length=4000)
    image_url: str | None = None

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
    is_read: bool
    created_at: datetime | None = None


class ConversationOut(BaseModel):
    id: uuid.UUID
    participants: list[UserPublic]
    last_message: MessageOut | None = None
    unread_count: int = 0
    updated_at: datetime | None = None
