"""Admin web panel API: boshqaruv paneli, foydalanuvchilar, agronomlar, AI, bilimlar bazasini qaytarish,
moderatsiya, tariflar, tizim (zaxira), ommaviy xabar va harakatlar jurnali."""
from app.core.config import settings
from app.services.ai_client import Prediction
from tests.conftest import auth, image_bytes, register
from tests.test_experts import make_expert

API = "/api/v1"


async def test_dashboard_users_and_audit(client, user_headers, admin_headers, fake_ai):
    fake_ai.next = Prediction("Pomidor", "Tomato_Late_blight", 60.0, True)
    await client.post(f"{API}/diagnoses", files={"image": ("l.png", image_bytes(), "image/png")}, headers=user_headers)
    assert (await client.get(f"{API}/admin/dashboard", headers=user_headers)).status_code == 403
    d = (await client.get(f"{API}/admin/dashboard?days=7", headers=admin_headers)).json()
    assert d["diagnoses"] == 1 and len(d["diagnoses_daily"]) == 7 and d["diagnoses_daily"][-1]["count"] == 1
    assert d["users_new"] >= 2 and d["attention"]["applications"] == 0 and d["regions"]

    users = (await client.get(f"{API}/admin/users?q=farmer", headers=admin_headers)).json()
    farmer = users[0]
    assert farmer["diagnoses"] == 1
    r = await client.put(f"{API}/admin/users/{farmer['id']}/block?blocked=true&reason=spam", headers=admin_headers)
    assert r.status_code == 200 and r.json()["is_active"] is False
    assert [u["id"] for u in (await client.get(f"{API}/admin/users?blocked=true", headers=admin_headers)).json()] == [farmer["id"]]
    await client.put(f"{API}/admin/users/{farmer['id']}/block?blocked=false", headers=admin_headers)
    await client.put(f"{API}/admin/users/{farmer['id']}/role", json={"role": "agronomist"}, headers=admin_headers)
    log = (await client.get(f"{API}/admin/audit", headers=admin_headers)).json()
    assert [a["action"] for a in log][:3] == ["role", "unblock", "block"] and "spam" in log[2]["summary"]
    assert log[0]["actor"] == "Admin"


async def test_experts_ai_and_revert(client, user_headers, admin_headers, fake_ai):
    expert = await make_expert(client, admin_headers)
    fake_ai.next = Prediction("Pomidor", "Tomato_Late_blight", 55.0, True)
    d = (await client.post(f"{API}/diagnoses", files={"image": ("l.png", image_bytes(), "image/png")}, headers=user_headers)).json()
    await client.post(f"{API}/experts/queue/{d['id']}", json={"status": "corrected", "label": "Tomato_Early_blight"}, headers=expert)

    ex = (await client.get(f"{API}/admin/experts", headers=admin_headers)).json()
    assert ex[0]["reviewed"] == 1 and ex[0]["ai_agreement"] == 0
    ai = (await client.get(f"{API}/admin/ai", headers=admin_headers)).json()
    assert ai["corrected"] == 1 and ai["pairs"][0]["ai_label"] == "Tomato_Late_blight" and ai["pairs"][0]["label"] == "Tomato_Early_blight"

    # Agronom tahriri → admin qaytaradi
    dis = [x for x in (await client.get(f"{API}/diseases")).json() if x["ai_label"] == "Tomato_Early_blight"][0]
    old = dis["treatment"]
    await client.put(f"{API}/diseases/{dis['id']}", json={"treatment": "Noto'g'ri matn", "risk_level": "low"}, headers=expert)
    meds = (await client.get(f"{API}/medicines")).json()
    orig = sorted(m["id"] for m in (await client.get(f"{API}/diseases/{dis['id']}")).json()["medicines"])
    other = next(m["id"] for m in meds if m["id"] not in orig)
    await client.put(f"{API}/diseases/{dis['id']}/medicines", json={"items": [{"medicine_id": other}]}, headers=expert)
    changes = (await client.get(f"{API}/admin/catalog-changes", headers=admin_headers)).json()
    assert changes[0]["revertible"] and changes[1]["revertible"]
    assert [m["id"] for m in (await client.get(f"{API}/diseases/{dis['id']}")).json()["medicines"]] == [other]
    for ch in changes[:2]:
        r = await client.post(f"{API}/admin/catalog-changes/{ch['id']}/revert", headers=admin_headers)
        assert r.status_code == 200, r.text
    back = (await client.get(f"{API}/diseases/{dis['id']}")).json()
    assert back["treatment"] == old and back["risk_level"] == dis["risk_level"]
    assert sorted(m["id"] for m in back["medicines"]) == orig
    assert (await client.post(f"{API}/admin/catalog-changes/{changes[0]['id']}/revert", headers=admin_headers)).status_code == 409
    kb = (await client.get(f"{API}/admin/kb/diseases", headers=admin_headers)).json()
    assert any(k["medicines"] > 0 for k in kb)

    # Dori tahririda faqat o'zgargan maydon yuboriladi (nom yuborilmasa ham 200)
    r = await client.put(f"{API}/medicines/{meds[0]['id']}", json={"usage": "Yangi me'yor"}, headers=expert)
    assert r.status_code == 200 and r.json()["name"] == meds[0]["name"]


async def test_moderation_settings_broadcast_system(client, user_headers, admin_headers, tmp_path, monkeypatch):
    other = auth(await register(client, "otabek"))
    post = (await client.post(f"{API}/posts", json={"title": "Arzon dori sotaman", "content": "telegram @..."}, headers=other)).json()
    for h in (user_headers, admin_headers):
        await client.post(f"{API}/reports", json={"post_id": post["id"], "reason": "Reklama"}, headers=h)
    rep = (await client.get(f"{API}/admin/reports", headers=admin_headers)).json()
    assert rep[0]["count"] == 2 and rep[0]["reasons"] == ["Reklama"] and rep[0]["kind"] == "post"
    assert (await client.post(f"{API}/admin/reports/hide", json={"kind": "post", "target_id": post["id"]}, headers=admin_headers)).status_code == 200
    assert (await client.get(f"{API}/admin/reports", headers=admin_headers)).json() == []
    assert (await client.get(f"{API}/admin/dashboard", headers=admin_headers)).json()["attention"]["reports"] == 0
    assert (await client.get(f"{API}/posts/{post['id']}", headers=other)).status_code == 404

    # Tariflar va bepul limitlar
    r = await client.put(f"{API}/admin/settings", json={"price_monthly": 29000, "free_questions_month": 3}, headers=admin_headers)
    assert r.status_code == 200
    assert {p["code"]: p["price"] for p in (await client.get(f"{API}/subscriptions/plans")).json()}["monthly"] in (29000, "29000", "29000.00", 29000.0)
    assert (await client.get(f"{API}/questions/quota", headers=user_headers)).json()["limit"] == 3
    assert (await client.put(f"{API}/admin/settings", json={"price_monthly": 1}, headers=admin_headers)).status_code == 422
    await client.put(f"{API}/admin/settings", json={"price_monthly": 29000, "price_yearly": 250000}, headers=admin_headers)
    settings_log = [a["summary"] for a in (await client.get(f"{API}/admin/audit", headers=admin_headers)).json() if a["action"] == "settings"]
    assert len(settings_log) == 1 and "yil" not in settings_log[0]  # o'zgarmagan qiymat jurnalga yozilmaydi
    pay = (await client.get(f"{API}/admin/payments", headers=admin_headers)).json()
    assert pay["mode"] == "sandbox" and len(pay["monthly"]) == 6

    # Ommaviy xabar
    aud = (await client.get(f"{API}/admin/broadcast/audiences", headers=admin_headers)).json()
    assert aud[0]["key"] == "all" and aud[0]["count"] >= 3
    r = await client.post(f"{API}/admin/broadcast", json={"audience": "farmers", "title": "Yomg'ir kutilmoqda",
                                                         "body": "Purkashni ko'chiring"}, headers=admin_headers)
    assert r.json()["sent"] >= 2
    notes = (await client.get(f"{API}/notifications", headers=user_headers)).json()
    assert any(n["type"] == "broadcast" for n in notes)

    # Tizim: zaxira papkasi
    monkeypatch.setattr(settings, "BACKUP_DIR", str(tmp_path))
    (tmp_path / "status").write_text("ok 2026-10-11_2200 — baza 4.1M, serverda + tashqi xotirada (offsite:b)")
    (tmp_path / ".last_ok").write_text("1791763200")
    (tmp_path / "agroyordam-2026-10-11_2200.sql.gz").write_bytes(b"x" * 2000)
    (tmp_path / "req").mkdir()
    sysinfo = (await client.get(f"{API}/admin/system", headers=admin_headers)).json()
    assert sysinfo["backup"]["ok"] and sysinfo["backup"]["offsite"] and sysinfo["backup"]["files"][0]["name"] == "2026-10-11_2200"
    assert (await client.post(f"{API}/admin/system/backup-now", headers=admin_headers)).status_code == 200
    assert (tmp_path / "req" / "now").exists()
    log = [a["action"] for a in (await client.get(f"{API}/admin/audit", headers=admin_headers)).json()]
    assert {"report_hide", "settings", "broadcast", "backup_now"} <= set(log)
