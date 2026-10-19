import uuid
from datetime import datetime

from sqlalchemy import JSON, Boolean, DateTime, Float, SmallInteger, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._base import created_at_col, updated_at_col, uuid_pk


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = uuid_pk()
    full_name: Mapped[str] = mapped_column(String(150), nullable=False)
    username: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    email: Mapped[str | None] = mapped_column(String(150), unique=True)
    phone: Mapped[str | None] = mapped_column(String(20), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(String(255))
    region: Mapped[str | None] = mapped_column(String(100))
    district: Mapped[str | None] = mapped_column(String(100))  # tuman/shahar
    address: Mapped[str | None] = mapped_column(String(255))  # mahalla, qishloq (ixtiyoriy)
    about: Mapped[str | None] = mapped_column(Text)
    experience_years: Mapped[int | None] = mapped_column(SmallInteger)  # dehqonchilik yoki agronomlik tajribasi
    # Dehqon xo'jaligi — agronom javob berishda ko'radi
    farm_type: Mapped[str | None] = mapped_column(String(20))  # tomorqa|dehqon|fermer|issiqxona
    farm_area: Mapped[float | None] = mapped_column(Float)  # gektar
    main_crops: Mapped[list | None] = mapped_column(JSON)
    irrigation: Mapped[str | None] = mapped_column(String(20))  # ariq|tomchi|yomgir|nasos|lalmi
    language: Mapped[str] = mapped_column(String(10), default="uz", server_default="uz")
    role: Mapped[str] = mapped_column(String(20), default="user", server_default="user")
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    premium_until: Mapped[datetime | None] = mapped_column(DateTime)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    # Agronom (role="agronomist"): mutaxassisligi va savol qabul qilyaptimi (onlayn/oflayn)
    specialization: Mapped[str | None] = mapped_column(String(200))
    accepting_questions: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    work_hours: Mapped[str | None] = mapped_column(String(100))  # agronom: "Du–Ju, 9:00–18:00"
    education: Mapped[str | None] = mapped_column(String(255))  # agronom: o'qigan joyi
    skills: Mapped[list | None] = mapped_column(JSON)  # agronom: yo'nalishlari (ekinlar, mavzular)
    terms_version: Mapped[str | None] = mapped_column(String(40))  # rozilik berilgan qoidalar versiyasi (TZ S34)
    terms_accepted_at: Mapped[datetime | None] = mapped_column(DateTime)
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()
