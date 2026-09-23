"""Payme Merchant API va Click SHOP API — provayder serveri yuboradigan so'rovlar simulyatsiyasi."""
import base64
import hashlib
import time

from app.core.config import settings

PAYME_AUTH = {"Authorization": "Basic " + base64.b64encode(f"Paycom:{settings.PAYME_SECRET_KEY}".encode()).decode()}


async def checkout(client, headers, provider, plan="monthly"):
    r = await client.post("/api/v1/subscriptions/checkout", json={"plan": plan, "provider": provider}, headers=headers)
    return r.json()["subscription_id"]


async def rpc(client, method, params, auth=PAYME_AUTH, rid=1):
    r = await client.post("/api/v1/payments/payme", json={"jsonrpc": "2.0", "id": rid, "method": method, "params": params}, headers=auth)
    assert r.status_code == 200
    return r.json()


async def test_payme_full_cycle(client, user_headers):
    sub = await checkout(client, user_headers, "payme")
    acc = {"order_id": sub}

    bad = await rpc(client, "CheckPerformTransaction", {"amount": 2500000, "account": acc}, auth={"Authorization": "Basic eDp5"})
    assert bad["error"]["code"] == -32504
    assert (await rpc(client, "Nope", {}))["error"]["code"] == -32601
    assert (await rpc(client, "CheckPerformTransaction", {"amount": 100, "account": acc}))["error"]["code"] == -31001
    assert (await rpc(client, "CheckPerformTransaction", {"amount": 2500000, "account": {"order_id": "x"}}))["error"]["code"] == -31050
    assert (await rpc(client, "CheckPerformTransaction", {"amount": 2500000, "account": acc}))["result"] == {"allow": True}

    t = int(time.time() * 1000)
    created = (await rpc(client, "CreateTransaction", {"id": "pm-1", "time": t, "amount": 2500000, "account": acc}))["result"]
    assert created["state"] == 1
    again = (await rpc(client, "CreateTransaction", {"id": "pm-1", "time": t, "amount": 2500000, "account": acc}))["result"]
    assert again["transaction"] == created["transaction"]  # idempotent
    other = await rpc(client, "CreateTransaction", {"id": "pm-2", "time": t, "amount": 2500000, "account": acc})
    assert other["error"]["code"] == -31051  # buyurtma band

    performed = (await rpc(client, "PerformTransaction", {"id": "pm-1"}))["result"]
    assert performed["state"] == 2 and performed["perform_time"] > 0
    assert (await rpc(client, "PerformTransaction", {"id": "pm-1"}))["result"]["perform_time"] == performed["perform_time"]
    me = (await client.get("/api/v1/subscriptions/me", headers=user_headers)).json()
    assert me["is_premium"] is True

    checked = (await rpc(client, "CheckTransaction", {"id": "pm-1"}))["result"]
    assert checked["state"] == 2 and checked["cancel_time"] == 0
    st = (await rpc(client, "GetStatement", {"from": t - 1000, "to": t + 1000}))["result"]["transactions"]
    assert st[0]["id"] == "pm-1" and st[0]["amount"] == 2500000 and st[0]["account"]["order_id"] == sub
    assert (await rpc(client, "CheckTransaction", {"id": "nope"}))["error"]["code"] == -31003

    # Qaytarish (refund): -2 holat, Premium olib tashlanadi
    cancelled = (await rpc(client, "CancelTransaction", {"id": "pm-1", "reason": 5}))["result"]
    assert cancelled["state"] == -2
    assert (await client.get("/api/v1/subscriptions/me", headers=user_headers)).json()["is_premium"] is False
    assert (await rpc(client, "PerformTransaction", {"id": "pm-1"}))["error"]["code"] == -31008


async def test_payme_cancel_before_perform_and_timeout(client, user_headers, monkeypatch):
    sub = await checkout(client, user_headers, "payme")
    t = int(time.time() * 1000)
    await rpc(client, "CreateTransaction", {"id": "pm-3", "time": t, "amount": 2500000, "account": {"order_id": sub}})
    res = (await rpc(client, "CancelTransaction", {"id": "pm-3", "reason": 3}))["result"]
    assert res["state"] == -1
    assert (await rpc(client, "CheckTransaction", {"id": "pm-3"}))["result"]["reason"] == 3

    sub2 = await checkout(client, user_headers, "payme")
    await rpc(client, "CreateTransaction", {"id": "pm-4", "time": t, "amount": 2500000, "account": {"order_id": sub2}})
    monkeypatch.setattr(settings, "PAYME_TIMEOUT_MS", -1)
    assert (await rpc(client, "PerformTransaction", {"id": "pm-4"}))["error"]["code"] == -31008
    assert (await rpc(client, "CheckTransaction", {"id": "pm-4"}))["result"]["reason"] == 4


def click_form(sub_id, trans_id, action, amount="25000", prepare_id=None, error="0"):
    f = {"click_trans_id": str(trans_id), "service_id": settings.CLICK_SERVICE_ID or "1", "click_paydoc_id": "77",
         "merchant_trans_id": sub_id, "amount": amount, "action": str(action), "error": error,
         "error_note": "ok", "sign_time": "2026-09-23 10:00:00"}
    if prepare_id is not None:
        f["merchant_prepare_id"] = str(prepare_id)
    parts = [f["click_trans_id"], f["service_id"], settings.CLICK_SECRET_KEY, f["merchant_trans_id"]]
    if prepare_id is not None:
        parts.append(f["merchant_prepare_id"])
    parts += [f["amount"], f["action"], f["sign_time"]]
    f["sign_string"] = hashlib.md5("".join(parts).encode()).hexdigest()
    return f


async def test_click_prepare_complete(client, user_headers):
    sub = await checkout(client, user_headers, "click")
    bad = click_form(sub, 555, 0)
    bad["sign_string"] = "0" * 32
    assert (await client.post("/api/v1/payments/click/prepare", data=bad)).json()["error"] == -1
    assert (await client.post("/api/v1/payments/click/prepare", data=click_form(sub, 555, 0, amount="10"))).json()["error"] == -2
    assert (await client.post("/api/v1/payments/click/prepare", data=click_form("x", 555, 0))).json()["error"] == -5

    prep = (await client.post("/api/v1/payments/click/prepare", data=click_form(sub, 555, 0))).json()
    assert prep["error"] == 0 and prep["merchant_prepare_id"] == 555
    assert (await client.post("/api/v1/payments/click/complete", data=click_form(sub, 999, 1, prepare_id=999))).json()["error"] == -6

    done = (await client.post("/api/v1/payments/click/complete", data=click_form(sub, 555, 1, prepare_id=555))).json()
    assert done["error"] == 0 and done["merchant_confirm_id"] == 555
    assert (await client.get("/api/v1/subscriptions/me", headers=user_headers)).json()["is_premium"] is True
    again = (await client.post("/api/v1/payments/click/complete", data=click_form(sub, 555, 1, prepare_id=555))).json()
    assert again["error"] == -4


async def test_click_failed_payment(client, user_headers):
    sub = await checkout(client, user_headers, "click")
    await client.post("/api/v1/payments/click/prepare", data=click_form(sub, 777, 0))
    res = (await client.post("/api/v1/payments/click/complete", data=click_form(sub, 777, 1, prepare_id=777, error="-5017"))).json()
    assert res["error"] == -9
    assert (await client.get("/api/v1/subscriptions/me", headers=user_headers)).json()["is_premium"] is False


async def test_payment_urls_live(client, user_headers, monkeypatch):
    monkeypatch.setattr(settings, "PAYMENT_MODE", "live")
    monkeypatch.setattr(settings, "PAYME_MERCHANT_ID", "m123")
    co = (await client.post("/api/v1/subscriptions/checkout", json={"plan": "monthly", "provider": "payme"}, headers=user_headers)).json()
    raw = base64.b64decode(co["payment_url"].rsplit("/", 1)[1]).decode()
    assert co["sandbox"] is False and f"ac.order_id={co['subscription_id']}" in raw and "a=2500000" in raw
    co = (await client.post("/api/v1/subscriptions/checkout", json={"plan": "yearly", "provider": "click"}, headers=user_headers)).json()
    assert co["payment_url"].startswith("https://my.click.uz/services/pay?") and "amount=250000" in co["payment_url"]


async def test_seed_is_idempotent_and_covers_model_labels(client):
    import importlib.util
    from pathlib import Path

    from sqlalchemy import func, select

    from app.core.database import SessionLocal
    from app.models import Disease
    from app.seed import seed_catalog

    async with SessionLocal() as db:
        before = await db.scalar(select(func.count()).select_from(Disease))
        await seed_catalog(db)
        await db.commit()
        assert await db.scalar(select(func.count()).select_from(Disease)) == before
        kb = set((await db.scalars(select(Disease.ai_label))).all())
    spec = importlib.util.spec_from_file_location("labels", Path(__file__).resolve().parents[2] / "ai-service/app/models/labels.py")
    labels = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(labels)
    assert [lbl for lbl in labels.MODEL_LABELS if not lbl.endswith("healthy") and lbl not in kb] == []
