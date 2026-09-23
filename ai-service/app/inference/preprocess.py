"""Model uchun yagona preprocessing (o'qitishdagi val transform bilan bir xil): resize(256) → center crop(224)."""
import numpy as np
from PIL import Image

MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def resize_center_crop(img: Image.Image, resize: int = 256, crop: int = 224) -> Image.Image:
    img = img.convert("RGB")
    w, h = img.size
    s = resize / min(w, h)
    img = img.resize((max(crop, round(w * s)), max(crop, round(h * s))), Image.BILINEAR)
    w, h = img.size
    left, top = (w - crop) // 2, (h - crop) // 2
    return img.crop((left, top, left + crop, top + crop))


def to_tensor(img: Image.Image) -> np.ndarray:
    """→ (1, 3, 224, 224) float32, ImageNet normalizatsiyasi."""
    x = np.asarray(resize_center_crop(img), dtype=np.float32) / 255.0
    return ((x - MEAN) / STD).transpose(2, 0, 1)[None].astype(np.float32)
