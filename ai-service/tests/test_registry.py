"""Model versiyalari: release'dan yuklash, faollashtirish, qayta ishga tushganda eslab qolish, buzilgan versiyani rad etish."""
import json
import os
import shutil
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.inference import registry
from app.models.labels import MODEL_LABELS

MODEL = Path(os.getenv("MODEL_PATH") or Path(__file__).resolve().parents[1] / "models" / "agro-mobilenetv3.onnx")
pytestmark = pytest.mark.skipif(not MODEL.exists(), reason="ONNX model yo'q")


@pytest.fixture
def releases(tmp_path, monkeypatch):
    """file:// orqali "GitHub Release": model-v2 — yaroqli, model-v3 — buzilgan fayl."""
    rel = tmp_path / "releases"
    (rel / "model-v2").mkdir(parents=True)
    shutil.copy(MODEL, rel / "model-v2" / registry.FILES[0])
    (rel / "model-v2" / registry.FILES[1]).write_text("\n".join(MODEL_LABELS) + "\n")
    (rel / "model-v2" / registry.FILES[2]).write_text(json.dumps({"field_test_accuracy": 0.84}))
    (rel / "model-v3").mkdir()
    (rel / "model-v3" / registry.FILES[0]).write_bytes(b"not a model")
    (rel / "model-v3" / registry.FILES[1]).write_text("A\nB\n")
    monkeypatch.setenv("MODEL_RELEASE_BASE", rel.as_uri())
    monkeypatch.setenv("MODEL_STORE", str(tmp_path / "store"))
    (tmp_path / "store").mkdir()
    return tmp_path


@pytest.fixture
def main_app(releases):
    from app import main

    saved = (main.classifier, main.model_tag, main.model_path)
    yield main
    main.classifier, main.model_tag, main.model_path = saved  # boshqa testlarga ta'sir qilmasin


def test_activate_switch_and_persist(releases, main_app):
    c = TestClient(main_app.app)
    r = c.post("/model/activate", json={"tag": "model-v2"})
    assert r.status_code == 200, r.text
    assert r.json()["model_tag"] == "model-v2" and r.json()["metrics"]["field_test_accuracy"] == 0.84
    assert c.get("/health").json()["model_tag"] == "model-v2"
    # Qayta ishga tushganda ham o'sha versiya
    clf, tag, path = registry.load_active()
    assert tag == "model-v2" and path.parent.name == "model-v2"

    # Buzilgan versiya — 502, eski model ishlashda davom etadi
    r = c.post("/model/activate", json={"tag": "model-v3"})
    assert r.status_code == 502
    assert c.get("/model").json()["model_tag"] == "model-v2"
    assert json.loads((releases / "store" / "active.json").read_text())["tag"] == "model-v2"

    assert c.post("/model/activate", json={"tag": "../etc"}).status_code == 422
    assert c.post("/model/activate", json={"tag": "model-v9"}).status_code == 502  # release yo'q
