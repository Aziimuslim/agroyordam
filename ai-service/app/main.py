"""AgroYordam AI Service — ichki mikroservis (tashqariga yopiq)."""
import io

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError

from app.inference.classifier import OnnxClassifier, load_classifier
from app.inference.validation import validate
from app.models.labels import ALL_LABELS
from app.schemas import PredictResponse

MAX_BYTES = 10 * 1024 * 1024

app = FastAPI(title="AgroYordam AI Service", version="0.1.3")
classifier = load_classifier()


@app.get("/health")
async def health():
    return {"status": "ok", "model": type(classifier).__name__}


@app.get("/labels")
async def labels():
    """Model taniydigan sinflar (backend dataset belgilashda ishlatadi)."""
    return {"labels": classifier.labels if isinstance(classifier, OnnxClassifier) else ALL_LABELS}


@app.post("/predict", response_model=PredictResponse)
async def predict(image: UploadFile = File(...), plant_hint: str | None = Form(default=None)) -> PredictResponse:
    """plant_hint — ixtiyoriy: foydalanuvchi tanlagan ekin turi (stub undan foydalanadi, real model e'tiborsiz qoldiradi)."""
    raw = await image.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise HTTPException(413, "Fayl juda katta")
    try:
        img = Image.open(io.BytesIO(raw))
        img.load()
    except (UnidentifiedImageError, OSError):
        return PredictResponse(plant=None, ai_label=None, confidence=0, is_valid_image=False, reason="Fayl rasm emas")

    img = ImageOps.exif_transpose(img)  # telefon suratlari aylantirilgan holda keladi
    check = validate(img)
    if not check.ok:
        return PredictResponse(plant=None, ai_label=None, confidence=0, is_valid_image=False, reason=check.reason)

    plant, label, conf = classifier.predict(img, raw, plant_hint)
    return PredictResponse(plant=plant, ai_label=label, confidence=conf, is_valid_image=True)
