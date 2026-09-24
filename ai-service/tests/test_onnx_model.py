"""Haqiqiy ONNX model testi. MODEL_PATH berilmagan bo'lsa o'tkazib yuboriladi (CI'da model release'dan yuklanadi)."""
import os
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from app.models.labels import MODEL_LABELS

MODEL = os.getenv("MODEL_PATH")
pytestmark = pytest.mark.skipif(not MODEL or not Path(MODEL).exists(), reason="ONNX model yo'q")


def leaf() -> Image.Image:
    rng = np.random.default_rng(0)
    a = np.zeros((256, 256, 3))
    a[..., 1] = 140 + rng.integers(-30, 30, (256, 256))
    a[..., 0] = 60
    a[..., 2] = 40
    return Image.fromarray(a.astype(np.uint8))


def test_model_labels_match():
    from app.inference.classifier import OnnxClassifier

    clf = OnnxClassifier(MODEL)
    assert clf.labels == MODEL_LABELS
    probs = clf.probabilities(leaf())
    assert probs.shape == (len(MODEL_LABELS),) and abs(probs.sum() - 1) < 1e-4


def test_plant_hint_restricts_classes():
    from app.inference.classifier import OnnxClassifier

    clf = OnnxClassifier(MODEL)
    for plant, prefix in [("Pomidor", "Tomato_"), ("Uzum", "Grape_"), ("Makkajo'xori", "Corn_")]:
        p, label, conf = clf.predict(leaf(), b"", plant)
        assert label.startswith(prefix) and p == plant and 0 < conf <= 100


def test_tta_is_normalized_and_deterministic():
    from app.inference.classifier import OnnxClassifier

    clf = OnnxClassifier(MODEL)
    p1, p2 = clf.probabilities_tta(leaf()), clf.probabilities_tta(leaf())
    assert p1.shape == (len(MODEL_LABELS),) and abs(p1.sum() - 1) < 1e-4
    assert np.allclose(p1, p2)
