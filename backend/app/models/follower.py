import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, uuid_pk


class Follower(Base):
    __tablename__ = "followers"
    __table_args__ = (UniqueConstraint("follower_id", "following_id"),)

    id: Mapped[uuid.UUID] = uuid_pk()
    follower_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    following_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    created_at: Mapped[datetime] = created_at_col()
