import uuid
from datetime import datetime

from sqlalchemy import DateTime, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.security import utcnow


def uuid_pk() -> Mapped[uuid.UUID]:
    return mapped_column(Uuid, primary_key=True, default=uuid.uuid4)


def created_at_col() -> Mapped[datetime]:
    return mapped_column(DateTime, default=utcnow, server_default=func.now(), nullable=True)


def updated_at_col() -> Mapped[datetime]:
    return mapped_column(DateTime, default=utcnow, onupdate=utcnow, server_default=func.now(), nullable=True)
