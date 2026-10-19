"""TZ A01: AI tahlil fon jarayoni — holatlar, dublikatsiz qayta yuborish, bekor qilish, xato, limit."""
import asyncio

from app.services.ai_client import Prediction
from tests.conftest import image_bytes

API = "/api/v1"


def files():
    return {"image": ("leaf.png", image_bytes(), "image/png")}


async def wait_done(client, h, job_id, timeout=5.0):
    for _ in range(int(timeout / 0.05)):
        j = (await client.get(f"{API}/diagnoses/jobs/{job_id}", headers=h)).json()
        if j["status"] in ("done", "failed", "cancelled"):
            return j
        await asyncio.sleep(0.05)
    raise AssertionError(f"tahlil tugamadi: {j}")


async def test_job_done_and_idempotent(client, user_headers, fake_ai):
    r = await client.post(f"{API}/diagnoses/jobs", files=files(), data={"client_key": "key-00000001"}, headers=user_headers)
    assert r.status_code == 202, r.text
    job = r.json()
    assert job["status"] in ("queued", "processing", "finishing", "done")
    # ikki marta bosish / tarmoq qayta yuborishi — o'sha ish qaytadi
    again = (await client.post(f"{API}/diagnoses/jobs", files=files(), data={"client_key": "key-00000001"}, headers=user_headers)).json()
    assert again["id"] == job["id"]
    done = await wait_done(client, user_headers, job["id"])
    assert done["status"] == "done" and done["diagnosis_id"]
    d = (await client.get(f"{API}/diagnoses/{done['diagnosis_id']}", headers=user_headers)).json()
    assert d["disease_name"].startswith("Fitoftoroz")
    assert len((await client.get(f"{API}/diagnoses", headers=user_headers)).json()) == 1  # dublikat tashxis yo'q
    notes = (await client.get(f"{API}/notifications", headers=user_headers)).json()
    assert [n["type"] for n in notes] == ["diagnosis_ready"]
    # tayyor ishni bekor qilib bo'lmaydi — natija qaytadi
    c = (await client.post(f"{API}/diagnoses/jobs/{job['id']}/cancel", headers=user_headers)).json()
    assert c["status"] == "done"


async def test_job_cancel_creates_nothing(client, user_headers, fake_ai):
    gate = asyncio.Event()
    orig = fake_ai.predict

    async def slow(*a, **kw):
        await gate.wait()
        return await orig(*a, **kw)

    fake_ai.predict = slow
    job = (await client.post(f"{API}/diagnoses/jobs", files=files(), data={"client_key": "key-cancel-1"}, headers=user_headers)).json()
    await asyncio.sleep(0.1)  # worker AI javobini kutmoqda
    assert (await client.get(f"{API}/diagnoses/jobs/{job['id']}", headers=user_headers)).json()["status"] == "processing"
    c = (await client.post(f"{API}/diagnoses/jobs/{job['id']}/cancel", headers=user_headers)).json()
    assert c["status"] == "cancelled"
    gate.set()
    await asyncio.sleep(0.2)
    j = (await client.get(f"{API}/diagnoses/jobs/{job['id']}", headers=user_headers)).json()
    assert j["status"] == "cancelled" and j["diagnosis_id"] is None
    assert (await client.get(f"{API}/diagnoses", headers=user_headers)).json() == []
    assert (await client.get(f"{API}/notifications", headers=user_headers)).json() == []
    sub = (await client.get(f"{API}/subscriptions/me", headers=user_headers)).json()
    assert sub["ai_used_today"] == 0  # bekor qilingan tahlil limitdan hisoblanmaydi


async def test_job_failed_invalid_image(client, user_headers, fake_ai):
    fake_ai.next = Prediction(None, None, 0, False, reason="Rasmda barg topilmadi")
    job = (await client.post(f"{API}/diagnoses/jobs", files=files(), data={"client_key": "key-bad-img1"}, headers=user_headers)).json()
    j = await wait_done(client, user_headers, job["id"])
    assert j["status"] == "failed" and j["error_code"] == 422 and j["error"] == "Rasmda barg topilmadi"


async def test_job_validation_and_access(client, user_headers, fake_ai):
    bad = await client.post(f"{API}/diagnoses/jobs", files={"image": ("x.png", b"not an image", "image/png")},
                            data={"client_key": "key-notimg1"}, headers=user_headers)
    assert bad.status_code == 415
    short = await client.post(f"{API}/diagnoses/jobs", files=files(), data={"client_key": "k"}, headers=user_headers)
    assert short.status_code == 422
    from tests.conftest import auth, register

    other = auth(await register(client, "boshqa"))
    job = (await client.post(f"{API}/diagnoses/jobs", files=files(), data={"client_key": "key-owner-1"}, headers=user_headers)).json()
    assert (await client.get(f"{API}/diagnoses/jobs/{job['id']}", headers=other)).status_code == 404
    assert (await client.post(f"{API}/diagnoses/jobs/{job['id']}/cancel", headers=other)).status_code == 404
    await wait_done(client, user_headers, job["id"])
