import csv
import io
import zipfile

from app.services.ai_client import Prediction
from tests.conftest import image_bytes


def files():
    return {"image": ("leaf.png", image_bytes(), "image/png")}


async def diagnose(client, headers, fake_ai, label, conf=90):
    fake_ai.next = Prediction("Pomidor", label, conf, True)
    r = await client.post("/api/v1/diagnoses", files=files(), headers=headers)
    assert r.status_code == 201, r.text
    return r.json()


async def test_feedback_review_stats_and_export(client, user_headers, admin_headers, fake_ai):
    a = await diagnose(client, user_headers, fake_ai, "Tomato_Late_blight")
    b = await diagnose(client, user_headers, fake_ai, "Tomato_healthy", 95)
    c = await diagnose(client, user_headers, fake_ai, "Tomato_Early_blight", 55)
    assert a["ai_label"] == "Tomato_Late_blight" and b["ai_label"] == "Tomato_healthy"

    # Foydalanuvchi fikri
    r = await client.post(f"/api/v1/diagnoses/{c['id']}/feedback", json={"correct": False}, headers=user_headers)
    assert r.status_code == 200 and r.json()["user_feedback"] is False
    await client.post(f"/api/v1/diagnoses/{a['id']}/feedback", json={"correct": True}, headers=user_headers)

    # Oddiy foydalanuvchi dataset bo'limiga kira olmaydi
    assert (await client.get("/api/v1/admin/dataset/items", headers=user_headers)).status_code == 403

    # Navbat: "xato" deb belgilangan birinchi
    queue = (await client.get("/api/v1/admin/dataset/items", headers=admin_headers)).json()
    assert [q["id"] for q in queue][0] == c["id"] and len(queue) == 3
    flagged = (await client.get("/api/v1/admin/dataset/items?flagged=true", headers=admin_headers)).json()
    assert [q["id"] for q in flagged] == [c["id"]]

    labels = (await client.get("/api/v1/admin/dataset/labels", headers=admin_headers)).json()
    assert "Tomato_healthy" in labels and "Cucumber_Powdery_mildew" in labels  # bilimlar bazasidan

    put = lambda d, body: client.put(f"/api/v1/admin/dataset/items/{d['id']}", json=body, headers=admin_headers)  # noqa: E731
    assert (await put(a, {"status": "confirmed"})).json()["verified_label"] == "Tomato_Late_blight"
    assert (await put(b, {"status": "confirmed"})).json()["verified_label"] == "Tomato_healthy"
    assert (await put(c, {"status": "corrected", "label": "bad label"})).status_code == 422
    assert (await put(c, {"status": "corrected", "label": "Tomato_Septoria_leaf_spot"})).json()["review_status"] == "corrected"

    st = (await client.get("/api/v1/admin/dataset/stats", headers=admin_headers)).json()
    assert st["usable"] == 3 and st["pending"] == 0 and st["corrected"] == 1
    assert st["feedback_wrong"] == 1 and st["feedback_correct"] == 1
    assert st["ai_field_accuracy"] == 66.7
    assert {x["label"] for x in st["labels"]} == {"Tomato_Late_blight", "Tomato_healthy", "Tomato_Septoria_leaf_spot"}

    # Eksport: qisqa muddatli havola, token'siz/yaroqsiz — rad
    assert (await client.get("/api/v1/dataset/export?token=xxx")).status_code == 403
    link = (await client.post("/api/v1/admin/dataset/export-link", headers=admin_headers)).json()["url"]
    r = await client.get(link)
    assert r.status_code == 200 and r.headers["x-dataset-items"] == "3"
    zf = zipfile.ZipFile(io.BytesIO(r.content))
    names = set(zf.namelist())
    assert f"Tomato_Septoria_leaf_spot/{c['id']}.png" in names and "manifest.csv" in names
    rows = list(csv.DictReader(io.StringIO(zf.read("manifest.csv").decode())))
    assert len(rows) == 3 and {r["label"] for r in rows} >= {"Tomato_healthy"}

    # Rad etilgan rasm eksportga kirmaydi
    await put(b, {"status": "rejected"})
    link = (await client.post("/api/v1/admin/dataset/export-link", headers=admin_headers)).json()["url"]
    assert (await client.get(link)).headers["x-dataset-items"] == "2"
