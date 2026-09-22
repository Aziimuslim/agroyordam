import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.common import ORMModel


class AIChatIn(BaseModel):
    message: str = Field(min_length=1, max_length=2000)


class AIChatMessageOut(ORMModel):
    id: uuid.UUID
    role: str
    content: str
    created_at: datetime | None = None


class AIChatReply(BaseModel):
    reply: AIChatMessageOut
    remaining_today: int | None = None
