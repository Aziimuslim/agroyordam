import uuid

from sqlalchemy import ForeignKey, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class DiseaseMedicine(Base):
    __tablename__ = "disease_medicines"

    disease_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("diseases.id", ondelete="CASCADE"), primary_key=True)
    medicine_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("medicines.id", ondelete="CASCADE"), primary_key=True)
    recommendation: Mapped[str | None] = mapped_column(Text)
