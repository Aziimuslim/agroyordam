import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import utcnow
from app.models import Conversation, ConversationParticipant, Message, User
from app.schemas.chat import MessageOut
from app.services.notification_service import notify
from app.websocket.manager import chat_hub


async def save_message(
    db: AsyncSession, conversation_id: uuid.UUID, sender_id: uuid.UUID, content: str | None, image_url: str | None
) -> Message:
    msg = Message(conversation_id=conversation_id, sender_id=sender_id, content=content, image_url=image_url)
    db.add(msg)
    conv = await db.get(Conversation, conversation_id)
    if conv:
        conv.updated_at = utcnow()
    await db.flush()
    await db.refresh(msg)
    await chat_hub.send(str(conversation_id), {"event": "message", "data": MessageOut.model_validate(msg).model_dump(mode="json")})
    # Suhbatdagi boshqa ishtirokchilarga bildirishnoma
    sender = await db.get(User, sender_id)
    others = await db.scalars(
        select(ConversationParticipant.user_id).where(
            ConversationParticipant.conversation_id == conversation_id,
            ConversationParticipant.user_id != sender_id,
        )
    )
    for uid in others:
        await notify(db, uid, "message", f"{sender.full_name if sender else 'Yangi'} xabar yubordi", (content or "📷")[:120], conversation_id)
    return msg
