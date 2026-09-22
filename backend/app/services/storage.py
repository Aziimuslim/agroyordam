import os
import secrets
from pathlib import Path

from fastapi import HTTPException, UploadFile, status

from app.core.config import settings

ALLOWED = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}
MAGIC = {
    "jpg": [b"\xff\xd8\xff"],
    "png": [b"\x89PNG\r\n\x1a\n"],
    "webp": [b"RIFF"],
}


def _sniff(data: bytes) -> str | None:
    if data.startswith(b"\xff\xd8\xff"):
        return "jpg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"
    return None


async def read_image(upload: UploadFile) -> tuple[bytes, str]:
    """7-bo'lim: jpg/png/webp, ≤10MB, MIME + magic-byte tekshiruvi."""
    if upload.content_type not in ALLOWED:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "Faqat JPG, PNG yoki WEBP rasm yuklash mumkin")
    limit = settings.MAX_UPLOAD_MB * 1024 * 1024
    data = await upload.read(limit + 1)
    if len(data) > limit:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, f"Fayl hajmi {settings.MAX_UPLOAD_MB}MB dan oshmasligi kerak")
    ext = _sniff(data)
    if ext is None:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "Fayl haqiqiy rasm emas")
    return data, ext


class LocalStorage:
    def __init__(self, root: str, base_url: str) -> None:
        self.root = Path(root)
        self.base_url = base_url.rstrip("/")

    def save(self, data: bytes, ext: str, folder: str) -> str:
        name = f"{secrets.token_hex(16)}.{ext}"
        target = self.root / folder
        target.mkdir(parents=True, exist_ok=True)
        (target / name).write_bytes(data)
        return f"{self.base_url}/{folder}/{name}"


class S3Storage:
    def __init__(self) -> None:
        import boto3  # faqat s3 rejimida kerak

        self.client = boto3.client(
            "s3",
            endpoint_url=settings.S3_ENDPOINT_URL,
            aws_access_key_id=settings.S3_ACCESS_KEY,
            aws_secret_access_key=settings.S3_SECRET_KEY,
        )
        self.bucket = settings.S3_BUCKET
        self.public = (settings.S3_PUBLIC_URL or f"{settings.S3_ENDPOINT_URL}/{self.bucket}").rstrip("/")
        try:
            self.client.head_bucket(Bucket=self.bucket)
        except Exception:
            self.client.create_bucket(Bucket=self.bucket)

    def save(self, data: bytes, ext: str, folder: str) -> str:
        key = f"{folder}/{secrets.token_hex(16)}.{ext}"
        content_type = {"jpg": "image/jpeg", "png": "image/png", "webp": "image/webp"}[ext]
        self.client.put_object(Bucket=self.bucket, Key=key, Body=data, ContentType=content_type)
        return f"{self.public}/{key}"


_storage = None


def get_storage():
    global _storage
    if _storage is None:
        if settings.STORAGE_BACKEND == "s3":
            _storage = S3Storage()
        else:
            os.makedirs(settings.MEDIA_ROOT, exist_ok=True)
            _storage = LocalStorage(settings.MEDIA_ROOT, settings.MEDIA_URL)
    return _storage
