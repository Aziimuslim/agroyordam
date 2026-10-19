import uuid

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import utcnow
from app.models import Conversation, ConversationParticipant, Message, User
from app.schemas.chat import MessageOut
from app.services.notification_service import notify
from app.websocket.manager import chat_hub, notifications_hub


async def save_message(
    db: AsyncSession, conversation_id: uuid.UUID, sender_id: uuid.UUID, content: str | None, image_urls: list[str] | None
) -> Message:
    images = [u for u in (image_urls or []) if u][:5]
    others = (await db.scalars(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conversation_id,
            ConversationParticipant.user_id != sender_id,
        )
    )).all()
    # TZ S16: "yetkazildi" faqat server event bilan — qabul qiluvchi qurilmasi realtime ulangan bo'lsa darhol
    online = any(notifications_hub.online(str(p.user_id)) for p in others)
    msg = Message(conversation_id=conversation_id, sender_id=sender_id, content=content,
                  image_url=images[0] if images else None, image_urls=images or None,
                  delivered_at=utcnow() if online else None)
    db.add(msg)
    conv = await db.get(Conversation, conversation_id)
    if conv:
        conv.updated_at = utcnow()  # yashirilgan suhbat yangi xabar bilan qayta ko'rinadi
    await db.flush()
    await db.refresh(msg)
    await chat_hub.send(str(conversation_id), {"event": "message", "data": MessageOut.of(msg).model_dump(mode="json")})
    sender = await db.get(User, sender_id)
    preview = content or ("📷" * min(len(images), 3) if images else "")
    for p in others:
        if p.muted:
            continue  # TZ S15: ovozsiz suhbat — bildirishnoma yo'q (o'qilmaganlar soni saqlanadi)
        await notify(db, p.user_id, "message", f"{sender.full_name if sender else 'Yangi'} xabar yubordi", preview[:120], conversation_id)
    return msg


async def mark_delivered(db: AsyncSession, user_id: uuid.UUID, conversation_ids: list[uuid.UUID]) -> None:
    """Qabul qiluvchi xabarlarni serverdan oldi — yetkazildi. Yuboruvchiga chat event."""
    if not conversation_ids:
        return
    pending = (await db.scalars(select(Message.conversation_id).where(
        Message.conversation_id.in_(conversation_ids), Message.sender_id != user_id, Message.delivered_at.is_(None)).distinct())).all()
    if not pending:
        return
    now = utcnow()
    await db.execute(update(Message).where(
        Message.conversation_id.in_(pending), Message.sender_id != user_id, Message.delivered_at.is_(None)).values(delivered_at=now))
    await db.commit()
    for cid in pending:
        await chat_hub.send(str(cid), {"event": "delivered", "user_id": str(user_id), "at": now.isoformat()})


async def mark_read(db: AsyncSession, user_id: uuid.UUID, conversation_id: uuid.UUID, until=None) -> None:
    stmt = update(Message).where(Message.conversation_id == conversation_id, Message.sender_id != user_id, Message.is_read.is_(False))
    if until is not None:
        stmt = stmt.where(Message.created_at <= until)
    now = utcnow()
    await db.execute(stmt.values(is_read=True))
    await db.execute(update(Message).where(Message.conversation_id == conversation_id, Message.sender_id != user_id,
                                           Message.delivered_at.is_(None), Message.is_read.is_(True)).values(delivered_at=now))
    await db.commit()
    await chat_hub.send(str(conversation_id), {"event": "read", "user_id": str(user_id)})
