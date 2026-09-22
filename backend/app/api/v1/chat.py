import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import Conversation, ConversationParticipant, Message, User
from app.schemas.chat import ConversationIn, ConversationOut, MessageIn, MessageOut
from app.schemas.user import UserPublic
from app.services.chat_service import save_message

router = APIRouter(tags=["Chat"])


async def ensure_member(db: AsyncSession, conv_id: uuid.UUID, user: User) -> Conversation:
    conv = await db.get(Conversation, conv_id)
    member = await db.scalar(select(ConversationParticipant.id).where(
        ConversationParticipant.conversation_id == conv_id, ConversationParticipant.user_id == user.id))
    if conv is None or member is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Suhbat topilmadi")
    return conv


async def conv_out(db: AsyncSession, conv: Conversation, me: User) -> ConversationOut:
    users = (await db.scalars(select(User).join(ConversationParticipant, ConversationParticipant.user_id == User.id)
                              .where(ConversationParticipant.conversation_id == conv.id))).all()
    last = await db.scalar(select(Message).where(Message.conversation_id == conv.id).order_by(Message.created_at.desc()).limit(1))
    unread = await db.scalar(select(func.count()).select_from(Message).where(
        Message.conversation_id == conv.id, Message.sender_id != me.id, Message.is_read.is_(False))) or 0
    return ConversationOut(
        id=conv.id, participants=[UserPublic.model_validate(u) for u in users if u.id != me.id],
        last_message=MessageOut.model_validate(last) if last else None, unread_count=unread, updated_at=conv.updated_at,
    )


@router.get("/conversations", response_model=list[ConversationOut])
async def list_conversations(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = (select(Conversation).join(ConversationParticipant, ConversationParticipant.conversation_id == Conversation.id)
            .where(ConversationParticipant.user_id == user.id).order_by(Conversation.updated_at.desc()))
    return [await conv_out(db, c, user) for c in (await db.scalars(stmt)).all()]


@router.post("/conversations", response_model=ConversationOut, status_code=201)
async def start_conversation(body: ConversationIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if body.user_id == user.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "O'zingiz bilan suhbat ochib bo'lmaydi")
    other = await db.get(User, body.user_id)
    if other is None or not other.is_active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Foydalanuvchi topilmadi")
    # Mavjud 1:1 suhbatni qayta ishlatamiz
    mine = select(ConversationParticipant.conversation_id).where(ConversationParticipant.user_id == user.id)
    existing = await db.scalar(select(Conversation).join(ConversationParticipant, ConversationParticipant.conversation_id == Conversation.id)
                               .where(ConversationParticipant.user_id == other.id, Conversation.id.in_(mine)).limit(1))
    if existing:
        return await conv_out(db, existing, user)
    conv = Conversation()
    db.add(conv)
    await db.flush()
    db.add_all([ConversationParticipant(conversation_id=conv.id, user_id=user.id),
                ConversationParticipant(conversation_id=conv.id, user_id=other.id)])
    await db.commit()
    return await conv_out(db, conv, user)


@router.get("/conversations/{conv_id}/messages", response_model=list[MessageOut])
async def list_messages(conv_id: uuid.UUID, limit: int = 100, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await ensure_member(db, conv_id, user)
    stmt = select(Message).where(Message.conversation_id == conv_id).order_by(Message.created_at.desc()).limit(min(limit, 500))
    return list(reversed((await db.scalars(stmt)).all()))


@router.post("/conversations/{conv_id}/messages", response_model=MessageOut, status_code=201)
async def send_message(conv_id: uuid.UUID, body: MessageIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await ensure_member(db, conv_id, user)
    if not (body.content or "").strip() and not body.image_url:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Bo'sh xabar")
    msg = await save_message(db, conv_id, user.id, (body.content or "").strip() or None, body.image_url)
    await db.commit()
    return msg


@router.put("/messages/{message_id}/read", response_model=MessageOut)
async def mark_read(message_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    msg = await db.get(Message, message_id)
    if msg is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Xabar topilmadi")
    await ensure_member(db, msg.conversation_id, user)
    if msg.sender_id != user.id:
        # shu xabargacha bo'lgan barcha xabarlarni o'qilgan deb belgilaymiz
        await db.execute(update(Message).where(
            Message.conversation_id == msg.conversation_id, Message.sender_id != user.id,
            Message.created_at <= msg.created_at).values(is_read=True))
        await db.commit()
        await db.refresh(msg)
    return msg
