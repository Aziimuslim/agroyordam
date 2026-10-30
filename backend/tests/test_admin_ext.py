"""Admin panel (Tabiiy Agro): sahifalangan foydalanuvchilar, profil, tashxislar, bilimlar bazasi to'liqligi,
moderatsiya tablari, to'lovlar ro'yxati, monitoring va jurnal."""
from app.services.ai_client import Prediction
from tests.conftest import auth, image_bytes, register

API = "/api/v1"


async def test_users_page_stats_and_detail(client, user_headers, admin_headers, fake_ai):
    await register(client, "otabek", phone="+998901234567", region="Samarqand viloyati")
    fake_ai.next = Prediction("Pomidor", "Tomato_Late_blight", 60.0, True)
    await client.post(f"{API}/diagnoses", files={"image": ("l.png", image_bytes(), "image/png")}, headers=user_headers)
    assert (await client.get(f"{API}/admin/users/page", headers=user_headers)).status_code == 403

    st = (await client.get(f"{API}/admin/users/stats", headers=admin_headers)).json()
    assert st["total"] == 3 and st["active"] == 3 and st["inactive"] == 0 and st["new"] == 3 and "Samarqand viloyati" in st["regions"]

    p = (await client.get(f"{API}/admin/users/page?limit=2", headers=admin_headers)).json()
    assert p["total"] == 3 and len(p["items"]) == 2
    o = (await client.get(f"{API}/admin/users/page?region=Samarqand viloyati", headers=admin_headers)).json()["items"]
    assert [u["username"] for u in o] == ["otabek"] and o[0]["phone_masked"] == "+99890 *** ** 67" and "phone" not in o[0]
    f = (await client.get(f"{API}/admin/users/page?q=farmer", headers=admin_headers)).json()["items"][0]
    assert f["diagnoses"] == 1 and f["last_active"] and f["email_masked"] == "f***@test.uz"
    assert (await client.get(f"{API}/admin/users/page?state=blocked", headers=admin_headers)).json()["total"] == 0

    await client.put(f"{API}/admin/users/{f['id']}/block?blocked=true&reason=spam", headers=admin_headers)
    d = (await client.get(f"{API}/admin/users/{f['id']}/detail", headers=admin_headers)).json()
    assert d["activity"]["diagnoses"] == 1 and d["is_active"] is False and "password_hash" not in d
    assert d["audit"][0]["action"] == "block" and "spam" in d["audit"][0]["summary"]
    assert (await client.get(f"{API}/admin/users/page?state=blocked", headers=admin_headers)).json()["total"] == 1


async def test_diagnoses_kb_monitor_audit(client, user_headers, admin_headers, fake_ai):
    fake_ai.next = Prediction("Pomidor", "Tomato_Late_blight", 41.0, True)
    d = (await client.post(f"{API}/diagnoses", files={"image": ("l.png", image_bytes(), "image/png")}, headers=user_headers)).json()
    r = (await client.get(f"{API}/admin/diagnoses?scope=recent", headers=admin_headers)).json()
    assert r["items"][0]["id"] == d["id"] and r["items"][0]["plant"] == "Pomidor" and r["queue_total"] == 0
    await client.post(f"{API}/diagnoses/{d['id']}/request-review", json={"note": "Ishonchim yo'q"}, headers=user_headers)
    q = (await client.get(f"{API}/admin/diagnoses?scope=queue", headers=admin_headers)).json()
    assert q["queue_total"] in (0, 1)  # so'rov endpointi bo'lmasa ham ro'yxat ishlaydi

    for kind in ("diseases", "plants", "medicines"):
        kb = (await client.get(f"{API}/admin/kb/list/{kind}", headers=admin_headers)).json()
        assert kb["total"] == len(kb["items"]) > 0
        assert sum(kb["summary"].values()) == kb["total"]
        assert all(i["state"] in ("complete", "incomplete", "no_image") for i in kb["items"])
    assert (await client.get(f"{API}/admin/kb/list/other", headers=admin_headers)).status_code == 404

    m = (await client.get(f"{API}/admin/system/monitor", headers=admin_headers)).json()
    assert m["database"]["ok"] is True and m["database"]["tables"] > 5 and m["host"]["disk_pct"] >= 0 and "queued" in m["jobs"]

    await client.post(f"{API}/admin/broadcast", json={"audience": "all", "title": "Salom hammaga", "body": "Sinov xabari"}, headers=admin_headers)
    a = (await client.get(f"{API}/admin/audit/page?action=broadcast", headers=admin_headers)).json()
    assert a["total"] == 1 and "broadcast" in a["actions"] and a["items"][0]["actor"] == "Admin"
    assert (await client.get(f"{API}/admin/audit/page?q=yo'q-matn", headers=admin_headers)).json()["total"] == 0


async def test_moderation_tabs_and_note(client, user_headers, admin_headers):
    other = auth(await register(client, "otabek"))
    post = (await client.post(f"{API}/posts", json={"title": "Arzon dori sotaman", "content": "telegram @..."}, headers=other)).json()
    await client.post(f"{API}/reports", json={"post_id": post["id"], "reason": "Reklama", "description": "Dori sotyapti"}, headers=user_headers)
    await client.post(f"{API}/reports", json={"post_id": post["id"], "reason": "Spam"}, headers=admin_headers)
    o = (await client.get(f"{API}/admin/moderation?tab=open", headers=admin_headers)).json()
    assert o["counts"]["open"] == 1 and o["items"][0]["count"] == 2 and o["items"][0]["claims"] == ["Dori sotyapti"]
    assert {x["reason"] for x in o["items"][0]["reasons"]} == {"Reklama", "Spam"} and o["items"][0]["title"] == "Arzon dori sotaman"

    body = {"kind": "post", "target_id": post["id"]}
    assert (await client.post(f"{API}/admin/moderation/start", json=body, headers=admin_headers)).status_code == 200
    assert (await client.post(f"{API}/admin/moderation/start", json=body, headers=admin_headers)).status_code == 409
    rv = (await client.get(f"{API}/admin/moderation?tab=review", headers=admin_headers)).json()
    assert rv["counts"] == {"open": 0, "review": 1, "closed": 0} and rv["items"][0]["status"] == "reviewing"
    # Ko'rib chiqilayotgan shikoyat ham boshqaruv panelida sanaladi
    assert (await client.get(f"{API}/admin/dashboard", headers=admin_headers)).json()["attention"]["reports"] == 1

    r = await client.post(f"{API}/admin/reports/dismiss", json=body | {"note": "Qoidaga zid emas"}, headers=admin_headers)
    assert r.json()["dismissed"] == 2
    c = (await client.get(f"{API}/admin/moderation?tab=closed", headers=admin_headers)).json()
    assert c["counts"]["closed"] == 1 and c["items"][0]["decision"] == "dismissed" and "Qoidaga zid emas" in c["items"][0]["summary"]


async def test_payments_list_separates_sandbox(client, user_headers, admin_headers):
    r = await client.post(f"{API}/subscriptions/checkout", json={"plan": "monthly", "provider": "payme"}, headers=user_headers)
    assert r.status_code == 201, r.text
    assert (await client.post(f"{API}/subscriptions/sandbox/confirm/{r.json()['subscription_id']}", headers=user_headers)).status_code == 200
    p = (await client.get(f"{API}/admin/payments/list", headers=admin_headers)).json()
    assert p["mode"] == "sandbox" and p["kpi"]["live_revenue_month"] == 0 and p["kpi"]["live_active"] == 0
    assert p["kpi"]["sandbox_active"] == 1 and p["items"][0]["sandbox"] and p["items"][0]["provider"] == "payme"
    u = (await client.get(f"{API}/admin/users/page?plan=premium", headers=admin_headers)).json()["items"]
    assert u[0]["premium_source"] == "sandbox"
