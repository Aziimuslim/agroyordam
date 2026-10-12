"""Profil: dehqon xo'jaligi va agronom ma'lumotlari, kim nimani ko'radi."""
from tests.conftest import auth, register
from tests.test_experts import API, make_expert, me


async def test_farmer_profile_fields(client, user_headers):
    body = {
        "region": "Qoraqalpog'iston", "district": "Amudaryo tumani", "address": "  Navbahor MFY  ",
        "about": "Paxta va bug'doy ekaman", "experience_years": 12,
        "farm_type": "fermer", "farm_area": 3.5, "main_crops": ["Paxta", "Bug'doy", "Paxta"], "irrigation": "tomchi",
        "education": "TDAU", "skills": ["Paxta"],  # agronom bo'lmagani uchun e'tiborsiz qoladi
    }
    r = await client.put(f"{API}/users/me", json=body, headers=user_headers)
    assert r.status_code == 200, r.text
    m = r.json()
    assert m["district"] == "Amudaryo tumani" and m["address"] == "Navbahor MFY"
    assert m["main_crops"] == ["Paxta", "Bug'doy"] and m["farm_area"] == 3.5 and m["irrigation"] == "tomchi"
    assert m["education"] is None and m["skills"] is None

    # Bo'sh qiymat — tozalash; ismni bo'sh qilib bo'lmaydi
    r = await client.put(f"{API}/users/me", json={"address": "", "main_crops": [], "full_name": "   "}, headers=user_headers)
    assert r.status_code == 200
    m = r.json()
    assert m["address"] is None and m["main_crops"] is None and m["full_name"] == "Test Fermer"

    for bad in ({"farm_type": "zavod"}, {"irrigation": "x"}, {"farm_area": -1}, {"experience_years": 200},
                {"main_crops": ["a" * 41]}):
        assert (await client.put(f"{API}/users/me", json=bad, headers=user_headers)).status_code == 422, bad


async def test_expert_public_profile_and_farm_brief(client, user_headers, admin_headers):
    eh = await make_expert(client, admin_headers)
    r = await client.put(f"{API}/users/me", json={
        "about": "15 yil bog'larda ishlaganman", "experience_years": 15, "education": "TDAU, agronomiya",
        "skills": ["Uzum", "Olma"], "specialization": "Mevali bog'lar", "district": "Urgut tumani",
    }, headers=eh)
    assert r.status_code == 200 and r.json()["skills"] == ["Uzum", "Olma"]
    eid = (await me(client, eh))["id"]

    p = (await client.get(f"{API}/experts/{eid}", headers=user_headers)).json()
    assert p["education"] == "TDAU, agronomiya" and p["experience_years"] == 15 and p["district"] == "Urgut tumani"
    assert (await client.get(f"{API}/experts/{(await me(client, user_headers))['id']}", headers=user_headers)).status_code == 404
    # Boshqa yo'llar {expert_id} ga tushib qolmaydi
    assert (await client.get(f"{API}/experts/queue", headers=eh)).status_code == 200

    await client.put(f"{API}/users/me", json={"farm_type": "tomorqa", "farm_area": 0.08, "main_crops": ["Pomidor"],
                                               "district": "Urgut tumani"}, headers=user_headers)
    q = (await client.post(f"{API}/questions", json={"title": "Pomidor barglari sarg'aymoqda"}, headers=user_headers)).json()
    # Dehqon o'z savolida xo'jalik ma'lumotini qaytarib olmaydi, agronom ko'radi
    assert (await client.get(f"{API}/questions/{q['id']}", headers=user_headers)).json()["author_farm"] is None
    farm = (await client.get(f"{API}/questions/{q['id']}", headers=eh)).json()["author_farm"]
    assert farm["farm_type"] == "tomorqa" and farm["main_crops"] == ["Pomidor"] and farm["district"] == "Urgut tumani"
    # Ro'yxatlarda ham, boshqa dehqonga ham ko'rinmaydi
    other = auth(await register(client, "qoshni"))
    assert (await client.get(f"{API}/users/{(await me(client, user_headers))['id']}", headers=other)).json().get("farm_type") is None


async def test_application_fills_expert_profile(client, user_headers, admin_headers):
    body = {"specialization": "Sabzavotlar", "experience_years": 7, "about": "Issiqxona bo'yicha mutaxassis"}
    await client.post(f"{API}/experts/applications", json=body, headers=user_headers)
    app_id = (await client.get(f"{API}/admin/expert-applications", headers=admin_headers)).json()[0]["id"]
    await client.post(f"{API}/admin/expert-applications/{app_id}/approve", headers=admin_headers)
    m = await me(client, user_headers)
    assert m["about"] == "Issiqxona bo'yicha mutaxassis" and m["experience_years"] == 7
