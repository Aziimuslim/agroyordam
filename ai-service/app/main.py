"""AgroYordam AI Service — ichki mikroservis (tashqariga yopiq)."""
import io

from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, UnidentifiedImageError

from app.inference.classifier import load_classifier
from app.inference.validation import validate
from app.schemas import PredictResponse

MAX_BYTES = 10 * 1024 * 1024

app = FastAPI(title="AgroYordam AI Service", version="0.1.0")
classifier = load_classifier()


@app.get("/health")
async def health():
    return {"status": "ok", "model": type(classifier).__name__}


@app.post("/predict", response_model=PredictResponse)
async def predict(image: UploadFile = File(...)) -> PredictResponse:
    raw = await image.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise HTTPException(413, "Fayl juda katta")
    try:
        img = Image.open(io.BytesIO(raw))
        img.load()
    except (UnidentifiedImageError, OSError):
        return PredictResponse(plant=None, ai_label=None, confidence=0, is_valid_image=False, reason="Fayl rasm emas")

    check = validate(img)
    if not check.ok:
        return PredictResponse(plant=None, ai_label=None, confidence=0, is_valid_image=False, reason=check.reason)

    plant, label, conf = classifier.predict(img, raw)
    return PredictResponse(plant=plant, ai_label=label, confidence=conf, is_valid_image=True)
