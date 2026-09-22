import uuid

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select

from app.core.database import SessionLocal
from app.core.security import decode_access_token
from app.models import ConversationParticipant, Message
from app.services.chat_service import save_message
from app.websocket.manager import chat_hub

router = APIRouter()


@router.websocket("/ws/chat/{conversation_id}")
async def chat_ws(websocket: WebSocket, conversation_id: uuid.UUID, token: str = Query(...)):
    payload = decode_access_token(token)
    if payload is None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
    user_id = uuid.UUID(payload["sub"])
    async with SessionLocal() as db:
        member = await db.scalar(
            select(ConversationParticipant.id).where(
                ConversationParticipant.conversation_id == conversation_id,
                ConversationParticipant.user_id == user_id,
            )
        )
    if member is None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await websocket.accept()
    key = str(conversation_id)
    await chat_hub.connect(key, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            kind = data.get("type", "message")
            if kind == "typing":
                await chat_hub.send(key, {"event": "typing", "user_id": str(user_id)})
                continue
            if kind == "read":
                async with SessionLocal() as db:
                    msgs = await db.scalars(
                        select(Message).where(
                            Message.conversation_id == conversation_id,
                            Message.sender_id != user_id,
                            Message.is_read.is_(False),
                        )
                    )
                    for m in msgs:
                        m.is_read = True
                    await db.commit()
                await chat_hub.send(key, {"event": "read", "user_id": str(user_id)})
                continue
            content = (data.get("content") or "").strip()
            if not content and not data.get("image_url"):
                continue
            async with SessionLocal() as db:
                await save_message(db, conversation_id, user_id, content[:4000], data.get("image_url"))
                await db.commit()
    except WebSocketDisconnect:
        pass
    finally:
        await chat_hub.disconnect(key, websocket)
