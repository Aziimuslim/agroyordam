from pydantic import BaseModel


class PredictResponse(BaseModel):
    """Qat'iy API kontrakt — real model shu interfeys ortiga almashtiriladi."""

    plant: str | None
    ai_label: str | None
    confidence: float
    is_valid_image: bool
    reason: str | None = None
