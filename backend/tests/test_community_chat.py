from fastapi.testclient import TestClient

from app.main import app
from tests.conftest import auth, register


async def test_posts_likes_comments(client, user_headers):
    other = auth(await register(client, "neighbor"))
    p = (await client.post("/api/v1/posts", json={"title": "Savol", "content": "Bodring sarg'aymoqda", "category": "question"}, headers=user_headers)).json()
    assert p["author"]["username"] == "farmer"
    liked = (await client.post(f"/api/v1/posts/{p['id']}/like", headers=other)).json()
    assert liked["likes_count"] == 1 and liked["liked_by_me"]
    liked = (await client.post(f"/api/v1/posts/{p['id']}/like", headers=other)).json()
    assert liked["likes_count"] == 1  # idempotent
    c = (await client.post(f"/api/v1/posts/{p['id']}/comments", json={"content": "Azot yetishmayapti"}, headers=other)).json()
    assert len((await client.get(f"/api/v1/posts/{p['id']}/comments", headers=user_headers)).json()) == 1
    feed = (await client.get("/api/v1/posts", params={"category": "question"}, headers=other)).json()
    assert feed[0]["comments_count"] == 1
    assert (await client.get("/api/v1/posts", params={"q": "Bodring"}, headers=other)).json()
    types = {n["type"] for n in (await client.get("/api/v1/notifications", headers=user_headers)).json()}
    assert {"like", "comment"} <= types

    assert (await client.put(f"/api/v1/posts/{p['id']}", json={"title": "Tahrir"}, headers=other)).status_code == 403
    assert (await client.put(f"/api/v1/posts/{p['id']}", json={"title": "Tahrir"}, headers=user_headers)).json()["title"] == "Tahrir"
    assert (await client.delete(f"/api/v1/comments/{c['id']}", headers=user_headers)).status_code == 403
    assert (await client.delete(f"/api/v1/comments/{c['id']}", headers=other)).status_code == 204
    assert (await client.delete(f"/api/v1/posts/{p['id']}/like", headers=other)).json()["likes_count"] == 0
    assert (await client.delete(f"/api/v1/posts/{p['id']}", headers=other)).status_code == 403
    assert (await client.delete(f"/api/v1/posts/{p['id']}", headers=user_headers)).status_code == 204
    assert (await client.get(f"/api/v1/posts/{p['id']}", headers=user_headers)).status_code == 404


async def test_following_feed(client, user_headers):
    other = auth(await register(client, "author"))
    oid = (await client.get("/api/v1/users/me", headers=other)).json()["id"]
    await client.post("/api/v1/posts", json={"title": "A"}, headers=other)
    assert (await client.get("/api/v1/posts", params={"feed": "following"}, headers=user_headers)).json() == []
    await client.post(f"/api/v1/users/{oid}/follow", headers=user_headers)
    assert len((await client.get("/api/v1/posts", params={"feed": "following"}, headers=user_headers)).json()) == 1


async def test_reports_moderation(client, user_headers, admin_headers):
    p = (await client.post("/api/v1/posts", json={"title": "Spam"}, headers=user_headers)).json()
    assert (await client.post("/api/v1/reports", json={"reason": "x"}, headers=user_headers)).status_code == 400
    rep = (await client.post("/api/v1/reports", json={"post_id": p["id"], "reason": "spam"}, headers=user_headers)).json()
    assert (await client.get("/api/v1/reports", headers=user_headers)).status_code == 403
    assert len((await client.get("/api/v1/reports", headers=admin_headers)).json()) == 1
    r = await client.put(f"/api/v1/reports/{rep['id']}/resolve", params={"remove_content": True}, headers=admin_headers)
    assert r.status_code == 200 and r.json()["status"] == "resolved"
    assert (await client.get(f"/api/v1/posts/{p['id']}", headers=user_headers)).status_code == 404


async def test_chat_rest(client, user_headers):
    other = auth(await register(client, "friend"))
    oid = (await client.get("/api/v1/users/me", headers=other)).json()["id"]
    conv = (await client.post("/api/v1/conversations", json={"user_id": oid}, headers=user_headers)).json()
    again = (await client.post("/api/v1/conversations", json={"user_id": oid}, headers=user_headers)).json()
    assert conv["id"] == again["id"]
    m = (await client.post(f"/api/v1/conversations/{conv['id']}/messages", json={"content": "Salom!"}, headers=user_headers)).json()
    assert (await client.post(f"/api/v1/conversations/{conv['id']}/messages", json={"content": " "}, headers=user_headers)).status_code == 400
    lst = (await client.get("/api/v1/conversations", headers=other)).json()
    assert lst[0]["unread_count"] == 1 and lst[0]["last_message"]["content"] == "Salom!"
    r = await client.put(f"/api/v1/messages/{m['id']}/read", headers=other)
    assert r.json()["is_read"] is True
    assert (await client.get("/api/v1/conversations", headers=other)).json()[0]["unread_count"] == 0
    third = auth(await register(client, "stranger"))
    assert (await client.get(f"/api/v1/conversations/{conv['id']}/messages", headers=third)).status_code == 404
    assert len((await client.get(f"/api/v1/conversations/{conv['id']}/messages", headers=other)).json()) == 1


async def test_chat_websocket(client, user_headers):
    other_tokens = await register(client, "wsfriend")
    other = auth(other_tokens)
    me_tokens_header = user_headers["Authorization"].split()[1]
    oid = (await client.get("/api/v1/users/me", headers=other)).json()["id"]
    me_id = (await client.get("/api/v1/users/me", headers=user_headers)).json()["id"]
    conv = (await client.post("/api/v1/conversations", json={"user_id": oid}, headers=user_headers)).json()

    with TestClient(app) as tc:
        with tc.websocket_connect(f"/ws/notifications/{oid}?token={other_tokens['access_token']}") as notif, \
             tc.websocket_connect(f"/ws/chat/{conv['id']}?token={me_tokens_header}") as a, \
             tc.websocket_connect(f"/ws/chat/{conv['id']}?token={other_tokens['access_token']}") as b:
            a.send_json({"type": "message", "content": "Real-time salom"})
            got_a, got_b = a.receive_json(), b.receive_json()
            assert got_a["event"] == got_b["event"] == "message"
            assert got_b["data"]["content"] == "Real-time salom" and got_b["data"]["sender_id"] == me_id
            n = notif.receive_json()
            assert n["event"] == "notification" and n["data"]["type"] == "message"
            b.send_json({"type": "typing"})
            assert a.receive_json()["event"] == "typing"
            b.send_json({"type": "read"})
            assert a.receive_json()["event"] == "read"


def test_websocket_rejects_bad_token():
    import pytest
    from starlette.websockets import WebSocketDisconnect

    with TestClient(app) as tc:
        with pytest.raises(WebSocketDisconnect):
            with tc.websocket_connect("/ws/chat/00000000-0000-0000-0000-000000000000?token=bad") as ws:
                ws.receive_json()
