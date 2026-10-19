"""TZ S33–S36: bir martalik kod, ro'yxatdan o'tish tasdig'i, parolni tiklash."""
from datetime import timedelta
import uuid

from app.core.config import settings
from app.core.database import SessionLocal
from app.core.security import utcnow
from app.models import AuthChallenge, User

API = "/api/v1"
REG = {"full_name": "Yangi Fermer", "password": "Parol1234", "accept_terms": True}


async def challenge(client, **body):
    return await client.post(f"{API}/auth/challenges", json=body)


async def test_options_and_register_by_code(client):
    opts = (await client.get(f"{API}/auth/options")).json()
    assert opts["channels"] == ["sms", "email"] and opts["dev_codes"] and opts["otp_ttl"] == 300

    r = await challenge(client, purpose="register", channel="sms", destination="+998 90 111-22-33", signup=REG)
    assert r.status_code == 201, r.text
    ch = r.json()
    assert ch["destination_masked"].startswith("+998") and "111" not in ch["destination_masked"]
    assert ch["attempts_left"] == 5 and ch["resend_in"] > 50
    # kod tasdiqlanmaguncha hisob yaratilmaydi
    async with SessionLocal() as db:
        from sqlalchemy import select

        assert await db.scalar(select(User).where(User.phone == "+998901112233")) is None

    wrong = "000000" if ch["dev_code"] != "000000" else "111111"
    bad = await client.post(f"{API}/auth/challenges/{ch['challenge_id']}/verify", json={"code": wrong})
    assert bad.status_code == 400 and bad.headers["x-attempts-left"] == "4"
    ok = await client.post(f"{API}/auth/challenges/{ch['challenge_id']}/verify", json={"code": ch["dev_code"]})
    assert ok.status_code == 200 and ok.json()["result"] == "session"
    me = (await client.get(f"{API}/users/me", headers={"Authorization": f"Bearer {ok.json()['access_token']}"})).json()
    assert me["phone"] == "+998901112233" and me["full_name"] == "Yangi Fermer" and len(me["username"]) >= 3
    # kod bir marta ishlaydi
    again = await client.post(f"{API}/auth/challenges/{ch['challenge_id']}/verify", json={"code": ch["dev_code"]})
    assert again.status_code == 410
    # endi shu raqam band
    dup = await challenge(client, purpose="register", channel="sms", destination="+998901112233", signup=REG)
    assert dup.status_code == 409


async def test_register_rules(client, user_headers):
    no_terms = await challenge(client, purpose="register", channel="email", destination="a@b.uz", signup={**REG, "accept_terms": False})
    assert no_terms.status_code == 422
    bad_phone = await challenge(client, purpose="register", channel="sms", destination="12345", signup=REG)
    assert bad_phone.status_code == 422
    taken = await challenge(client, purpose="register", channel="email", destination="FARMER@test.uz", signup=REG)
    assert taken.status_code == 409
    # to'g'ridan-to'g'ri ro'yxatdan o'tish username'siz ham ishlaydi va rozilik saqlanadi
    r = await client.post(f"{API}/auth/register", json={"full_name": "Ali Valiyev", "email": "ali@t.uz", "password": "Parol1234", "accept_terms": True})
    assert r.status_code == 201, r.text
    async with SessionLocal() as db:
        from sqlalchemy import select

        u = await db.scalar(select(User).where(User.email == "ali@t.uz"))
        assert u.username.startswith("ali") and u.terms_version == settings.TERMS_VERSION and u.terms_accepted_at


async def test_recovery_flow_and_token_scope(client, user_headers):
    unknown = await challenge(client, purpose="recovery", channel="email", destination="yoq@test.uz")
    known = await challenge(client, purpose="recovery", channel="email", destination="farmer@test.uz")
    assert unknown.status_code == known.status_code == 201
    assert set(unknown.json()) == set(known.json())  # hisob borligi oshkor qilinmaydi
    u = unknown.json()
    assert (await client.post(f"{API}/auth/challenges/{u['challenge_id']}/verify", json={"code": u["dev_code"]})).status_code == 400

    k = known.json()
    v = (await client.post(f"{API}/auth/challenges/{k['challenge_id']}/verify", json={"code": k["dev_code"]})).json()
    assert v["result"] == "recovery" and v["access_token"] is None
    # recovery token login sessiyasi emas
    assert (await client.get(f"{API}/users/me", headers={"Authorization": f"Bearer {v['recovery_token']}"})).status_code == 401
    r = await client.post(f"{API}/auth/recovery/reset", json={"recovery_token": v["recovery_token"], "new_password": "Yangi12345"})
    assert r.status_code == 200
    assert (await client.post(f"{API}/auth/login", json={"login": "farmer", "password": "Secret123!"})).status_code == 401
    assert (await client.post(f"{API}/auth/login", json={"login": "farmer", "password": "Yangi12345"})).status_code == 200
    # bir martalik
    r2 = await client.post(f"{API}/auth/recovery/reset", json={"recovery_token": v["recovery_token"], "new_password": "Boshqa12345"})
    assert r2.status_code == 400


async def test_resend_expiry_and_attempts(client, user_headers):
    ch = (await challenge(client, purpose="login", channel="email", destination="farmer@test.uz")).json()
    cid = ch["challenge_id"]
    early = await client.post(f"{API}/auth/challenges/{cid}/resend")
    assert early.status_code == 429 and int(early.headers["retry-after"]) > 0
    async with SessionLocal() as db:
        c = await db.get(AuthChallenge, uuid.UUID(cid))
        c.resend_at = utcnow() - timedelta(seconds=1)
        await db.commit()
    new = (await client.post(f"{API}/auth/challenges/{cid}/resend")).json()
    if new["dev_code"] != ch["dev_code"]:  # eski kod yaroqsiz
        old = await client.post(f"{API}/auth/challenges/{cid}/verify", json={"code": ch["dev_code"]})
        assert old.status_code == 400
    # urinishlar tugaydi
    for _ in range(5):
        await client.post(f"{API}/auth/challenges/{cid}/verify", json={"code": "999999" if new["dev_code"] != "999999" else "888888"})
    locked = await client.post(f"{API}/auth/challenges/{cid}/verify", json={"code": new["dev_code"]})
    assert locked.status_code == 429

    ch2 = (await challenge(client, purpose="login", channel="email", destination="farmer@test.uz")).json()
    async with SessionLocal() as db:
        c = await db.get(AuthChallenge, uuid.UUID(ch2["challenge_id"]))
        c.expires_at = utcnow() - timedelta(seconds=1)
        await db.commit()
    exp = await client.post(f"{API}/auth/challenges/{ch2['challenge_id']}/verify", json={"code": ch2["dev_code"]})
    assert exp.status_code == 410

    ch3 = (await challenge(client, purpose="login", channel="email", destination="farmer@test.uz")).json()
    s = await client.post(f"{API}/auth/challenges/{ch3['challenge_id']}/verify", json={"code": ch3["dev_code"]})
    assert s.status_code == 200 and s.json()["result"] == "session" and s.json()["refresh_token"]


async def test_no_channel_in_production(client, monkeypatch):
    monkeypatch.setattr(settings, "OTP_DEV_CODES", False)
    assert (await client.get(f"{API}/auth/options")).json()["channels"] == []
    r = await challenge(client, purpose="recovery", channel="sms", destination="+998901112233")
    assert r.status_code == 503


async def test_login_rate_limit_has_retry_after(client, monkeypatch):
    monkeypatch.setattr(settings, "LOGIN_RATE_LIMIT_PER_MINUTE", 2)
    for _ in range(2):
        await client.post(f"{API}/auth/login", json={"login": "x", "password": "y"})
    r = await client.post(f"{API}/auth/login", json={"login": "x", "password": "y"})
    assert r.status_code == 429 and r.headers["retry-after"] == "60"


async def test_cors_exposes_otp_headers(client):
    r = await client.post(f"{API}/auth/challenges/{uuid.uuid4()}/verify", json={"code": "123456"}, headers={"Origin": "http://localhost:8080"})
    assert "x-attempts-left" in r.headers.get("access-control-expose-headers", "").lower()
