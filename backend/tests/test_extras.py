"""TZ A02 Saqlanganlar, A04 Kundalik, A07 Qidiruv, A08 Bloklash va shikoyat dublikati."""
from sqlalchemy import select

from app.core.database import SessionLocal
from app.models import Plant, User
from tests.conftest import auth, register

API = "/api/v1"


async def me(client, h):
    return (await client.get(f"{API}/users/me", headers=h)).json()


async def test_bookmarks(client, user_headers):
    async with SessionLocal() as db:
        plant = (await db.scalars(select(Plant).limit(1))).first()
    post = (await client.post(f"{API}/posts", json={"title": "Saqlash", "content": "Saqlanadigan post matni", "category": "advice"}, headers=user_headers)).json()
    for _ in range(2):  # ikki marta bosish — bitta yozuv
        r = await client.post(f"{API}/bookmarks", json={"kind": "post", "target_id": post["id"]}, headers=user_headers)
        assert r.status_code == 201 and r.json()["exists"] and r.json()["title"] == "Saqlash"
    await client.post(f"{API}/bookmarks", json={"kind": "plant", "target_id": str(plant.id)}, headers=user_headers)
    assert len((await client.get(f"{API}/bookmarks", headers=user_headers)).json()) == 2
    assert [b["kind"] for b in (await client.get(f"{API}/bookmarks?kind=plant", headers=user_headers)).json()] == ["plant"]
    # o'chirilgan post — placeholder
    await client.delete(f"{API}/posts/{post['id']}", headers=user_headers)
    gone = [b for b in (await client.get(f"{API}/bookmarks", headers=user_headers)).json() if b["kind"] == "post"][0]
    assert gone["exists"] is False and gone["title"] is None
    assert (await client.delete(f"{API}/bookmarks/post/{post['id']}", headers=user_headers)).status_code == 204
    assert len((await client.get(f"{API}/bookmarks", headers=user_headers)).json()) == 1
    bad = await client.post(f"{API}/bookmarks", json={"kind": "post", "target_id": post["id"]}, headers=user_headers)
    assert bad.status_code == 404


async def test_search_and_block(client, user_headers):
    other = auth(await register(client, "dilnoza_f", full_name="Dilnoza Karimova"))
    third = auth(await register(client, "jasur", full_name="Jasur Aliyev"))
    other_id = (await me(client, other))["id"]
    assert (await client.get(f"{API}/users/search?q=d", headers=user_headers)).json() == []  # 2 belgidan kam
    found = (await client.get(f"{API}/users/search?q=dilno", headers=user_headers)).json()
    assert [u["username"] for u in found] == ["dilnoza_f"] and "email" not in found[0] and "phone" not in found[0]
    assert (await client.get(f"{API}/users/search?q=@jas", headers=user_headers)).json()[0]["username"] == "jasur"
    assert (await client.get(f"{API}/users/search?q=farmer", headers=user_headers)).json() == []  # o'zi chiqmaydi

    # obuna, post, izoh, suhbat — keyin bloklash
    await client.post(f"{API}/users/{other_id}/follow", headers=user_headers)
    post = (await client.post(f"{API}/posts", json={"title": "Dilnoza posti", "content": "Bloklangandan keyin ko'rinmaydi", "category": "advice"}, headers=other)).json()
    my_post = (await client.post(f"{API}/posts", json={"title": "Mening postim", "content": "Izohlar shu yerda bo'ladi", "category": "advice"}, headers=user_headers)).json()
    await client.post(f"{API}/posts/{my_post['id']}/comments", json={"content": "Dilnoza izohi"}, headers=other)
    await client.post(f"{API}/posts/{my_post['id']}/comments", json={"content": "Jasur izohi"}, headers=third)
    conv = (await client.post(f"{API}/conversations", json={"user_id": other_id}, headers=user_headers)).json()

    assert (await client.post(f"{API}/users/{other_id}/block", headers=user_headers)).status_code == 204
    assert (await client.post(f"{API}/users/{other_id}/block", headers=user_headers)).status_code == 204  # idempotent
    prof = (await client.get(f"{API}/users/{other_id}", headers=user_headers)).json()
    assert prof["is_blocked"] and not prof["is_following"]
    feed = [p["id"] for p in (await client.get(f"{API}/posts", headers=user_headers)).json()]
    assert post["id"] not in feed and my_post["id"] in feed
    # ikki tomonlama: u ham mening postimni ko'rmaydi
    assert my_post["id"] not in [p["id"] for p in (await client.get(f"{API}/posts", headers=other)).json()]
    comments = [c["content"] for c in (await client.get(f"{API}/posts/{my_post['id']}/comments", headers=user_headers)).json()]
    assert comments == ["Jasur izohi"]
    assert (await client.get(f"{API}/users/search?q=dilno", headers=user_headers)).json() == []
    assert (await client.get(f"{API}/users/search?q=farmer", headers=other)).json() == []
    send = await client.post(f"{API}/conversations/{conv['id']}/messages", json={"content": "salom"}, headers=other)
    assert send.status_code == 403
    assert (await client.post(f"{API}/conversations", json={"user_id": other_id}, headers=user_headers)).status_code == 403
    assert (await client.post(f"{API}/users/{(await me(client, user_headers))['id']}/follow", headers=other)).status_code == 403
    assert [c["blocked"] for c in (await client.get(f"{API}/conversations", headers=user_headers)).json()] == [True]
    assert [u["username"] for u in (await client.get(f"{API}/users/me/blocks", headers=user_headers)).json()] == ["dilnoza_f"]

    assert (await client.delete(f"{API}/users/{other_id}/block", headers=user_headers)).status_code == 204
    assert post["id"] in [p["id"] for p in (await client.get(f"{API}/posts", headers=user_headers)).json()]
    assert (await client.post(f"{API}/conversations/{conv['id']}/messages", json={"content": "salom"}, headers=other)).status_code == 201

    # faol bo'lmagan hisob qidiruvda chiqmaydi
    async with SessionLocal() as db:
        u = await db.scalar(select(User).where(User.username == "jasur"))
        u.is_active = False
        await db.commit()
    assert (await client.get(f"{API}/users/search?q=jasur", headers=user_headers)).json() == []


async def test_diary(client, user_headers):
    crop = (await client.post(f"{API}/crops", json={"name": "Pomidor"}, headers=user_headers)).json()
    url = f"{API}/crops/{crop['id']}/logs"
    assert (await client.post(url, json={"content": "  "}, headers=user_headers)).status_code == 422  # bo'sh
    assert (await client.post(url, json={"content": "x" * 2001}, headers=user_headers)).status_code == 422
    assert (await client.post(url, json={"images": ["https://evil.com/a.jpg"]}, headers=user_headers)).status_code == 422
    assert (await client.post(url, json={"content": "a", "images": ["/media/a.jpg"] * 6}, headers=user_headers)).status_code == 422
    assert (await client.post(url, json={"content": "a", "observed_at": "2999-01-01"}, headers=user_headers)).status_code == 422
    photo = await client.post(url, json={"images": ["/media/diag/a.jpg", "/media/diag/b.jpg"], "observed_at": "2026-10-01"}, headers=user_headers)
    assert photo.status_code == 201 and photo.json()["image_url"] == "/media/diag/a.jpg" and photo.json()["version"] == 1
    old = await client.post(url, json={"content": "Eski ilova", "image_url": "/media/x.jpg"}, headers=user_headers)
    assert old.json()["images"] == ["/media/x.jpg"]  # eski format ham ishlaydi
    log = photo.json()
    up = await client.put(f"{url}/{log['id']}", json={"content": "Barglar sarg'aydi", "images": [], "version": 1}, headers=user_headers)
    assert up.status_code == 200 and up.json()["version"] == 2 and up.json()["image_url"] is None
    conflict = await client.put(f"{url}/{log['id']}", json={"content": "Eski versiyadan", "version": 1}, headers=user_headers)
    assert conflict.status_code == 409
    other = auth(await register(client, "boshqa"))
    assert (await client.delete(f"{url}/{log['id']}", headers=other)).status_code == 404
    assert (await client.delete(f"{url}/{log['id']}", headers=user_headers)).status_code == 204
    assert [x["content"] for x in (await client.get(url, headers=user_headers)).json()] == ["Eski ilova"]


async def test_report_duplicate(client, user_headers):
    post = (await client.post(f"{API}/posts", json={"title": "Spam", "content": "Spam posti matni", "category": "advice"}, headers=user_headers)).json()
    other = auth(await register(client, "reporter"))
    a = (await client.post(f"{API}/reports", json={"post_id": post["id"], "reason": "spam"}, headers=other)).json()
    b = (await client.post(f"{API}/reports", json={"post_id": post["id"], "reason": "spam"}, headers=other)).json()
    assert a["id"] == b["id"]
