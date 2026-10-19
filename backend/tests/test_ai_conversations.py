"""TZ S09/S10: bir nechta AI suhbat, oqimli javob (SSE), qisman javob, qayta javob, nomlash/o'chirish/qidirish."""
import json

from sqlalchemy import select

from app.api.v1 import ai as ai_api
from app.core.database import SessionLocal
from app.models import AIChatMessage, User

API = "/api/v1"
Q = "Pomidor bargida qo'ng'ir suvli dog'lar paydo bo'ldi, fitoftoroz emasmi?"


def events(text: str) -> list[tuple[str, dict]]:
    out = []
    for block in text.strip().split("\n\n"):
        lines = dict(line.split(": ", 1) for line in block.split("\n") if ": " in line)
        out.append((lines["event"], json.loads(lines["data"])))
    return out


async def test_stream_and_conversations(client, user_headers):
    r = await client.post(f"{API}/ai/messages", json={"message": Q}, headers=user_headers)
    assert r.status_code == 200 and r.headers["content-type"].startswith("text/event-stream")
    ev = events(r.text)
    assert ev[0][0] == "user" and ev[-1][0] == "done"
    deltas = [d["text"] for e, d in ev if e == "delta"]
    assert len(deltas) > 1  # bo'laklab
    reply = ev[-1][1]["reply"]
    assert reply["status"] == "done" and reply["content"] == "".join(deltas).strip()
    conv_id = ev[0][1]["message"]["conversation_id"]
    assert reply["reply_to_id"] == ev[0][1]["message"]["id"]
    assert ev[0][1]["conversation_title"].startswith("Pomidor bargida")
    # ikkinchi suhbat
    r2 = await client.post(f"{API}/ai/messages", json={"message": "Qachon sug'orish kerak?"}, headers=user_headers)
    conv2 = events(r2.text)[0][1]["message"]["conversation_id"]
    assert conv2 != conv_id
    # davom ettirish — o'sha suhbatda
    r3 = await client.post(f"{API}/ai/messages", json={"message": "Bordo suyuqligi haqida", "conversation_id": conv_id}, headers=user_headers)
    assert events(r3.text)[0][1]["message"]["conversation_id"] == conv_id
    convs = (await client.get(f"{API}/ai/conversations", headers=user_headers)).json()
    assert [c["id"] for c in convs] == [conv_id, conv2] and convs[0]["message_count"] == 4
    # qidiruv (xabar matni bo'yicha) va nomlash
    assert [c["id"] for c in (await client.get(f"{API}/ai/conversations?q=qachon sug'orish", headers=user_headers)).json()] == [conv2]
    rn = await client.patch(f"{API}/ai/conversations/{conv2}", json={"title": "  Sug'orish  "}, headers=user_headers)
    assert rn.json()["title"] == "Sug'orish"
    assert (await client.patch(f"{API}/ai/conversations/{conv2}", json={"title": " "}, headers=user_headers)).status_code == 422
    msgs = (await client.get(f"{API}/ai/conversations/{conv_id}/messages", headers=user_headers)).json()
    assert [m["role"] for m in msgs] == ["user", "assistant", "user", "assistant"]
    # o'chirish va begona foydalanuvchi
    from tests.conftest import auth, register

    other = auth(await register(client, "begona"))
    assert (await client.get(f"{API}/ai/conversations/{conv_id}/messages", headers=other)).status_code == 404
    assert (await client.post(f"{API}/ai/messages", json={"message": "x", "conversation_id": conv_id}, headers=other)).status_code == 404
    assert (await client.delete(f"{API}/ai/conversations/{conv2}", headers=user_headers)).status_code == 204
    assert len((await client.get(f"{API}/ai/conversations", headers=user_headers)).json()) == 1
    # bo'sh xabar
    assert (await client.post(f"{API}/ai/messages", json={"message": "   "}, headers=user_headers)).status_code == 422


async def test_retry_replaces_reply_and_is_free(client, user_headers):
    r = await client.post(f"{API}/ai/messages", json={"message": Q}, headers=user_headers)
    user_msg = events(r.text)[0][1]["message"]
    used = (await client.get(f"{API}/subscriptions/me", headers=user_headers)).json()
    rr = await client.post(f"{API}/ai/messages/{user_msg['id']}/retry", headers=user_headers)
    ev = events(rr.text)
    assert ev[-1][0] == "done" and ev[-1][1]["reply"]["reply_to_id"] == user_msg["id"]
    msgs = (await client.get(f"{API}/ai/conversations/{user_msg['conversation_id']}/messages", headers=user_headers)).json()
    assert [m["role"] for m in msgs] == ["user", "assistant"]  # eski javob almashtirildi
    assert (await client.get(f"{API}/subscriptions/me", headers=user_headers)).json() == used
    reply_id = ev[-1][1]["reply"]["id"]
    assert (await client.post(f"{API}/ai/messages/{reply_id}/retry", headers=user_headers)).status_code == 404  # faqat savol


async def test_stopped_stream_saves_partial(client, user_headers):
    r = await client.post(f"{API}/ai/messages", json={"message": Q}, headers=user_headers)
    user_msg = events(r.text)[0][1]["message"]
    async with SessionLocal() as db:
        user = (await db.scalars(select(User).where(User.username == "farmer"))).one()
        q = await db.get(AIChatMessage, __import__("uuid").UUID(user_msg["id"]))
    import uuid

    gen = ai_api._stream(user.id, uuid.UUID(user_msg["conversation_id"]), q, None, [])
    first = await gen.__anext__()
    assert first.startswith("event: delta")
    await gen.aclose()  # mijoz "To'xtatish" bosdi / ulanish uzildi
    msgs = (await client.get(f"{API}/ai/conversations/{user_msg['conversation_id']}/messages", headers=user_headers)).json()
    partial = [m for m in msgs if m["status"] == "partial"]
    assert len(partial) == 1 and partial[0]["reply_to_id"] == user_msg["id"]
    assert partial[0]["content"] and len(partial[0]["content"]) < len([m for m in msgs if m["status"] == "done" and m["role"] == "assistant"][0]["content"])


async def test_legacy_chat_uses_conversation(client, user_headers):
    r = await client.post(f"{API}/ai/chat", json={"message": "Qachon sug'orish kerak?"}, headers=user_headers)
    assert r.status_code == 200 and r.json()["reply"]["conversation_id"]
    assert len((await client.get(f"{API}/ai/chat/history", headers=user_headers)).json()) == 2
    assert len((await client.get(f"{API}/ai/conversations", headers=user_headers)).json()) == 1
