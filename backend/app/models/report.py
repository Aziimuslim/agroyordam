import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, uuid_pk


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[uuid.UUID] = uuid_pk()
    reporter_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    post_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("posts.id", ondelete="CASCADE"))
    comment_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("comments.id", ondelete="CASCADE"))
    reason: Mapped[str | None] = mapped_column(String(100))
    description: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="pending", server_default="pending")
    created_at: Mapped[datetime] = created_at_col()
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime)
