"""AI'ni yaxshilash sikli: dataset qamrovi, model versiyalari va ishga tushirish qoidasi, qayta o'qitishni boshlash."""
import io
import zipfile

from app.core.config import settings
from app.services import model_ops
from app.services.ai_client import Prediction
from tests.conftest import image_bytes
from tests.test_experts import make_expert

API = "/api/v1"


def rel(tag, field=None, base=None, n=0):
    return {"tag": tag, "created_at": None, "url": None, "classes": 34, "val_accuracy": 0.97, "field_test_accuracy": field,
            "field_test_samples": n, "baseline_model": None, "baseline_field_test_accuracy": base, "field_train_images": 0}


async def test_coverage_counts_and_unknown_classes(client, user_headers, admin_headers, fake_ai):
    expert = await make_expert(client, admin_headers)
    fake_ai.next = Prediction("Bodring", "Squash_Powdery_mildew", 40.0, True)
    d = (await client.post(f"{API}/diagnoses", files={"image": ("l.png", image_bytes(), "image/png")}, headers=user_headers)).json()
    await client.post(f"{API}/experts/queue/{d['id']}", json={"status": "corrected", "label": "Cucumber_Powdery_mildew"}, headers=expert)
    cov = (await client.get(f"{API}/admin/ai/coverage", headers=admin_headers)).json()
    first = cov["classes"][0]
    assert first["in_model"] is False  # model bilmaydigan sinflar birinchi
    cuc = next(c for c in cov["classes"] if c["label"] == "Cucumber_Powdery_mildew")
    assert cuc["train"] + cuc["test"] == 1 and cuc["in_model"] is False and cuc["plant"] == "Bodring"
    assert next(c for c in cov["classes"] if c["label"] == "Tomato_Late_blight")["in_model"] is True


async def test_models_activation_rules(client, admin_headers, user_headers, fake_ai, monkeypatch):
    rels = [rel("model-v4"), rel("model-v3", 0.70, 0.78, 50), rel("model-v2", 0.84, 0.79, 50), rel("model-v1")]

    async def fake_releases():
        return [dict(r) for r in rels]
    monkeypatch.setattr(model_ops, "releases", fake_releases)
    fake_ai.active_tag, fake_ai.activated = "model-v1", []

    m = (await client.get(f"{API}/admin/ai/models", headers=admin_headers)).json()
    by = {r["tag"]: r for r in m["models"]}
    assert m["active_tag"] == "model-v1" and by["model-v1"]["active"] and not by["model-v1"]["can_activate"]
    assert by["model-v2"]["can_activate"]                       # dala testida yaxshiroq
    assert not by["model-v3"]["can_activate"] and "yomonroq" in by["model-v3"]["reason"]
    assert not by["model-v4"]["can_activate"] and by["model-v4"]["can_force"]  # dala testi yo'q

    assert (await client.post(f"{API}/admin/ai/models/model-v2/activate", headers=user_headers)).status_code == 403
    assert (await client.post(f"{API}/admin/ai/models/model-v3/activate", headers=admin_headers)).status_code == 409
    r = await client.post(f"{API}/admin/ai/models/model-v2/activate", headers=admin_headers)
    assert r.status_code == 200 and fake_ai.activated == ["model-v2"]
    # Qaytarish (eski versiya) — har doim mumkin
    assert (await client.post(f"{API}/admin/ai/models/model-v1/activate", headers=admin_headers)).status_code == 200
    # Dala testisiz — faqat majburan
    assert (await client.post(f"{API}/admin/ai/models/model-v4/activate", headers=admin_headers)).status_code == 409
    r = await client.post(f"{API}/admin/ai/models/model-v4/activate", json={"force": True}, headers=admin_headers)
    assert r.status_code == 200 and fake_ai.activated[-1] == "model-v4"
    assert (await client.post(f"{API}/admin/ai/models/model-v9/activate", headers=admin_headers)).status_code == 404
    log = [a["summary"] for a in (await client.get(f"{API}/admin/audit", headers=admin_headers)).json() if a["action"] == "model_activate"]
    assert len(log) == 3 and "majburan" in log[0] and "qaytarildi" in log[1]


async def test_training_dispatch_and_one_time_ticket(client, admin_headers, user_headers, fake_ai, monkeypatch):
    assert (await client.post(f"{API}/admin/ai/training", headers=admin_headers)).status_code == 503  # sozlanmagan
    monkeypatch.setattr(settings, "GITHUB_TRAIN_TOKEN", "ghp_test")
    monkeypatch.setattr(settings, "PUBLIC_URL", "https://agro.test")
    calls = []

    async def fake_dispatch(url, baseline):
        calls.append((url, baseline))

    async def no_runs():
        return []
    monkeypatch.setattr(model_ops, "dispatch", fake_dispatch)
    monkeypatch.setattr(model_ops, "runs", no_runs)

    # Tasdiqlangan rasm bor — havola beriladi
    expert = await make_expert(client, admin_headers)
    fake_ai.next = Prediction("Pomidor", "Tomato_Late_blight", 90.0, True)
    d = (await client.post(f"{API}/diagnoses", files={"image": ("l.png", image_bytes(), "image/png")}, headers=user_headers)).json()
    await client.post(f"{API}/experts/queue/{d['id']}", json={"status": "confirmed"}, headers=expert)

    assert (await client.post(f"{API}/admin/ai/training", headers=expert)).status_code == 403
    r = await client.post(f"{API}/admin/ai/training", headers=admin_headers)
    assert r.status_code == 200 and r.json()["field_images"] == 1
    url, baseline = calls[0]
    assert url.startswith("https://agro.test/api/v1/dataset/ticket/") and baseline == fake_ai.active_tag
    path = url.removeprefix("https://agro.test")
    z = await client.get(path)
    assert z.status_code == 200
    names = zipfile.ZipFile(io.BytesIO(z.content)).namelist()
    assert any(n.endswith(f"/Tomato_Late_blight/{d['id']}.png") and n.split("/")[0] in ("train", "test") for n in names)
    assert (await client.get(path)).status_code == 403  # bir martalik
    assert (await client.get(f"{API}/dataset/ticket/xxx")).status_code == 403
    t = (await client.get(f"{API}/admin/ai/training", headers=admin_headers)).json()
    assert t["configured"] is True and t["runs"] == []
