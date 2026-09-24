import io

import numpy as np
from fastapi.testclient import TestClient
from PIL import Image

from app.inference.classifier import StubClassifier
from app.main import app, classifier

client = TestClient(app)


def _png(arr: np.ndarray) -> bytes:
    buf = io.BytesIO()
    Image.fromarray(arr.astype(np.uint8)).save(buf, "PNG")
    return buf.getvalue()


def leaf_image(spots: bool, size: int = 300, seed: int = 0) -> bytes:
    rng = np.random.default_rng(seed)
    img = np.zeros((size, size, 3))
    img[..., 1] = 140 + rng.integers(-40, 40, (size, size))
    img[..., 0] = 50 + rng.integers(-20, 20, (size, size))
    img[..., 2] = 40 + rng.integers(-20, 20, (size, size))
    if spots:
        for _ in range(25):
            x, y = rng.integers(10, size - 30, 2)
            img[y:y + 22, x:x + 22] = (130, 80, 20)
    return _png(np.clip(img, 0, 255))


def post(data: bytes):
    return client.post("/predict", files={"image": ("x.png", data, "image/png")})


def test_health():
    assert client.get("/health").json()["status"] == "ok"


def test_labels():
    labels = client.get("/labels").json()["labels"]
    assert "Tomato_Late_blight" in labels and "Tomato_healthy" in labels


def test_contract_and_determinism():
    img = leaf_image(True)
    a, b = post(img).json(), post(img).json()
    assert set(a) >= {"plant", "ai_label", "confidence", "is_valid_image"}
    assert a == b and a["is_valid_image"] is True
    if isinstance(classifier, StubClassifier):
        # Sun'iy "dog'li" rasm semantikasini faqat stub tushunadi; haqiqiy model uchun test_onnx_model.py
        assert not a["ai_label"].endswith("healthy")


def test_healthy_leaf():
    r = post(leaf_image(False)).json()
    assert r["is_valid_image"] and r["ai_label"].endswith("healthy")


def test_too_small():
    r = post(leaf_image(False, size=100)).json()
    assert r["is_valid_image"] is False and "kichik" in r["reason"]


def test_dark_image():
    r = post(_png(np.full((300, 300, 3), 10))).json()
    assert r["is_valid_image"] is False and "qorong'i" in r["reason"]


def test_blurry_image():
    r = post(_png(np.full((300, 300, 3), (60, 140, 50)))).json()
    assert r["is_valid_image"] is False and "xira" in r["reason"]


def _blurred_leaf(radius: float, blur_background_only: bool = False) -> bytes:
    from PIL import ImageDraw, ImageFilter
    rng = np.random.default_rng(3)
    bg = np.clip(np.full((1200, 1200, 3), (120, 110, 90)) + rng.normal(0, 25, (1200, 1200, 3)), 0, 255)
    im = Image.fromarray(bg.astype(np.uint8))
    d = ImageDraw.Draw(im)
    d.ellipse((150, 250, 1050, 950), fill=(70, 130, 50))
    for i in range(12):
        d.line((600, 600, 150 + i * 80, 250 if i % 2 else 950), fill=(110, 160, 80), width=4)
    blurred = im.filter(ImageFilter.GaussianBlur(radius))
    if blur_background_only:
        mask = Image.new("L", im.size, 0)
        ImageDraw.Draw(mask).ellipse((150, 250, 1050, 950), fill=255)
        blurred = Image.composite(im, blurred, mask)
    buf = io.BytesIO()
    blurred.save(buf, "JPEG", quality=88)
    return buf.getvalue()


def test_slightly_soft_phone_photo_is_accepted():
    assert post(_blurred_leaf(2)).json()["is_valid_image"] is True


def test_sharp_leaf_with_blurred_background_is_accepted():
    assert post(_blurred_leaf(12, blur_background_only=True)).json()["is_valid_image"] is True


def test_very_blurry_photo_is_rejected():
    r = post(_blurred_leaf(10)).json()
    assert r["is_valid_image"] is False and "xira" in r["reason"]


def test_no_plant():
    rng = np.random.default_rng(1)
    gray = rng.integers(60, 200, (300, 300))
    r = post(_png(np.stack([gray] * 3, -1))).json()
    assert r["is_valid_image"] is False and "o'simlik" in r["reason"]


def test_not_an_image():
    r = client.post("/predict", files={"image": ("x.png", b"hello", "image/png")}).json()
    assert r["is_valid_image"] is False


def test_plant_hint_is_respected():
    r = client.post("/predict", files={"image": ("x.png", leaf_image(True), "image/png")}, data={"plant_hint": "Pomidor"}).json()
    assert r["plant"] == "Pomidor" and r["ai_label"].startswith("Tomato_")
