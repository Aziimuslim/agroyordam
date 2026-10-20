from pydantic import BaseModel, EmailStr, Field, model_validator


class RegisterIn(BaseModel):
    full_name: str = Field(min_length=2, max_length=150)
    # TZ S34: forma username so'ramaydi — yuborilmasa server o'zi yaratadi (eski ilovalar yuboradi)
    username: str | None = Field(default=None, min_length=3, max_length=50, pattern=r"^[A-Za-z0-9_.]+$")
    email: EmailStr | None = None
    phone: str | None = Field(default=None, pattern=r"^\+?[0-9]{9,15}$")
    password: str = Field(min_length=8, max_length=128)
    region: str | None = None
    language: str = "uz"
    accept_terms: bool | None = None

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


class RegisterDraft(BaseModel):
    """S34: kod tasdiqlangunga qadar hisob yaratilmaydi — ma'lumot challenge'da (parol faqat hash) turadi."""

    full_name: str = Field(min_length=2, max_length=80)
    password: str = Field(min_length=8, max_length=128)
    region: str | None = Field(default=None, max_length=100)
    language: str = Field(default="uz", max_length=10)
    accept_terms: bool


class ChallengeIn(BaseModel):
    purpose: str = Field(pattern=r"^(register|login|recovery)$")
    channel: str = Field(pattern=r"^(sms|email)$")
    destination: str = Field(min_length=3, max_length=150)
    signup: RegisterDraft | None = None  # faqat purpose=register


class ChallengeOut(BaseModel):
    challenge_id: str
    purpose: str
    channel: str
    destination_masked: str
    expires_in: int
    resend_in: int
    attempts_left: int
    dev_code: str | None = None  # faqat sinov rejimida


class ContactIn(BaseModel):
    """TZ S24: yangi telefon yoki email — kod shu manzilga yuboriladi."""
    channel: str = Field(pattern=r"^(sms|email)$")
    destination: str = Field(min_length=3, max_length=150)


class VerifyIn(BaseModel):
    code: str = Field(pattern=r"^\s*\d{6}\s*$")


class VerifyOut(BaseModel):
    result: str  # session | recovery
    access_token: str | None = None
    refresh_token: str | None = None
    token_type: str = "bearer"
    expires_in: int | None = None
    recovery_token: str | None = None


class RecoveryResetIn(BaseModel):
    recovery_token: str
    new_password: str = Field(min_length=8, max_length=128)


class AuthOptions(BaseModel):
    channels: list[str]
    dev_codes: bool
    terms_version: str
    otp_ttl: int
    otp_resend: int
