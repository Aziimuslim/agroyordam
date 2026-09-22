from pydantic import BaseModel, EmailStr, Field, model_validator


class RegisterIn(BaseModel):
    full_name: str = Field(min_length=2, max_length=150)
    username: str = Field(min_length=3, max_length=50, pattern=r"^[A-Za-z0-9_.]+$")
    email: EmailStr | None = None
    phone: str | None = Field(default=None, pattern=r"^\+?[0-9]{9,15}$")
    password: str = Field(min_length=8, max_length=128)
    region: str | None = None
    language: str = "uz"

    @model_validator(mode="after")
    def need_contact(self):
        if not self.email and not self.phone:
            raise ValueError("Email yoki telefon raqamidan kamida bittasi kerak")
        return self


class LoginIn(BaseModel):
    login: str = Field(description="username, email yoki telefon")
    password: str


class RefreshIn(BaseModel):
    refresh_token: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class ForgotPasswordIn(BaseModel):
    login: str


class ResetPasswordIn(BaseModel):
    token: str
    new_password: str = Field(min_length=8, max_length=128)
