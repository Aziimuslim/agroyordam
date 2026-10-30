"""Android ilova yangilanishi: eng so'nggi APK (GitHub Releases) haqida ma'lumot.

Ilova shu manzilni so'raydi, yangi versiya bo'lsa foydalanuvchiga taklif qiladi va APK'ni o'zi yuklab oladi.
Ma'lumot GitHub'dan olinadi va 10 daqiqa keshlanadi (GitHub cheklovlari va tezlik uchun).
Release faqat APK yig'ilib bo'lgach chiqadi — shuning uchun ilova hali yo'q faylni hech qachon so'ramaydi.
"""

import re
import time

import httpx
from fastapi import APIRouter, HTTPException, status

from app.core.config import settings

router = APIRouter(prefix="/app", tags=["Ilova yangilanishi"])

_TTL = 600
_cache: dict = {"at": 0.0, "data": None}


def _notes_for(body: str, version: str) -> str:
    """Release matnidan shu versiya bo'limini ("## 0.8.20 ...") ajratadi."""
    m = re.search(rf"^## {re.escape(version)}\b[^\n]*\n(.*?)(?=^## |\Z)", body or "", re.S | re.M)
    return (m.group(1) if m else "").strip()[:2000]


def _parse(rel: dict) -> dict | None:
    version = str(rel.get("tag_name", "")).lstrip("v")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        return None
    assets = rel.get("assets") or []
    apk = next((a for a in assets if a.get("name") == f"AgroYordam-{version}.apk"), None) or next(
        (a for a in assets if a.get("name") == "AgroYordam.apk"), None
    )
    if not apk:
        return None
    return {
        "version": version,
        "apk_url": apk.get("browser_download_url"),
        "size": apk.get("size"),
        "notes": _notes_for(rel.get("body") or "", version),
        "published_at": rel.get("published_at"),
    }


@router.get("/latest")
async def latest():
    """Eng so'nggi Android versiyasi: version, apk_url, size (bayt), notes, published_at."""
    now = time.monotonic()
    if _cache["data"] and now - _cache["at"] < _TTL:
        return _cache["data"]
    try:
        async with httpx.AsyncClient(timeout=10, follow_redirects=True) as client:
            r = await client.get(
                f"https://api.github.com/repos/{settings.GITHUB_REPO}/releases/latest",
                headers={"Accept": "application/vnd.github+json"},
            )
            r.raise_for_status()
            data = _parse(r.json())
    except (httpx.HTTPError, ValueError):
        data = None
    if data is None:
        if _cache["data"]:  # GitHub javob bermasa — oxirgi ma'lum ma'lumot
            return _cache["data"]
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Yangilanish ma'lumoti vaqtincha mavjud emas")
    _cache.update(at=now, data=data)
    return data
