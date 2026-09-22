"""Rasm validatsiyasi: o'lcham ≥224×224, yorug'lik, xiralik (Laplacian variance), o'simlik bor-yo'qligi."""
from dataclasses import dataclass

import numpy as np
from PIL import Image

MIN_SIDE = 224
MIN_BRIGHTNESS = 35
MAX_BRIGHTNESS = 235
MIN_LAPLACIAN_VAR = 25.0
MIN_PLANT_RATIO = 0.12


@dataclass
class ValidationResult:
    ok: bool
    reason: str | None = None
    brightness: float = 0.0
    sharpness: float = 0.0
    plant_ratio: float = 0.0


def laplacian_variance(gray: np.ndarray) -> float:
    """OpenCV cv2.Laplacian(gray, CV_64F).var() ekvivalenti (3x3 yadro)."""
    g = gray.astype(np.float64)
    lap = (-4 * g[1:-1, 1:-1] + g[:-2, 1:-1] + g[2:, 1:-1] + g[1:-1, :-2] + g[1:-1, 2:])
    return float(lap.var())


def vegetation_masks(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """(barg piksellar maskasi, dog'/zararlangan piksellar maskasi) — HSV evristikasi."""
    hsv = np.asarray(Image.fromarray(rgb).convert("HSV"), dtype=np.float32)
    h, s, v = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255, hsv[..., 2] / 255
    green = (h >= 60) & (h <= 170) & (s > 0.18) & (v > 0.15)
    lesion = (h >= 10) & (h < 60) & (s > 0.25) & (v > 0.12)  # sariq/qo'ng'ir dog'lar
    dark_spots = (v < 0.22) & (s > 0.15)
    return green | lesion, lesion | dark_spots


def validate(img: Image.Image) -> ValidationResult:
    w, h = img.size
    if min(w, h) < MIN_SIDE:
        return ValidationResult(False, f"Rasm juda kichik ({w}×{h}). Kamida {MIN_SIDE}×{MIN_SIDE} bo'lishi kerak.")
    small = img.convert("RGB")
    small.thumbnail((512, 512))
    rgb = np.asarray(small)
    gray = np.asarray(small.convert("L"))
    brightness = float(gray.mean())
    if brightness < MIN_BRIGHTNESS:
        return ValidationResult(False, "Rasm juda qorong'i. Yorug' joyda qayta suratga oling.", brightness)
    if brightness > MAX_BRIGHTNESS:
        return ValidationResult(False, "Rasm juda yorug' (oqarib ketgan). Soyaroq joyda suratga oling.", brightness)
    sharp = laplacian_variance(gray)
    if sharp < MIN_LAPLACIAN_VAR:
        return ValidationResult(False, "Rasm xira. Kamerani qimirlatmay, bargga fokus qilib suratga oling.", brightness, sharp)
    leaf, _ = vegetation_masks(rgb)
    ratio = float(leaf.mean())
    if ratio < MIN_PLANT_RATIO:
        return ValidationResult(False, "Rasmda o'simlik bargi aniqlanmadi. Bargni kadrga yaqinroq oling.", brightness, sharp, ratio)
    return ValidationResult(True, None, brightness, sharp, ratio)
