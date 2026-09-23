"""Kasallik klassifikatori interfeysi.

MVP: `StubClassifier` — deterministik (bir xil rasm → bir xil javob), barg
piksellaridagi dog'lar ulushiga qarab sog'lom/kasal qaror qiladi.
Prod: `OnnxClassifier` — PlantVillage'da o'qitilgan MobileNetV3 ONNX modeli
(training/train_plantvillage.py, GitHub Actions "Train AI model"). MODEL_PATH berilsa avtomatik ishlaydi.
"""
import hashlib
import logging
import os
from pathlib import Path
from typing import Protocol

import numpy as np
from PIL import Image

from app.inference.preprocess import to_tensor
from app.inference.validation import vegetation_masks
from app.models.labels import MODEL_LABELS, PLANT_LABELS, PLANT_PREFIX, plant_of

log = logging.getLogger(__name__)


class Classifier(Protocol):
    def predict(self, img: Image.Image, raw: bytes, plant_hint: str | None = None) -> tuple[str | None, str, float]:
        """→ (plant, ai_label, confidence 0..100)"""


class StubClassifier:
    LESION_THRESHOLD = 0.08

    def predict(self, img: Image.Image, raw: bytes, plant_hint: str | None = None) -> tuple[str | None, str, float]:
        digest = hashlib.sha256(raw).digest()
        plants = list(PLANT_LABELS)
        plant = plant_hint if plant_hint in PLANT_LABELS else plants[digest[0] % len(plants)]
        labels = PLANT_LABELS[plant]
        healthy = next((lbl for lbl in labels if lbl.endswith("healthy")), None)
        diseases = [lbl for lbl in labels if not lbl.endswith("healthy")] or labels

        small = img.convert("RGB")
        small.thumbnail((256, 256))
        leaf, lesion = vegetation_masks(np.asarray(small))
        lesion_ratio = float(lesion.sum()) / max(1.0, float(leaf.sum()))

        if lesion_ratio < self.LESION_THRESHOLD and healthy:
            conf = 80 + digest[2] % 18
            return plant, healthy, float(conf)
        label = diseases[digest[1] % len(diseases)]
        conf = min(97.0, 62 + lesion_ratio * 120 + digest[3] % 10)
        return plant, label, round(conf, 2)


class OnnxClassifier:
    """MobileNetV3 (PlantVillage) ONNX modeli. plant_hint berilsa — faqat shu ekin sinflari ichida tanlaydi."""

    def __init__(self, model_path: str, labels_path: str | None = None) -> None:
        import onnxruntime as ort

        self.session = ort.InferenceSession(model_path, providers=["CPUExecutionProvider"])
        self.input_name = self.session.get_inputs()[0].name
        lp = Path(labels_path) if labels_path else Path(model_path).with_suffix(".labels.txt")
        self.labels = lp.read_text().split() if lp.exists() else MODEL_LABELS

    def probabilities(self, img: Image.Image) -> np.ndarray:
        logits = self.session.run(None, {self.input_name: to_tensor(img)})[0][0]
        e = np.exp(logits - logits.max())
        return e / e.sum()  # softmax

    def predict(self, img: Image.Image, raw: bytes, plant_hint: str | None = None) -> tuple[str | None, str, float]:
        probs = self.probabilities(img)
        prefix = PLANT_PREFIX.get(plant_hint or "")
        mask = np.array([lbl.startswith(prefix + "_") for lbl in self.labels]) if prefix else None
        if mask is not None and mask.any():
            probs = np.where(mask, probs, 0)
            probs = probs / probs.sum()
        idx = int(probs.argmax())
        label = self.labels[idx]
        return plant_of(label), label, round(float(probs[idx]) * 100, 2)


def load_classifier() -> Classifier:
    model_path = os.getenv("MODEL_PATH")
    if model_path and Path(model_path).exists():
        log.info("ONNX model yuklandi: %s", model_path)
        return OnnxClassifier(model_path, os.getenv("LABELS_PATH"))
    log.warning("MODEL_PATH topilmadi — StubClassifier ishlatilmoqda (faqat sinov uchun)")
    return StubClassifier()
