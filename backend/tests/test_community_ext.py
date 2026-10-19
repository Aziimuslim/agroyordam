"""TZ S12 (0–5 rasm), S13 (izohga javob, o'chirilgan ota izoh, tahrir), S15 (o'qildi/ovozsiz/yashirish), S16 (rasmlar, yetkazildi)."""
from tests.conftest import auth, register

API = "/api/v1"


async def me(client, h):
    return (await client.get(f"{API}/users/me", headers=h)).json()


async def test_post_images(client, user_headers):
    imgs = [f"/media/posts/{i}.jpg" for i in range(5)]
    body = {"title": "Rasmli post", "content": "Beshta rasmli post matni", "category": "experience", "image_urls": imgs + [imgs[0]]}
    p = (await client.post(f"{API}/posts", json=body, headers=user_headers)).json()
    assert p["image_urls"] == imgs and p["image_url"] == imgs[0]
    too_many = await client.post(f"{API}/posts", json={**body, "image_urls": imgs + ["/media/posts/x.jpg"]}, headers=user_headers)
    assert too_many.status_code == 422
    # tahrir: rasmni olib tashlash
    u = (await client.put(f"{API}/posts/{p['id']}", json={"image_urls": imgs[2:4]}, headers=user_headers)).json()
    assert u["image_urls"] == imgs[2:4] and u["image_url"] == imgs[2]
    u = (await client.put(f"{API}/posts/{p['id']}", json={"image_urls": []}, headers=user_headers)).json()
    assert u["image_urls"] == [] and u["image_url"] is None
    # eski klient: bitta image_url
    old = (await client.post(f"{API}/posts", json={"title": "Eski", "content": "Bitta rasmli eski post", "image_url": "/media/a.jpg"}, headers=user_headers)).json()
    assert old["image_urls"] == ["/media/a.jpg"]


async def test_comment_replies(client, user_headers):
    other = auth(await register(client, "javobchi"))
    post = (await client.post(f"{API}/posts", json={"title": "Savol", "content": "Pomidor bargida dog'", "category": "question"}, headers=user_headers)).json()
    root = (await client.post(f"{API}/posts/{post['id']}/comments", json={"content": "Ota izoh"}, headers=user_headers)).json()
    r1 = (await client.post(f"{API}/posts/{post['id']}/comments", json={"content": "Javob", "reply_to_id": root["id"]}, headers=other)).json()
    assert r1["parent_id"] == root["id"] and r1["reply_to_name"] == "Test Fermer"
    # javobga javob — ildizga birikadi, reply_to aynan javob
    r2 = (await client.post(f"{API}/posts/{post['id']}/comments", json={"content": "Javobga javob", "reply_to_id": r1["id"]}, headers=user_headers)).json()
    assert r2["parent_id"] == root["id"] and r2["reply_to_id"] == r1["id"]
    # boshqa postdagi izohga javob — 404
    post2 = (await client.post(f"{API}/posts", json={"title": "Boshqa", "content": "Boshqa post matni"}, headers=user_headers)).json()
    bad = await client.post(f"{API}/posts/{post2['id']}/comments", json={"content": "x", "reply_to_id": root["id"]}, headers=user_headers)
    assert bad.status_code == 404
    # javob muallifga "Izohingizga javob" bildirishnomasi
    notes = (await client.get(f"{API}/notifications", headers=other)).json()
    assert any(n["title"] == "Izohingizga javob" for n in notes)
    # tahrir
    e = await client.put(f"{API}/comments/{r1['id']}", json={"content": "Tuzatilgan"}, headers=user_headers)
    assert e.status_code == 403
    e = (await client.put(f"{API}/comments/{r1['id']}", json={"content": "Tuzatilgan javob"}, headers=other)).json()
    assert e["content"] == "Tuzatilgan javob"
    # ota izoh o'chirildi — javoblar saqlanadi
    assert (await client.delete(f"{API}/comments/{root['id']}", headers=user_headers)).status_code == 204
    cs = (await client.get(f"{API}/posts/{post['id']}/comments", headers=user_headers)).json()
    assert len(cs) == 3 and cs[0]["deleted"] is True and cs[0]["content"] == "" and cs[0]["author"] is None
    assert (await client.get(f"{API}/posts/{post['id']}", headers=user_headers)).json()["comments_count"] == 2
    # o'chirilgan izohga javob bo'lmaydi
    assert (await client.post(f"{API}/posts/{post['id']}/comments", json={"content": "x", "reply_to_id": root["id"]}, headers=other)).status_code == 404
    # javoblar ham o'chsa ota izoh butunlay yo'qoladi
    await client.delete(f"{API}/comments/{r1['id']}", headers=other)
    await client.delete(f"{API}/comments/{r2['id']}", headers=user_headers)
    assert (await client.get(f"{API}/posts/{post['id']}/comments", headers=user_headers)).json() == []


async def test_chat_images_delivered_mute_hide(client, user_headers):
    other = auth(await register(client, "suhbatdosh2"))
    other_id = (await me(client, other))["id"]
    conv = (await client.post(f"{API}/conversations", json={"user_id": other_id}, headers=user_headers)).json()
    imgs = [f"/media/messages/{i}.jpg" for i in range(3)]
    m = (await client.post(f"{API}/conversations/{conv['id']}/messages", json={"image_urls": imgs}, headers=user_headers)).json()
    assert m["image_urls"] == imgs and m["delivered"] is False and m["is_read"] is False
    six = await client.post(f"{API}/conversations/{conv['id']}/messages", json={"image_urls": imgs * 2}, headers=user_headers)
    assert six.status_code == 422
    # qabul qiluvchi ro'yxatni oldi — yetkazildi (server event)
    lst = (await client.get(f"{API}/conversations", headers=other)).json()
    assert lst[0]["last_message"]["image_urls"] == imgs
    mine = (await client.get(f"{API}/conversations/{conv['id']}/messages", headers=user_headers)).json()
    assert mine[0]["delivered"] is True and mine[0]["is_read"] is False
    # o'qilgan deb belgilash
    assert (await client.put(f"{API}/conversations/{conv['id']}/read", headers=other)).status_code == 204
    assert (await client.get(f"{API}/conversations", headers=other)).json()[0]["unread_count"] == 0
    assert (await client.get(f"{API}/conversations/{conv['id']}/messages", headers=user_headers)).json()[0]["is_read"] is True
    # ovozsiz — bildirishnoma yo'q
    r = (await client.put(f"{API}/conversations/{conv['id']}/mute", json={"muted": True}, headers=other)).json()
    assert r["muted"] is True
    before = len((await client.get(f"{API}/notifications", headers=other)).json())
    await client.post(f"{API}/conversations/{conv['id']}/messages", json={"content": "jim"}, headers=user_headers)
    assert len((await client.get(f"{API}/notifications", headers=other)).json()) == before
    assert (await client.get(f"{API}/conversations", headers=other)).json()[0]["unread_count"] == 1
    # yashirish — faqat o'z ro'yxatidan; yangi xabar bilan qaytadi
    assert (await client.delete(f"{API}/conversations/{conv['id']}", headers=other)).status_code == 204
    assert (await client.get(f"{API}/conversations", headers=other)).json() == []
    assert len((await client.get(f"{API}/conversations", headers=user_headers)).json()) == 1
    assert len((await client.get(f"{API}/conversations/{conv['id']}/messages", headers=user_headers)).json()) == 2
    await client.post(f"{API}/conversations/{conv['id']}/messages", json={"content": "yana"}, headers=user_headers)
    assert len((await client.get(f"{API}/conversations", headers=other)).json()) == 1
