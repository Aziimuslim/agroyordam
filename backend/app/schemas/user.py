import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.schemas.common import ORMModel


class UserPublic(ORMModel):
    id: uuid.UUID
    full_name: str
    username: str
    avatar_url: str | None = None
    region: str | None = None
    is_premium: bool = False
    created_at: datetime | None = None


class UserMe(UserPublic):
    email: str | None = None
    phone: str | None = None
    language: str = "uz"
    role: str = "user"
    premium_until: datetime | None = None
    is_active: bool = True


class UserProfile(UserPublic):
    followers_count: int = 0
    following_count: int = 0
    posts_count: int = 0
    is_following: bool = False


class UserUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=150)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, pattern=r"^\+?[0-9]{9,15}$")
    region: str | None = None
    language: str | None = Field(default=None, pattern=r"^(uz|ru|en)$")
