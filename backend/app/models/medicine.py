import uuid
from datetime import datetime

from sqlalchemy import Boolean, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, updated_at_col, uuid_pk


class Medicine(Base):
    __tablename__ = "medicines"

    id: Mapped[uuid.UUID] = uuid_pk()
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    active_ingredient: Mapped[str | None] = mapped_column(String(150))
    description: Mapped[str | None] = mapped_column(Text)
    usage: Mapped[str | None] = mapped_column(Text)
    precautions: Mapped[str | None] = mapped_column(Text)
    manufacturer: Mapped[str | None] = mapped_column(String(150))
    image_url: Mapped[str | None] = mapped_column(String(255))
    category: Mapped[str | None] = mapped_column(String(20))  # fungicide | insecticide | acaricide | biological | other
    kind: Mapped[str | None] = mapped_column(String(10))  # active (faol modda) | product (tayyor mahsulot) | mixture
    # Qo'llash me'yori aniq mahsulot yorlig'i bo'yicha tasdiqlangan (TZ S22). False — me'yor dehqonga ko'rsatilmaydi.
    label_verified: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    source: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()
