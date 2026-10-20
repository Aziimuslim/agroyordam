import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Numeric, String, Text, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.security import utcnow
from app.models._base import uuid_pk


class Diagnosis(Base):
    __tablename__ = "diagnoses"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    crop_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("crops.id", ondelete="SET NULL"))
    plant_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("plants.id"))
    disease_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("diseases.id"))
    image_url: Mapped[str] = mapped_column(String(255), nullable=False)
    confidence: Mapped[Decimal | None] = mapped_column(Numeric(5, 2))
    risk_level: Mapped[str | None] = mapped_column(String(20))
    symptoms: Mapped[str | None] = mapped_column(Text)
    causes: Mapped[str | None] = mapped_column(Text)
    recommendations: Mapped[str | None] = mapped_column(Text)
    diagnosed_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, server_default=func.now())

    # AI modeli qaytargan sinf (masalan Tomato_Late_blight) — dataset va tahlil uchun
    ai_label: Mapped[str | None] = mapped_column(String(150))
    ai_top: Mapped[list | None] = mapped_column(JSON)  # AI ning eng ehtimolli 3 sinfi [{"label", "confidence"}]

    # Dataset yig'ish: foydalanuvchi fikri va mutaxassis (admin/moderator) tekshiruvi
    user_feedback: Mapped[bool | None] = mapped_column(Boolean)  # True — AI to'g'ri topdi, False — xato
    feedback_reason: Mapped[str | None] = mapped_column(Text)  # TZ S08: "Yo'q" uchun ixtiyoriy sabab
    # pending — tekshirilmagan, confirmed — AI to'g'ri, corrected — mutaxassis tuzatgan, rejected — datasetga yaroqsiz
    review_status: Mapped[str] = mapped_column(String(20), default="pending", server_default="pending", index=True)
    verified_label: Mapped[str | None] = mapped_column(String(150), index=True)
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("users.id", ondelete="SET NULL"))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime)

    # Dehqon "Agronomga yuborish" bosgan: navbatda birinchi turadi
    review_requested: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", index=True)
    review_note: Mapped[str | None] = mapped_column(Text)  # dehqon izohi
    expert_comment: Mapped[str | None] = mapped_column(Text)  # agronomning dehqonga izohi
    # Dehqon tarixdan yashirgan vaqt (TZ S07: yashirish va qaytarish). Yozuv o'chmaydi —
    # agronom tekshiruvi va AI dataseti saqlanadi.
    hidden_at: Mapped[datetime | None] = mapped_column(DateTime)
