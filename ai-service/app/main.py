"""AgroYordam AI Service — ichki mikroservis (tashqariga yopiq)."""
import asyncio
import io
import os

from fastapi import FastAPI, File, Form, Header, HTTPException, UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel

from app.inference import registry
from app.inference.classifier import OnnxClassifier
from app.inference.validation import validate
from app.models.labels import ALL_LABELS
from app.schemas import PredictResponse, TopPrediction

MAX_BYTES = 10 * 1024 * 1024

app = FastAPI(title="AgroYordam AI Service", version="0.1.4")
classifier, model_tag, model_path = registry.load_active()
_switch = asyncio.Lock()


@app.get("/health")
async def health():
    out = {"status": "ok"} | registry.info(classifier, model_tag, model_path)
    out.pop("metrics", None)
    return out


@app.get("/model")
async def model_info():
    """Faol model versiyasi va uning metrikalari (admin panel)."""
    return registry.info(classifier, model_tag, model_path)


class ActivateIn(BaseModel):
    tag: str


@app.post("/model/activate")
async def activate(body: ActivateIn, x_admin_token: str | None = Header(default=None)):
    """Boshqa versiyaga o'tish (yangi nomzod yoki qaytarish). Faqat ichki tarmoq; AI_ADMIN_TOKEN berilsa — tekshiriladi."""
    global classifier, model_tag, model_path
    expected = os.getenv("AI_ADMIN_TOKEN")
    if expected and x_admin_token != expected:
        raise HTTPException(403, "Ruxsat yo'q")
    if not registry.TAG_RE.match(body.tag):
        raise HTTPException(422, "Noto'g'ri versiya nomi")
    async with _switch:
        try:
            clf, path = await asyncio.to_thread(registry.activate, body.tag)
        except Exception as exc:  # yuklab bo'lmadi / fayl buzilgan — eski model ishlashda davom etadi
            raise HTTPException(502, f"{body.tag} ni ishga tushirib bo'lmadi: {exc}") from exc
        classifier, model_tag, model_path = clf, body.tag, path
    return registry.info(classifier, model_tag, model_path)


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

    plant, label, conf, top = classifier.predict_top(img, raw, plant_hint)
    return PredictResponse(plant=plant, ai_label=label, confidence=conf, is_valid_image=True,
                           top=[TopPrediction(label=lbl, confidence=c) for lbl, c in top])
