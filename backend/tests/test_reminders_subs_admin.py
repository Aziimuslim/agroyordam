import hashlib
import hmac
import json
from datetime import date, timedelta

from app.core.config import settings
from app.core.database import SessionLocal
from app.core.security import utcnow
from app.models import User
from app.tasks.scheduler import expire_subscriptions, send_due_reminders


async def test_reminders_crud(client, user_headers):
    crop = (await client.post("/api/v1/crops", json={"name": "Qalampir"}, headers=user_headers)).json()
    body = {"title": "Sug'orish", "reminder_type": "watering", "reminder_date": str(date.today()), "crop_id": crop["id"]}
    r = (await client.post("/api/v1/reminders", json=body, headers=user_headers)).json()
    assert r["crop_name"] == "Qalampir"
    assert (await client.post("/api/v1/reminders", json={**body, "reminder_type": "bad"}, headers=user_headers)).status_code == 422
    r2 = (await client.put(f"/api/v1/reminders/{r['id']}", json={"title": "Chuqur sug'orish"}, headers=user_headers)).json()
    assert r2["title"] == "Chuqur sug'orish"
    done = (await client.put(f"/api/v1/reminders/{r['id']}/complete", headers=user_headers)).json()
    assert done["is_completed"] is True
    assert len((await client.get("/api/v1/reminders", params={"completed": True}, headers=user_headers)).json()) == 1
    assert len((await client.get("/api/v1/reminders", params={"reminder_type": "watering", "crop_id": crop["id"],
                                                               "date_from": str(date.today()), "date_to": str(date.today())},
                                  headers=user_headers)).json()) == 1
    assert (await client.delete(f"/api/v1/reminders/{r['id']}", headers=user_headers)).status_code == 204
    assert (await client.put(f"/api/v1/reminders/{r['id']}", json={}, headers=user_headers)).status_code == 404


async def test_scheduler_sends_due_reminders_once(client, user_headers):
    await client.post("/api/v1/reminders", json={"title": "Dori sepish", "reminder_type": "treatment",
                                                 "reminder_date": str(date.today() - timedelta(days=1))}, headers=user_headers)
    assert await send_due_reminders() == 1
    assert await send_due_reminders() == 0
    notes = (await client.get("/api/v1/notifications", params={"unread": True}, headers=user_headers)).json()
    assert notes[0]["type"] == "reminder"
    assert (await client.put(f"/api/v1/notifications/{notes[0]['id']}/read", headers=user_headers)).json()["is_read"]
    assert (await client.put("/api/v1/notifications/read-all", headers=user_headers)).status_code == 204


def signed(provider: str, payload: dict) -> tuple[bytes, dict]:
    raw = json.dumps(payload).encode()
    secret = {"payme": settings.PAYME_SECRET_KEY, "click": settings.CLICK_SECRET_KEY, "uzum": settings.UZUM_SECRET_KEY}[provider]
    return raw, {"X-Signature": hmac.new(secret.encode(), raw, hashlib.sha256).hexdigest(), "Content-Type": "application/json"}


async def test_subscription_webhook_flow(client, user_headers):
    plans = (await client.get("/api/v1/subscriptions/plans")).json()
    assert {p["code"] for p in plans} == {"monthly", "yearly", "lifetime"}
    co = (await client.post("/api/v1/subscriptions/checkout", json={"plan": "monthly", "provider": "uzum"}, headers=user_headers)).json()
    assert co["sandbox"] and "subscription_id" in co["payment_url"]

    payload = {"subscription_id": co["subscription_id"], "transaction_id": "T-1", "status": "paid", "amount": "25000"}
    raw, headers = signed("uzum", payload)
    bad = await client.post("/api/v1/subscriptions/webhook/uzum", content=raw, headers={**headers, "X-Signature": "00"})
    assert bad.status_code == 401
    other = await client.post("/api/v1/subscriptions/webhook/payme", content=raw, headers=headers)
    assert other.status_code == 404  # Payme/Click o'z protokoli orqali
    raw_amt, h_amt = signed("uzum", {**payload, "amount": "1"})
    assert (await client.post("/api/v1/subscriptions/webhook/uzum", content=raw_amt, headers=h_amt)).status_code == 400
    ok = await client.post("/api/v1/subscriptions/webhook/uzum", content=raw, headers=headers)
    assert ok.status_code == 200 and ok.json()["status"] == "active"
    again = await client.post("/api/v1/subscriptions/webhook/uzum", content=raw, headers=headers)
    assert again.json()["status"] == "active"  # idempotent

    me = (await client.get("/api/v1/subscriptions/me", headers=user_headers)).json()
    assert me["is_premium"] and me["ai_daily_limit"] is None and me["crop_limit"] is None
    assert len((await client.get("/api/v1/subscriptions/history", headers=user_headers)).json()) == 1
    # premium: ekin limiti yo'q
    for i in range(5):
        assert (await client.post("/api/v1/crops", json={"name": f"E{i}"}, headers=user_headers)).status_code == 201
    cancelled = (await client.post("/api/v1/subscriptions/cancel", headers=user_headers)).json()
    assert cancelled["auto_renew"] is False
    assert (await client.post("/api/v1/subscriptions/cancel", headers=user_headers)).status_code == 404


async def test_sandbox_confirm_and_expiry(client, user_headers):
    co = (await client.post("/api/v1/subscriptions/checkout", json={"plan": "yearly", "provider": "payme"}, headers=user_headers)).json()
    sub = (await client.post(f"/api/v1/subscriptions/sandbox/confirm/{co['subscription_id']}", headers=user_headers)).json()
    assert sub["status"] == "active" and sub["external_txn_id"].startswith("sandbox-")
    async with SessionLocal() as db:
        from sqlalchemy import select

        u = await db.scalar(select(User).where(User.username == "farmer"))
        u.premium_until = utcnow() - timedelta(days=1)
        from app.models import Subscription

        s = await db.get(Subscription, __import__("uuid").UUID(co["subscription_id"]))
        s.expires_at = utcnow() - timedelta(days=1)
        await db.commit()
    assert await expire_subscriptions() == 1
    me = (await client.get("/api/v1/subscriptions/me", headers=user_headers)).json()
    assert me["is_premium"] is False


async def test_failed_payment(client, user_headers):
    co = (await client.post("/api/v1/subscriptions/checkout", json={"plan": "monthly", "provider": "uzum"}, headers=user_headers)).json()
    raw, headers = signed("uzum", {"subscription_id": co["subscription_id"], "transaction_id": "U-9", "status": "failed", "amount": "25000"})
    assert (await client.post("/api/v1/subscriptions/webhook/uzum", content=raw, headers=headers)).json()["status"] == "cancelled"
    raw, headers = signed("uzum", {"bad": 1})
    assert (await client.post("/api/v1/subscriptions/webhook/uzum", content=raw, headers=headers)).status_code == 400
    assert (await client.post("/api/v1/subscriptions/webhook/paypal", content=raw, headers=headers)).status_code == 404


async def test_admin_panel_endpoints(client, user_headers, admin_headers):
    assert (await client.get("/api/v1/admin/stats/platform", headers=user_headers)).status_code == 403
    stats = (await client.get("/api/v1/admin/stats/platform", headers=admin_headers)).json()
    assert stats["users_total"] == 2
    assert "top_diseases" in (await client.get("/api/v1/admin/stats/ai", headers=admin_headers)).json()
    assert (await client.get("/api/v1/admin/stats/revenue", headers=admin_headers)).json()["currency"] == "UZS"
    users = (await client.get("/api/v1/admin/users", params={"q": "farmer"}, headers=admin_headers)).json()
    assert len(users) == 1
    blocked = (await client.put(f"/api/v1/admin/users/{users[0]['id']}/block", headers=admin_headers)).json()
    assert blocked["is_active"] is False
    assert (await client.get("/api/v1/users/me", headers=user_headers)).status_code == 401
    r = await client.post("/api/v1/auth/login", json={"login": "farmer", "password": "Secret123!"})
    assert r.status_code == 403
    unblocked = (await client.put(f"/api/v1/admin/users/{users[0]['id']}/block", params={"blocked": False}, headers=admin_headers)).json()
    assert unblocked["is_active"] is True


async def test_uploads(client, user_headers):
    from tests.conftest import image_bytes

    r = await client.post("/api/v1/uploads", params={"folder": "posts"}, files={"file": ("p.jpg", image_bytes("JPEG"), "image/jpeg")}, headers=user_headers)
    assert r.status_code == 201 and r.json()["url"].endswith(".jpg")
    served = await client.get(r.json()["url"])
    assert served.status_code == 200
