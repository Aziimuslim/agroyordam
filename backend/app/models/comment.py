import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, updated_at_col, uuid_pk


class Comment(Base):
    __tablename__ = "comments"

    id: Mapped[uuid.UUID] = uuid_pk()
    post_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("posts.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    # TZ S13: javoblar bir daraja — parent_id doim ildiz izoh; reply_to_id — aynan javob berilgan izoh
    parent_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("comments.id", ondelete="SET NULL"), index=True)
    reply_to_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("comments.id", ondelete="SET NULL"))
    content: Mapped[str] = mapped_column(Text, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime)  # javoblari bor izoh o'chirilsa — "Izoh o'chirilgan"
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()
