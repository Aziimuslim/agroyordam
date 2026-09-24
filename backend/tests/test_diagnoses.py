from app.services.ai_client import Prediction
from tests.conftest import image_bytes


def files():
    return {"image": ("leaf.png", image_bytes(), "image/png")}


async def test_diagnosis_full_pipeline(client, user_headers, fake_ai):
    plants = (await client.get("/api/v1/plants")).json()
    tomato = next(p for p in plants if p["name"] == "Pomidor")
    crop = (await client.post("/api/v1/crops", json={"name": "Pomidorlarim", "plant_id": tomato["id"]}, headers=user_headers)).json()
    r = await client.post("/api/v1/diagnoses", files=files(), data={"crop_id": crop["id"]}, headers=user_headers)
    assert r.status_code == 201, r.text
    assert fake_ai.last_hint == "Pomidor"
    d = r.json()
    assert d["disease_name"].startswith("Fitoftoroz") and d["risk_level"] == "high"
    assert d["medicines"] and d["treatment"] and not d["low_confidence"]
    assert d["image_url"].startswith("/media/diagnoses/")

    crop = (await client.get(f"/api/v1/crops/{crop['id']}", headers=user_headers)).json()
    assert crop["health_score"] < 60 and crop["last_disease"]
    hist = (await client.get(f"/api/v1/crops/{crop['id']}/health-history", headers=user_headers)).json()
    assert len(hist) == 2

    assert len((await client.get("/api/v1/diagnoses", headers=user_headers)).json()) == 1
    assert (await client.get(f"/api/v1/diagnoses/{d['id']}", headers=user_headers)).status_code == 200
    notes = (await client.get("/api/v1/notifications", headers=user_headers)).json()
    assert notes[0]["type"] == "diagnosis_ready"

    post = await client.post(f"/api/v1/diagnoses/{d['id']}/share", headers=user_headers)
    assert post.status_code == 201 and post.json()["diagnosis_id"] == d["id"]
    assert (await client.delete(f"/api/v1/diagnoses/{d['id']}", headers=user_headers)).status_code == 204


async def test_healthy_and_low_confidence(client, user_headers, fake_ai):
    fake_ai.next = Prediction("Pomidor", "Tomato_healthy", 95, True)
    d = (await client.post("/api/v1/diagnoses", files=files(), headers=user_headers)).json()
    assert d["is_healthy"] and d["disease_id"] is None
    fake_ai.next = Prediction("Pomidor", "Tomato_Late_blight", 41, True)
    d = (await client.post("/api/v1/diagnoses", files=files(), headers=user_headers)).json()
    # Ishonch past bo'lsa ham eng ehtimoliy kasallik qaytadi, lekin "taxminiy" deb belgilanadi
    assert d["low_confidence"] and d["disease_name"].startswith("Fitoftoroz")


async def test_care_plan_adds_diagnosis_to_garden(client, user_headers, fake_ai):
    tomato = next(p for p in (await client.get("/api/v1/plants")).json() if p["name"] == "Pomidor")
    fake_ai.next = Prediction("Pomidor", "Tomato_Late_blight", 88, True)
    d = (await client.post("/api/v1/diagnoses", files=files(), data={"plant_id": tomato["id"]}, headers=user_headers)).json()
    assert d["crop_id"] is None and fake_ai.last_hint == "Pomidor"

    plan = (await client.get(f"/api/v1/diagnoses/{d['id']}/care-plan", headers=user_headers)).json()
    assert plan["disease_name"].startswith("Fitoftoroz") and plan["duration_days"] == 21  # high risk
    titles = [t["title"] for t in plan["tasks"]]
    sprays = [t for t in plan["tasks"] if "ishlov berish" in t["title"]]
    assert [t["day"] for t in sprays] == [0, 7, 14]  # "3 marta 7 kun oralig'ida"
    assert sum(t == "Kunlik ko'rik" for t in titles) == 20
    assert plan["tasks"][-1]["reminder_type"] == "recheck" and plan["tasks"][-1]["day"] == 21
    assert [t["day"] for t in plan["tasks"]] == sorted(t["day"] for t in plan["tasks"])

    r = await client.post(f"/api/v1/diagnoses/{d['id']}/care-plan", json={}, headers=user_headers)
    assert r.status_code == 201, r.text
    applied = r.json()
    assert applied["reminders_created"] == len(plan["tasks"])

    crop = (await client.get(f"/api/v1/crops/{applied['crop_id']}", headers=user_headers)).json()
    assert crop["name"] == "Pomidor" and crop["plant_name"] == "Pomidor"
    assert crop["health_score"] < 60 and crop["last_disease"].startswith("Fitoftoroz")
    logs = (await client.get(f"/api/v1/crops/{crop['id']}/logs", headers=user_headers)).json()
    assert "21 kunlik" in logs[0]["content"]
    assert (await client.get(f"/api/v1/diagnoses/{d['id']}", headers=user_headers)).json()["crop_id"] == crop["id"]

    # Qayta qo'llash eslatmalarni ikki barobar ko'paytirmaydi
    await client.post(f"/api/v1/diagnoses/{d['id']}/care-plan", json={}, headers=user_headers)
    rems = (await client.get("/api/v1/reminders", headers=user_headers)).json()
    assert len([x for x in rems if x["diagnosis_id"] == d["id"]]) == len(plan["tasks"])

    # Sog'lom tashxis — mavjud ekinga yengil parvarish rejasi
    fake_ai.next = Prediction("Pomidor", "Tomato_healthy", 95, True)
    h = (await client.post("/api/v1/diagnoses", files=files(), headers=user_headers)).json()
    r = await client.post(f"/api/v1/diagnoses/{h['id']}/care-plan", json={"crop_id": crop["id"]}, headers=user_headers)
    assert r.status_code == 201 and r.json()["crop_id"] == crop["id"]
    assert (await client.get(f"/api/v1/crops/{crop['id']}", headers=user_headers)).json()["health_score"] == 100


async def test_invalid_image_and_daily_limit(client, user_headers, fake_ai):
    fake_ai.next = Prediction(None, None, 0, False, "Rasm xira")
    r = await client.post("/api/v1/diagnoses", files=files(), headers=user_headers)
    assert r.status_code == 422 and "xira" in r.json()["detail"]
    r = await client.post("/api/v1/diagnoses", files={"image": ("x.txt", b"hello", "text/plain")}, headers=user_headers)
    assert r.status_code == 415

    fake_ai.next = Prediction("Pomidor", "Tomato_Late_blight", 90, True)
    for _ in range(3):
        assert (await client.post("/api/v1/diagnoses", files=files(), headers=user_headers)).status_code == 201
    r = await client.post("/api/v1/diagnoses", files=files(), headers=user_headers)
    assert r.status_code == 402


async def test_ai_service_down(client, user_headers, monkeypatch):
    from app.services import ai_client
    from app.services.ai_client import AIServiceError

    class Down:
        async def predict(self, *a, **k):
            raise AIServiceError("down")

    monkeypatch.setattr(ai_client, "_client", Down())
    r = await client.post("/api/v1/diagnoses", files=files(), headers=user_headers)
    assert r.status_code == 503


async def test_ai_chat(client, user_headers):
    r = await client.post("/api/v1/ai/chat", json={"message": "Pomidor bargida qo'ng'ir suvli dog'lar paydo bo'ldi, fitoftoroz emasmi?"}, headers=user_headers)
    assert r.status_code == 200
    assert "fitoftoroz" in r.json()["reply"]["content"].lower()
    r = await client.post("/api/v1/ai/chat", json={"message": "Qachon sug'orish kerak?"}, headers=user_headers)
    assert "sug'or" in r.json()["reply"]["content"].lower()
    r = await client.post("/api/v1/ai/chat", json={"message": "Bordo suyuqligi haqida"}, headers=user_headers)
    assert "Bordo" in r.json()["reply"]["content"]
    r = await client.post("/api/v1/ai/chat", json={"message": "salom"}, headers=user_headers)
    assert "aniqroq" in r.json()["reply"]["content"]
    hist = (await client.get("/api/v1/ai/chat/history", headers=user_headers)).json()
    assert len(hist) == 8 and hist[0]["role"] == "user"
