"""0.8.14: S04 reja farqi, S08 fikr sababi, S26 takrorlashni tahrirlash, S24 kontaktni kod bilan o'zgartirish, chat shikoyati."""
from datetime import date, timedelta

from tests.conftest import auth, image_bytes, register

API = "/api/v1"


async def me(client, h):
    return (await client.get(f"{API}/users/me", headers=h)).json()


async def test_feedback_reason_and_plan_diff(client, user_headers, fake_ai):
    d = (await client.post(f"{API}/diagnoses", files={"image": ("l.png", image_bytes(), "image/png")}, headers=user_headers)).json()
    r = (await client.post(f"{API}/diagnoses/{d['id']}/feedback", json={"correct": False, "reason": "  Bu bakterial dog'  "}, headers=user_headers)).json()
    assert r["user_feedback"] is False and r["feedback_reason"] == "Bu bakterial dog'"
    r = (await client.post(f"{API}/diagnoses/{d['id']}/feedback", json={"correct": True, "reason": "x"}, headers=user_headers)).json()
    assert r["feedback_reason"] is None  # sabab faqat "Yo'q" uchun
    plan = (await client.get(f"{API}/diagnoses/{d['id']}/care-plan", headers=user_headers)).json()
    assert plan["replaces"] == []
    await client.post(f"{API}/diagnoses/{d['id']}/care-plan", json={}, headers=user_headers)
    plan = (await client.get(f"{API}/diagnoses/{d['id']}/care-plan", headers=user_headers)).json()
    assert len(plan["replaces"]) == len(plan["tasks"]) > 0 and plan["replaces"][0]["title"]


async def test_reminder_repeat_change(client, user_headers):
    start = date.today() + timedelta(days=1)
    body = {"title": "Sug'orish", "reminder_date": start.isoformat(), "repeat": "daily", "repeat_until": (start + timedelta(days=4)).isoformat()}
    first = (await client.post(f"{API}/reminders", json=body, headers=user_headers)).json()
    series = [r for r in (await client.get(f"{API}/reminders", headers=user_headers)).json() if r["series_id"] == first["series_id"]]
    assert len(series) == 5
    # ikkinchisini bajarilgan qilamiz, uchinchisidan boshlab haftalikka o'tkazamiz
    await client.put(f"{API}/reminders/{series[1]['id']}/complete", headers=user_headers)
    third = series[2]
    r = await client.put(f"{API}/reminders/{third['id']}", json={"repeat": "weekly", "repeat_until": (start + timedelta(days=20)).isoformat()}, headers=user_headers)
    assert r.status_code == 200, r.text
    new = r.json()
    assert new["repeat"] == "weekly" and new["series_id"] != first["series_id"]
    allr = (await client.get(f"{API}/reminders", headers=user_headers)).json()
    old_left = [x for x in allr if x["series_id"] == first["series_id"]]
    assert {x["reminder_date"] for x in old_left} == {series[0]["reminder_date"], series[1]["reminder_date"]}  # o'tgan va bajarilgan qoladi
    new_s = sorted(x["reminder_date"] for x in allr if x["series_id"] == new["series_id"])
    assert new_s == [(start + timedelta(days=d)).isoformat() for d in (2, 9, 16)]
    # takrorlashni o'chirish — bitta vazifa
    single = (await client.put(f"{API}/reminders/{new['id']}", json={"repeat": None}, headers=user_headers)).json()
    assert single["series_id"] is None and single["repeat"] is None
    assert not [x for x in (await client.get(f"{API}/reminders", headers=user_headers)).json() if x["series_id"] == new["series_id"]]
    bad = await client.put(f"{API}/reminders/{new['id']}", json={"repeat": "daily"}, headers=user_headers)
    assert bad.status_code == 422  # tugash sanasi yo'q


async def test_contact_change_with_code(client, user_headers):
    # kanal bor (sinov rejimi) — to'g'ridan-to'g'ri o'zgartirib bo'lmaydi
    r = await client.put(f"{API}/users/me", json={"phone": "+998901234567"}, headers=user_headers)
    assert r.status_code == 409
    ch = (await client.post(f"{API}/auth/contact", json={"channel": "sms", "destination": "+998 90 123-45-67"}, headers=user_headers)).json()
    assert ch["purpose"] == "contact" and ch["dev_code"]
    # ommaviy verify kontakt kodini qabul qilmaydi (sessiya/recovery berilmaydi)
    assert (await client.post(f"{API}/auth/challenges/{ch['challenge_id']}/verify", json={"code": ch["dev_code"]})).status_code == 410
    wrong = await client.post(f"{API}/auth/contact/{ch['challenge_id']}/verify", json={"code": "000000" if ch["dev_code"] != "000000" else "111111"}, headers=user_headers)
    assert wrong.status_code == 400 and wrong.headers["X-Attempts-Left"] == "4"
    other = auth(await register(client, "boshqasi"))
    assert (await client.post(f"{API}/auth/contact/{ch['challenge_id']}/verify", json={"code": ch["dev_code"]}, headers=other)).status_code == 410
    ok = await client.post(f"{API}/auth/contact/{ch['challenge_id']}/verify", json={"code": ch["dev_code"]}, headers=user_headers)
    assert ok.status_code == 200 and ok.json()["phone"] == "+998901234567"
    # band manzil
    taken = await client.post(f"{API}/auth/contact", json={"channel": "sms", "destination": "+998901234567"}, headers=other)
    assert taken.status_code == 409
    # olib tashlash — kodsiz mumkin
    assert (await client.put(f"{API}/users/me", json={"phone": None}, headers=user_headers)).json()["phone"] is None


async def test_report_chat_message(client, user_headers, admin_headers):
    other = auth(await register(client, "yozuvchi"))
    oid = (await me(client, other))["id"]
    conv = (await client.post(f"{API}/conversations", json={"user_id": oid}, headers=user_headers)).json()
    bad_msg = (await client.post(f"{API}/conversations/{conv['id']}/messages", json={"content": "spam havola"}, headers=other)).json()
    mine = (await client.post(f"{API}/conversations/{conv['id']}/messages", json={"content": "salom"}, headers=user_headers)).json()
    assert (await client.post(f"{API}/reports", json={"message_id": mine["id"], "reason": "Spam"}, headers=user_headers)).status_code == 404
    r = await client.post(f"{API}/reports", json={"message_id": bad_msg["id"], "reason": "Spam yoki reklama"}, headers=user_headers)
    assert r.status_code == 201 and r.json()["message_id"] == bad_msg["id"]
    again = await client.post(f"{API}/reports", json={"message_id": bad_msg["id"], "reason": "Spam yoki reklama"}, headers=user_headers)
    assert again.json()["id"] == r.json()["id"]  # dublikat yo'q
    third = auth(await register(client, "tashqi"))
    assert (await client.post(f"{API}/reports", json={"message_id": bad_msg["id"], "reason": "x"}, headers=third)).status_code == 404
    groups = (await client.get(f"{API}/admin/reports", headers=admin_headers)).json()
    g = [x for x in groups if x["kind"] == "message"][0]
    assert g["text"] == "spam havola" and g["author_id"] == oid
    h = await client.post(f"{API}/admin/reports/hide", json={"kind": "message", "target_id": bad_msg["id"]}, headers=admin_headers)
    assert h.status_code == 200
    msgs = (await client.get(f"{API}/conversations/{conv['id']}/messages", headers=user_headers)).json()
    assert [m["content"] for m in msgs] == ["salom"]
    assert any(n["title"] == "Chatdagi xabaringiz olib tashlandi" for n in (await client.get(f"{API}/notifications", headers=other)).json())
