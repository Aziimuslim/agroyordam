from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_NAME: str = "AgroYordam"
    APP_VERSION: str = "0.1.0"
    ENVIRONMENT: str = "development"  # development | production | test

    # Dev'da Docker'siz ishga tushirish uchun SQLite; docker-compose PostgreSQL beradi
    DATABASE_URL: str = "sqlite+aiosqlite:///./agroyordam.db"
    REDIS_URL: str | None = None

    SECRET_KEY: str = "change-me-in-production-please-32-bytes-min"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    BCRYPT_ROUNDS: int = 12

    CORS_ORIGINS: str = "http://localhost:8080,http://localhost:3000,http://localhost:5173"

    AI_SERVICE_URL: str = "http://localhost:8001"
    AI_MIN_CONFIDENCE: float = 60.0

    # Storage: local | s3
    STORAGE_BACKEND: str = "local"
    MEDIA_ROOT: str = "./media"
    MEDIA_URL: str = "/media"
    S3_ENDPOINT_URL: str | None = None
    S3_ACCESS_KEY: str | None = None
    S3_SECRET_KEY: str | None = None
    S3_BUCKET: str = "agroyordam"
    S3_PUBLIC_URL: str | None = None
    MAX_UPLOAD_MB: int = 10

    # Feature gating
    FREE_AI_DAILY_LIMIT: int = 3
    FREE_AI_CHAT_DAILY_LIMIT: int = 10
    FREE_CROP_LIMIT: int = 3
    LOGIN_RATE_LIMIT_PER_MINUTE: int = 5

    # To'lov provayderlari (sandbox kalitlari .env orqali beriladi)
    PAYMENT_MODE: str = "sandbox"  # sandbox | live
    PAYME_MERCHANT_ID: str = ""
    PAYME_SECRET_KEY: str = "payme-sandbox-secret"
    CLICK_SERVICE_ID: str = ""
    CLICK_MERCHANT_ID: str = ""
    CLICK_SECRET_KEY: str = "click-sandbox-secret"
    UZUM_MERCHANT_ID: str = ""
    UZUM_SECRET_KEY: str = "uzum-sandbox-secret"
    PAYMENT_RETURN_URL: str = "http://localhost:8080/#/premium"

    FCM_SERVER_KEY: str | None = None
    ENABLE_SCHEDULER: bool = True
    SEED_DEMO_DATA: bool = True

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
