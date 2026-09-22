"""Kasallik klassifikatori interfeysi.

MVP: `StubClassifier` — deterministik (bir xil rasm → bir xil javob), barg
piksellaridagi dog'lar ulushiga qarab sog'lom/kasal qaror qiladi.
Prod: `OnnxClassifier` — EfficientNet-B0/MobileNetV3 ONNX modeli
(training/train.py orqali eksport qilinadi). MODEL_PATH berilsa avtomatik ishlaydi.
"""
import hashlib
import os
from pathlib import Path
from typing import Protocol

import numpy as np
from PIL import Image

from app.inference.validation import vegetation_masks
from app.models.labels import ALL_LABELS, PLANT_LABELS, plant_of


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
        healthy = [lbl for lbl in labels if lbl.endswith("healthy")][0]
        diseases = [lbl for lbl in labels if not lbl.endswith("healthy")]

        small = img.convert("RGB")
        small.thumbnail((256, 256))
        leaf, lesion = vegetation_masks(np.asarray(small))
        lesion_ratio = float(lesion.sum()) / max(1.0, float(leaf.sum()))

        if lesion_ratio < self.LESION_THRESHOLD:
            conf = 80 + digest[2] % 18
            return plant, healthy, float(conf)
        label = diseases[digest[1] % len(diseases)]
        conf = min(97.0, 62 + lesion_ratio * 120 + digest[3] % 10)
        return plant, label, round(conf, 2)


class OnnxClassifier:  # pragma: no cover - model fayli bo'lganda ishlaydi
    def __init__(self, model_path: str, labels_path: str | None = None) -> None:
        import onnxruntime as ort

        self.session = ort.InferenceSession(model_path, providers=["CPUExecutionProvider"])
        self.input_name = self.session.get_inputs()[0].name
        lp = Path(labels_path) if labels_path else Path(model_path).with_suffix(".labels.txt")
        self.labels = lp.read_text().split() if lp.exists() else ALL_LABELS
        self.mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
        self.std = np.array([0.229, 0.224, 0.225], dtype=np.float32)

    def predict(self, img: Image.Image, raw: bytes, plant_hint: str | None = None) -> tuple[str | None, str, float]:
        x = np.asarray(img.convert("RGB").resize((224, 224)), dtype=np.float32) / 255.0
        x = ((x - self.mean) / self.std).transpose(2, 0, 1)[None]
        logits = self.session.run(None, {self.input_name: x})[0][0]
        e = np.exp(logits - logits.max())
        probs = e / e.sum()  # softmax
        idx = int(probs.argmax())
        label = self.labels[idx]
        return plant_of(label), label, round(float(probs[idx]) * 100, 2)


def load_classifier() -> Classifier:
    model_path = os.getenv("MODEL_PATH")
    if model_path and Path(model_path).exists():
        return OnnxClassifier(model_path, os.getenv("LABELS_PATH"))
    return StubClassifier()
