"""Model versiyalari: GitHub Release "model-vN" dan yuklab olish, ishga tushirish va qaytarish.

Faol versiya MODEL_STORE/active.json da saqlanadi (Docker volume) — servis qayta ishga tushganda ham o'sha model.
Store bo'sh bo'lsa — image ichidagi model (MODEL_PATH, odatda model-v1).
"""
import json
import logging
import os
import re
import shutil
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

from app.inference.classifier import Classifier, OnnxClassifier, load_classifier

log = logging.getLogger(__name__)
FILES = ("agro-mobilenetv3.onnx", "agro-mobilenetv3.labels.txt", "agro-mobilenetv3.metrics.json")
TAG_RE = re.compile(r"^model-v\d{1,4}$")


def store() -> Path:
    return Path(os.getenv("MODEL_STORE", "/srv/models-store"))


def release_base() -> str:
    return os.getenv("MODEL_RELEASE_BASE", "https://github.com/Aziimuslim/agroyordam/releases/download").rstrip("/")


def _metrics(folder: Path) -> dict | None:
    f = folder / FILES[2]
    try:
        return json.loads(f.read_text()) if f.exists() else None
    except ValueError:
        return None


def load_active() -> tuple[Classifier, str | None, Path | None]:
    """→ (klassifikator, versiya, model fayli)."""
    try:
        tag = json.loads((store() / "active.json").read_text())["tag"]
        path = store() / tag / FILES[0]
        if TAG_RE.match(tag) and path.exists():
            log.info("Faol model: %s", tag)
            return OnnxClassifier(str(path)), tag, path
    except (OSError, ValueError, KeyError) as exc:
        if not isinstance(exc, FileNotFoundError):
            log.warning("active.json o'qilmadi (%s) — image ichidagi model ishlatiladi", exc)
    clf = load_classifier()
    path = Path(os.environ["MODEL_PATH"]) if isinstance(clf, OnnxClassifier) and os.getenv("MODEL_PATH") else None
    return clf, (os.getenv("MODEL_TAG", "model-v1") if path else None), path


def fetch(tag: str) -> Path:
    """Release fayllarini MODEL_STORE/<tag>/ ga yuklaydi (bor bo'lsa qayta yuklamaydi)."""
    if not TAG_RE.match(tag):
        raise ValueError("Noto'g'ri versiya nomi")
    dest = store() / tag
    if (dest / FILES[0]).exists() and (dest / FILES[1]).exists():
        return dest
    tmp = store() / f".{tag}.tmp"
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True)
    try:
        for name in FILES:
            try:
                with urllib.request.urlopen(f"{release_base()}/{tag}/{name}", timeout=120) as r, open(tmp / name, "wb") as f:
                    shutil.copyfileobj(r, f)
            except Exception:
                if name == FILES[2]:  # metrics ixtiyoriy (eski versiyalarda bo'lmasligi mumkin)
                    continue
                raise
        shutil.rmtree(dest, ignore_errors=True)
        tmp.rename(dest)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return dest


def activate(tag: str) -> tuple[OnnxClassifier, Path]:
    """Yuklaydi, tekshiradi va faol qilib belgilaydi. Xato bo'lsa — eski model ishlashda davom etadi."""
    folder = fetch(tag)
    clf = OnnxClassifier(str(folder / FILES[0]))
    probs = clf.probabilities(Image.fromarray(np.full((256, 256, 3), (60, 140, 40), dtype=np.uint8)))
    if probs.shape != (len(clf.labels),) or not np.isfinite(probs).all():
        raise ValueError("Model fayli buzilgan: sinflar soni mos emas")
    (store() / "active.json").write_text(json.dumps({"tag": tag}))
    return clf, folder / FILES[0]


def info(clf: Classifier, tag: str | None, path: Path | None) -> dict:
    from datetime import datetime, timezone

    out = {"model": type(clf).__name__, "model_tag": tag}
    if isinstance(clf, OnnxClassifier) and path and path.exists():
        st = path.stat()
        out |= {"model_file": path.name, "model_size_mb": round(st.st_size / 1e6, 1),
                "model_updated": datetime.fromtimestamp(st.st_mtime, timezone.utc).isoformat(), "classes": len(clf.labels),
                "metrics": _metrics(path.parent)}
    return out
