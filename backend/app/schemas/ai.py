import uuid
from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.schemas.common import ORMModel


def _strip(v):
    return v.strip() if isinstance(v, str) else v


class AIChatIn(BaseModel):
    message: str = Field(min_length=1, max_length=4000)  # TZ S10

    @field_validator("message", mode="before")
    @classmethod
    def strip_message(cls, v):
        return _strip(v)


class AISendIn(AIChatIn):
    conversation_id: uuid.UUID | None = None  # yo'q bo'lsa — yangi suhbat (nomi birinchi savoldan)


class AIChatMessageOut(ORMModel):
    id: uuid.UUID
    conversation_id: uuid.UUID | None = None
    reply_to_id: uuid.UUID | None = None
    role: str
    content: str
    status: str = "done"  # done | partial (to'xtatilgan yoki uzilgan)
    created_at: datetime | None = None


class AIChatReply(BaseModel):
    reply: AIChatMessageOut
    remaining_today: int | None = None


class AIConversationOut(BaseModel):
    id: uuid.UUID
    title: str
    last_message: str | None = None
    message_count: int = 0
    created_at: datetime | None = None
    updated_at: datetime | None = None


class AIConversationUpdate(BaseModel):
    title: str = Field(min_length=1, max_length=100)

    @field_validator("title", mode="before")
    @classmethod
    def strip_title(cls, v):
        return _strip(v)
