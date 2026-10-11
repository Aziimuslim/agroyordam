"""Agronom roli: ariza → admin tasdig'i, tekshirish navbati, savollar, jamoat va bilimlar bazasi huquqlari."""
from sqlalchemy import select

from app.core.database import SessionLocal
from app.models import Medicine, User
from app.services.ai_client import Prediction
from tests.conftest import auth, image_bytes, register

API = "/api/v1"


async def me(client, h):
    return (await client.get(f"{API}/users/me", headers=h)).json()


async def make_expert(client, admin_headers, username="agro"):
    h = auth(await register(client, username))
    uid = (await me(client, h))["id"]
    r = await client.put(f"{API}/admin/users/{uid}/role", json={"role": "agronomist"}, headers=admin_headers)
    assert r.status_code == 200, r.text
    return h


async def diagnose(client, h, fake_ai, label="Tomato_Late_blight", conf=55.0):
    fake_ai.next = Prediction("Pomidor", label, conf, True)
    r = await client.post(f"{API}/diagnoses", files={"image": ("leaf.png", image_bytes(), "image/png")}, headers=h)
    assert r.status_code == 201, r.text
    return r.json()


async def test_application_approve_and_reject(client, user_headers, admin_headers):
    body = {"specialization": "Mevali bog'lar", "experience_years": 6, "about": "TDAU bitiruvchisi"}
    r = await client.post(f"{API}/experts/applications", json=body, headers=user_headers)
    assert r.status_code == 201 and r.json()["status"] == "pending"
    assert (await client.post(f"{API}/experts/applications", json=body, headers=user_headers)).status_code == 409
    assert (await client.get(f"{API}/experts/applications/me", headers=user_headers)).json()["status"] == "pending"

    # Oddiy foydalanuvchi arizalarni ko'ra olmaydi
    assert (await client.get(f"{API}/admin/expert-applications", headers=user_headers)).status_code == 403
    apps = (await client.get(f"{API}/admin/expert-applications", headers=admin_headers)).json()
    assert len(apps) == 1 and apps[0]["full_name"] == "Test Fermer"

    r = await client.post(f"{API}/admin/expert-applications/{apps[0]['id']}/approve", headers=admin_headers)
    assert r.status_code == 200 and r.json()["status"] == "approved"
    m = await me(client, user_headers)
    assert m["role"] == "agronomist" and m["specialization"] == "Mevali bog'lar"
    notes = (await client.get(f"{API}/notifications", headers=user_headers)).json()
    assert any(n["type"] == "expert_approved" for n in notes)
    # Ikkinchi marta tasdiqlab bo'lmaydi, agronom qayta ariza bera olmaydi
    assert (await client.post(f"{API}/admin/expert-applications/{apps[0]['id']}/approve", headers=admin_headers)).status_code == 409
    assert (await client.post(f"{API}/experts/applications", json=body, headers=user_headers)).status_code == 409

    other = auth(await register(client, "farmer2"))
    a2 = (await client.post(f"{API}/experts/applications", json=body | {"experience_years": 1}, headers=other)).json()
    r = await client.post(f"{API}/admin/expert-applications/{a2['id']}/reject", json={"reason": "Hujjat yuklanmagan"},
                          headers=admin_headers)
    assert r.status_code == 200 and r.json()["reason"] == "Hujjat yuklanmagan"
    assert (await me(client, other))["role"] == "user"
    # Rad etilgandan keyin qayta topshirish mumkin
    assert (await client.post(f"{API}/experts/applications", json=body, headers=other)).status_code == 201


async def test_review_queue_correct_and_notify(client, user_headers, admin_headers, fake_ai):
    expert = await make_expert(client, admin_headers)
    sure = await diagnose(client, user_headers, fake_ai, "Tomato_Late_blight", 95.0)
    unsure = await diagnose(client, user_headers, fake_ai, "Tomato_Late_blight", 55.0)
    assert unsure["low_confidence"] and unsure["review_status"] == "pending"

    r = await client.post(f"{API}/diagnoses/{unsure['id']}/request-review", json={"note": "Pastki barglardan boshlandi"},
                          headers=user_headers)
    assert r.status_code == 200 and r.json()["review_requested"]

    assert (await client.get(f"{API}/experts/queue", headers=user_headers)).status_code == 403
    q = (await client.get(f"{API}/experts/queue", headers=expert)).json()
    assert [i["id"] for i in q] == [unsure["id"], sure["id"]]  # so'ralgan birinchi
    assert q[0]["review_note"] == "Pastki barglardan boshlandi" and q[0]["farmer_name"] == "Test"
    assert [i["id"] for i in (await client.get(f"{API}/experts/queue?filter=requested", headers=expert)).json()] == [unsure["id"]]

    r = await client.post(f"{API}/experts/queue/{unsure['id']}", json={
        "status": "corrected", "label": "Tomato_Early_blight", "comment": "Bu alternarioz. Mankoseb bilan ishlov bering."},
        headers=expert)
    assert r.status_code == 200 and r.json()["id"] == sure["id"]  # javobda — navbatdagi keyingisi
    assert (await client.post(f"{API}/experts/queue/{unsure['id']}", json={"status": "confirmed"}, headers=expert)).status_code == 409

    d = (await client.get(f"{API}/diagnoses/{unsure['id']}", headers=user_headers)).json()
    assert d["review_status"] == "corrected" and d["disease_name"].startswith("Alternarioz")
    assert d["ai_label"] == "Tomato_Late_blight"  # asl AI javobi saqlanadi
    assert d["expert_comment"].startswith("Bu alternarioz") and not d["low_confidence"]
    notes = (await client.get(f"{API}/notifications", headers=user_headers)).json()
    assert any(n["type"] == "diagnosis_reviewed" and n["title"] == "Agronom tashxisni tuzatdi" for n in notes)

    # Tasdiqlangan rasm datasetga tushadi
    stats = (await client.get(f"{API}/admin/dataset/stats", headers=admin_headers)).json()
    assert stats["corrected"] == 1 and stats["usable"] == 1

    await client.post(f"{API}/experts/queue/{sure['id']}", json={"status": "confirmed"}, headers=expert)
    s = (await client.get(f"{API}/experts/stats/me", headers=expert)).json()
    assert s["reviewed_today"] == 2 and s["ai_agreement"] == 50 and s["queue_pending"] == 0
    assert (await client.post(f"{API}/diagnoses/{sure['id']}/request-review", headers=user_headers)).status_code == 409


async def test_questions_flow_quota_and_rating(client, user_headers, admin_headers, fake_ai):
    expert = await make_expert(client, admin_headers)
    expert2 = await make_expert(client, admin_headers, "agro2")
    d = await diagnose(client, user_headers, fake_ai)
    assert (await client.get(f"{API}/questions/quota", headers=user_headers)).json() == {"used": 0, "limit": 2, "remaining": 2}

    r = await client.post(f"{API}/questions", json={"title": "Pomidor barglarida dog'lar", "body": "Nima qilay?",
                                                    "diagnosis_id": d["id"]}, headers=user_headers)
    assert r.status_code == 201
    q = r.json()
    assert q["status"] == "new" and q["diagnosis_name"] and q["image_url"]
    assert (await client.get(f"{API}/diagnoses/{d['id']}", headers=user_headers)).json()["review_requested"]

    assert (await client.get(f"{API}/questions", headers=user_headers)).status_code == 403
    new = (await client.get(f"{API}/questions?status=new", headers=expert)).json()
    assert [x["id"] for x in new] == [q["id"]]

    async with SessionLocal() as db:
        med = await db.scalar(select(Medicine).where(Medicine.name == "Mis oksixlorid"))
    r = await client.post(f"{API}/questions/{q['id']}/messages", json={"body": "Fitoftoroz. Mana dori:", "medicine_id": str(med.id)},
                          headers=expert)
    assert r.status_code == 201
    detail = r.json()
    assert detail["status"] == "answered" and detail["expert"]["role"] == "agronomist"
    assert detail["messages"][0]["medicine"]["name"] == "Mis oksixlorid"
    # Boshqa agronom shu savolga aralasha olmaydi; begona dehqon ko'ra olmaydi
    assert (await client.post(f"{API}/questions/{q['id']}/messages", json={"body": "Men ham"}, headers=expert2)).status_code == 409
    stranger = auth(await register(client, "stranger"))
    assert (await client.get(f"{API}/questions/{q['id']}", headers=stranger)).status_code == 404

    r = await client.post(f"{API}/questions/{q['id']}/messages", json={"body": "Rahmat, purkadim"}, headers=user_headers)
    assert len(r.json()["messages"]) == 2
    assert (await client.post(f"{API}/questions/{q['id']}/messages", json={}, headers=user_headers)).status_code == 422
    assert [x["id"] for x in (await client.get(f"{API}/questions?status=mine", headers=expert)).json()] == [q["id"]]

    assert (await client.post(f"{API}/questions/{q['id']}/close", headers=expert)).json()["status"] == "closed"
    assert (await client.post(f"{API}/questions/{q['id']}/messages", json={"body": "yana"}, headers=user_headers)).status_code == 409
    assert (await client.post(f"{API}/questions/{q['id']}/rate", json={"rating": 5}, headers=user_headers)).json()["rating"] == 5
    experts = (await client.get(f"{API}/experts", headers=user_headers)).json()
    top = next(e for e in experts if e["answers"])
    assert top["rating"] == 5.0 and top["answers"] == 1

    # Bepul limit: oyiga 2 ta
    assert (await client.post(f"{API}/questions", json={"title": "Ikkinchi savol"}, headers=user_headers)).status_code == 201
    r = await client.post(f"{API}/questions", json={"title": "Uchinchi savol"}, headers=user_headers)
    assert r.status_code == 402
    assert len((await client.get(f"{API}/questions/mine", headers=user_headers)).json()) == 2


async def test_premium_has_no_question_limit(client, user_headers):
    async with SessionLocal() as db:
        u = await db.scalar(select(User).where(User.username == "farmer"))
        u.is_premium = True
        await db.commit()
    for i in range(3):
        assert (await client.post(f"{API}/questions", json={"title": f"Savol {i}"}, headers=user_headers)).status_code == 201
    assert (await client.get(f"{API}/questions/quota", headers=user_headers)).json()["limit"] is None


async def test_community_unanswered_and_expert_badge(client, user_headers, admin_headers):
    expert = await make_expert(client, admin_headers)
    p = (await client.post(f"{API}/posts", json={"title": "Uzumda dog'", "category": "question"}, headers=user_headers)).json()
    other = (await client.post(f"{API}/posts", json={"title": "Hosil yaxshi"}, headers=user_headers)).json()
    await client.post(f"{API}/posts/{other['id']}/comments", json={"content": "Tabriklayman"}, headers=user_headers)
    ids = {x["id"] for x in (await client.get(f"{API}/posts?unanswered=true", headers=expert)).json()}
    assert ids == {p["id"], other["id"]}

    c = (await client.post(f"{API}/posts/{p['id']}/comments", json={"content": "Bu eska"}, headers=expert)).json()
    assert c["author"]["role"] == "agronomist"
    ids = {x["id"] for x in (await client.get(f"{API}/posts?unanswered=true", headers=expert)).json()}
    assert ids == {other["id"]}


async def test_catalog_edit_permissions_and_log(client, user_headers, admin_headers):
    expert = await make_expert(client, admin_headers)
    diseases = (await client.get(f"{API}/diseases?q=Fitoftoroz", headers=user_headers)).json()
    did = diseases[0]["id"]
    assert (await client.put(f"{API}/diseases/{did}", json={"treatment": "Yangi matn"}, headers=user_headers)).status_code == 403
    r = await client.put(f"{API}/diseases/{did}", json={"treatment": "Zararlangan barglarni olib tashlang."}, headers=expert)
    assert r.status_code == 200
    assert (await client.delete(f"{API}/diseases/{did}", headers=expert)).status_code == 403  # o'chirish — faqat admin

    log = (await client.get(f"{API}/admin/catalog-changes", headers=admin_headers)).json()
    assert log[0]["action"] == "update" and "davolash" in log[0]["summary"] and log[0]["user_role"] == "agronomist"
    assert (await client.get(f"{API}/admin/catalog-changes", headers=expert)).status_code == 403


async def test_admin_role_management(client, user_headers, admin_headers):
    uid = (await me(client, user_headers))["id"]
    admin_id = (await me(client, admin_headers))["id"]
    assert (await client.put(f"{API}/admin/users/{admin_id}/role", json={"role": "user"}, headers=admin_headers)).status_code == 400
    assert (await client.put(f"{API}/admin/users/{uid}/role", json={"role": "boss"}, headers=admin_headers)).status_code == 422
    assert (await client.put(f"{API}/admin/users/{uid}/role", json={"role": "agronomist"}, headers=user_headers)).status_code == 403
    await client.put(f"{API}/admin/users/{uid}/role", json={"role": "agronomist"}, headers=admin_headers)
    users = (await client.get(f"{API}/admin/users?role=agronomist", headers=admin_headers)).json()
    assert [u["id"] for u in users] == [uid]
    stats = (await client.get(f"{API}/admin/stats/experts", headers=admin_headers)).json()
    assert stats["agronomists"] == 1 and stats["applications_pending"] == 0


async def test_expert_mode_tools(client, user_headers, admin_headers, fake_ai):
    """Agronom rejimi: AI muqobillari, statistika, ish vaqti, o'zgarishlar tarixi, datasetdan rasm, yopilgan savollar."""
    expert = await make_expert(client, admin_headers)
    fake_ai.next = Prediction("Pomidor", "Tomato_Late_blight", 61.0, True,
                              top=[{"label": "Tomato_Late_blight", "confidence": 61.0},
                                   {"label": "Tomato_Early_blight", "confidence": 27.0},
                                   {"label": "Tomato_healthy", "confidence": 8.0}])
    r = await client.post(f"{API}/diagnoses", files={"image": ("leaf.png", image_bytes(), "image/png")}, headers=user_headers)
    d = r.json()

    item = (await client.get(f"{API}/experts/queue/{d['id']}", headers=expert)).json()
    alts = item["alternatives"]
    assert [a["label"] for a in alts] == ["Tomato_Late_blight", "Tomato_Early_blight", "Tomato_healthy"]
    assert alts[0]["disease_name"] and alts[1]["disease_id"] and alts[2]["healthy"] and alts[2]["disease_name"] == "Sog'lom"
    assert item["plant_id"] and item["plant_name"] == "Pomidor"
    # Eski tashxislarda (ai_top yo'q) — bitta muqobil: AI javobi
    old = await diagnose(client, user_headers, fake_ai, "Tomato_Leaf_Mold", 50.0)
    assert [a["label"] for a in (await client.get(f"{API}/experts/queue/{old['id']}", headers=expert)).json()["alternatives"]] == ["Tomato_Leaf_Mold"]

    # Tuzatish → rasm datasetga tushadi → rasmi yo'q kasallik uchun tanlash mumkin
    await client.post(f"{API}/experts/queue/{d['id']}", json={"status": "corrected", "label": "Tomato_Early_blight"}, headers=expert)
    imgs = (await client.get(f"{API}/experts/dataset-images?label=Tomato_Early_blight", headers=expert)).json()
    assert [i["id"] for i in imgs] == [d["id"]]
    assert (await client.get(f"{API}/experts/dataset-images?label=Tomato_Early_blight", headers=user_headers)).status_code == 403
    dis = [x for x in (await client.get(f"{API}/diseases")).json() if x["ai_label"] == "Tomato_Early_blight"][0]
    r = await client.put(f"{API}/diseases/{dis['id']}", json={"image_url": imgs[0]["image_url"], "treatment": "Yangi matn"}, headers=expert)
    assert r.status_code == 200 and r.json()["image_url"] == imgs[0]["image_url"]

    changes = (await client.get(f"{API}/experts/catalog-changes?mine=true", headers=expert)).json()
    assert changes[0]["mine"] and "rasmi" in changes[0]["summary"] and "davolash" in changes[0]["summary"]

    # Ish vaqti va onlayn holati
    r = await client.put(f"{API}/experts/me", json={"work_hours": "Du–Ju, 9:00–18:00", "accepting_questions": False}, headers=expert)
    assert r.json()["work_hours"] == "Du–Ju, 9:00–18:00" and not r.json()["accepting_questions"]
    assert (await me(client, expert))["work_hours"] == "Du–Ju, 9:00–18:00"

    # Savolga javob → o'rtacha javob vaqti; yopilgan savollar "closed_mine"da
    q = (await client.post(f"{API}/questions", json={"title": "Pomidor sarg'aydi"}, headers=user_headers)).json()
    await client.post(f"{API}/questions/{q['id']}/messages", json={"body": "Rasm yuboring"}, headers=expert)
    await client.post(f"{API}/questions/{q['id']}/close", headers=expert)
    assert [x["id"] for x in (await client.get(f"{API}/questions?status=closed_mine", headers=expert)).json()] == [q["id"]]
    assert (await client.get(f"{API}/questions?status=mine", headers=expert)).json() == []
    stats = (await client.get(f"{API}/experts/stats/me", headers=expert)).json()
    assert stats["avg_answer_minutes"] == 0 and stats["reviewed_total"] == 1 and stats["ratings_count"] == 0
