import uuid
from datetime import datetime

from typing import Annotated

from pydantic import BaseModel, EmailStr, Field, StringConstraints

from app.schemas.common import ORMModel


class UserPublic(ORMModel):
    id: uuid.UUID
    full_name: str
    username: str
    avatar_url: str | None = None
    region: str | None = None
    is_premium: bool = False
    role: str = "user"  # user | agronomist | admin — jamoatda "Agronom" belgisi uchun
    created_at: datetime | None = None


class UserMe(UserPublic):
    email: str | None = None
    phone: str | None = None
    language: str = "uz"
    specialization: str | None = None
    accepting_questions: bool = True
    work_hours: str | None = None
    education: str | None = None
    skills: list[str] | None = None
    district: str | None = None
    address: str | None = None
    about: str | None = None
    experience_years: int | None = None
    farm_type: str | None = None
    farm_area: float | None = None
    main_crops: list[str] | None = None
    irrigation: str | None = None
    premium_until: datetime | None = None
    is_active: bool = True


class UserProfile(UserPublic):
    # TZ S14: ommaviy profil — telefon, email va aniq manzil berilmaydi
    about: str | None = None
    district: str | None = None
    followers_count: int = 0
    following_count: int = 0
    posts_count: int = 0
    is_following: bool = False


Tag = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=40)]

# Faqat agronom o'zgartira oladigan maydonlar (boshqalarniki e'tiborsiz qoldiriladi)
EXPERT_FIELDS = {"specialization", "work_hours", "education", "skills"}


class FarmBrief(BaseModel):
    """Dehqon xo'jaligi haqida qisqacha — faqat agronom ko'radi (savolga aniqroq javob uchun)."""

    region: str | None = None
    district: str | None = None
    farm_type: str | None = None
    farm_area: float | None = None
    main_crops: list[str] | None = None
    irrigation: str | None = None
    experience_years: int | None = None


class UserUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=150)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, pattern=r"^\+?[0-9]{9,15}$")
    region: str | None = Field(default=None, max_length=100)
    district: str | None = Field(default=None, max_length=100)
    address: str | None = Field(default=None, max_length=255)
    about: str | None = Field(default=None, max_length=2000)
    experience_years: int | None = Field(default=None, ge=0, le=70)
    farm_type: str | None = Field(default=None, pattern=r"^(tomorqa|dehqon|fermer|issiqxona)$")
    farm_area: float | None = Field(default=None, ge=0, le=100000)
    main_crops: list[Tag] | None = Field(default=None, max_length=20)
    irrigation: str | None = Field(default=None, pattern=r"^(ariq|tomchi|yomgir|nasos|lalmi)$")
    specialization: str | None = Field(default=None, max_length=200)
    work_hours: str | None = Field(default=None, max_length=100)
    education: str | None = Field(default=None, max_length=255)
    skills: list[Tag] | None = Field(default=None, max_length=20)
    language: str | None = Field(default=None, pattern=r"^(uz|uz-Cyrl|ru|en|kaa)$")
