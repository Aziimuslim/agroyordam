"""AI Service bilan ichki API kontrakt: POST /predict → {plant, ai_label, confidence, is_valid_image, top}."""
from dataclasses import dataclass, field

import httpx

from app.core.config import settings


@dataclass
class Prediction:
    plant: str | None
    ai_label: str | None
    confidence: float
    is_valid_image: bool
    reason: str | None = None
    top: list[dict] = field(default_factory=list)  # [{"label", "confidence"}] — agronom tekshiruvida muqobillar


class AIServiceError(Exception):
    pass


class AIClient:
    async def predict(self, image: bytes, filename: str, content_type: str, plant_hint: str | None = None) -> Prediction:
        try:
            async with httpx.AsyncClient(base_url=settings.AI_SERVICE_URL, timeout=30) as client:
                resp = await client.post("/predict", files={"image": (filename, image, content_type)},
                                         data={"plant_hint": plant_hint} if plant_hint else None)
        except httpx.HTTPError as exc:  # pragma: no cover - tarmoq xatosi
            raise AIServiceError(str(exc)) from exc
        if resp.status_code != 200:
            raise AIServiceError(f"AI service {resp.status_code}")
        data = resp.json()
        return Prediction(
            plant=data.get("plant"),
            ai_label=data.get("ai_label"),
            confidence=float(data.get("confidence") or 0),
            is_valid_image=bool(data.get("is_valid_image")),
            reason=data.get("reason"),
            top=[{"label": t["label"], "confidence": float(t["confidence"])} for t in data.get("top") or [] if t.get("label")],
        )


    async def health(self) -> dict | None:
        """AI xizmati holati va qaysi model ishlayotgani (admin panel uchun)."""
        try:
            async with httpx.AsyncClient(base_url=settings.AI_SERVICE_URL, timeout=5) as client:
                resp = await client.get("/health")
            resp.raise_for_status()
            return resp.json()
        except (httpx.HTTPError, ValueError):
            return None

    async def labels(self) -> list[str]:
        """Model biladigan sinflar ro'yxati (dataset belgilash uchun)."""
        try:
            async with httpx.AsyncClient(base_url=settings.AI_SERVICE_URL, timeout=10) as client:
                resp = await client.get("/labels")
            resp.raise_for_status()
            return list(resp.json().get("labels", []))
        except (httpx.HTTPError, ValueError):
            return []


_client: AIClient = AIClient()


def get_ai_client() -> AIClient:
    return _client
