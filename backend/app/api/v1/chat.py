import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import Conversation, ConversationParticipant, Message, User
from app.schemas.chat import ConversationIn, ConversationOut, MessageIn, MessageOut
from app.schemas.user import UserPublic
from app.services import block_service
from app.core.security import utcnow
from app.services import chat_service
from app.services.chat_service import save_message

router = APIRouter(tags=["Chat"])


async def ensure_member(db: AsyncSession, conv_id: uuid.UUID, user: User) -> Conversation:
    conv = await db.get(Conversation, conv_id)
    member = await db.scalar(select(ConversationParticipant.id).where(
        ConversationParticipant.conversation_id == conv_id, ConversationParticipant.user_id == user.id))
    if conv is None or member is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Suhbat topilmadi")
    return conv


async def blocked_conversation(db: AsyncSession, conv_id: uuid.UUID, user_id: uuid.UUID) -> bool:
    others = (await db.scalars(select(ConversationParticipant.user_id).where(
        ConversationParticipant.conversation_id == conv_id, ConversationParticipant.user_id != user_id))).all()
    for o in others:
        if await block_service.between(db, user_id, o):
            return True
    return False


async def my_part(db: AsyncSession, conv_id: uuid.UUID, user: User) -> ConversationParticipant:
    part = await db.scalar(select(ConversationParticipant).where(
        ConversationParticipant.conversation_id == conv_id, ConversationParticipant.user_id == user.id))
    if part is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Suhbat topilmadi")
    return part


async def conv_out(db: AsyncSession, conv: Conversation, me: User) -> ConversationOut:
    users = (await db.scalars(select(User).join(ConversationParticipant, ConversationParticipant.user_id == User.id)
                              .where(ConversationParticipant.conversation_id == conv.id))).all()
    last = await db.scalar(select(Message).where(Message.conversation_id == conv.id).order_by(Message.created_at.desc()).limit(1))
    others = [u for u in users if u.id != me.id]
    blocked = bool(others) and await block_service.between(db, me.id, others[0].id)
    unread = await db.scalar(select(func.count()).select_from(Message).where(
        Message.conversation_id == conv.id, Message.sender_id != me.id, Message.is_read.is_(False))) or 0
    muted = bool(await db.scalar(select(ConversationParticipant.muted).where(
        ConversationParticipant.conversation_id == conv.id, ConversationParticipant.user_id == me.id)))
    return ConversationOut(
        id=conv.id, participants=[UserPublic.model_validate(u) for u in users if u.id != me.id],
        last_message=MessageOut.of(last) if last else None, unread_count=unread, updated_at=conv.updated_at,
        blocked=blocked, muted=muted,
    )


@router.get("/conversations", response_model=list[ConversationOut])
async def list_conversations(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    # TZ S15: o'z ro'yxatidan yashirilgan suhbat yangi xabar kelguncha ko'rinmaydi
    stmt = (select(Conversation).join(ConversationParticipant, ConversationParticipant.conversation_id == Conversation.id)
            .where(ConversationParticipant.user_id == user.id,
                   (ConversationParticipant.hidden_at.is_(None)) | (Conversation.updated_at > ConversationParticipant.hidden_at))
            .order_by(Conversation.updated_at.desc()))
    convs = (await db.scalars(stmt)).all()
    await chat_service.mark_delivered(db, user.id, [c.id for c in convs])
    return [await conv_out(db, c, user) for c in convs]


@router.post("/conversations", response_model=ConversationOut, status_code=201)
async def start_conversation(body: ConversationIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if body.user_id == user.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "O'zingiz bilan suhbat ochib bo'lmaydi")
    other = await db.get(User, body.user_id)
    if other is None or not other.is_active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Foydalanuvchi topilmadi")
    if await block_service.between(db, user.id, other.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, block_service.BLOCKED_MSG)
    # Mavjud 1:1 suhbatni qayta ishlatamiz
    mine = select(ConversationParticipant.conversation_id).where(ConversationParticipant.user_id == user.id)
    existing = await db.scalar(select(Conversation).join(ConversationParticipant, ConversationParticipant.conversation_id == Conversation.id)
                               .where(ConversationParticipant.user_id == other.id, Conversation.id.in_(mine)).limit(1))
    if existing:
        part = await my_part(db, existing.id, user)
        if part.hidden_at is not None:  # yashirilgan suhbat qayta ochildi
            part.hidden_at = None
            await db.commit()
        return await conv_out(db, existing, user)
    conv = Conversation()
    db.add(conv)
    await db.flush()
    db.add_all([ConversationParticipant(conversation_id=conv.id, user_id=user.id),
                ConversationParticipant(conversation_id=conv.id, user_id=other.id)])
    await db.commit()
    return await conv_out(db, conv, user)


@router.get("/conversations/{conv_id}/messages", response_model=list[MessageOut])
async def list_messages(conv_id: uuid.UUID, limit: int = 100, before: uuid.UUID | None = None,
                        user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Oxirgi `limit` ta xabar (eskidan yangiga). `before` — shu xabardan oldingilari (QA09: eski xabarlar sahifasi)."""
    await ensure_member(db, conv_id, user)
    stmt = select(Message).where(Message.conversation_id == conv_id).order_by(Message.created_at.desc(), Message.id.desc()).limit(min(limit, 500))
    if before is not None:
        pivot = await db.get(Message, before)
        if pivot is None or pivot.conversation_id != conv_id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Xabar topilmadi")
        stmt = stmt.where(Message.created_at < pivot.created_at)
    rows = list(reversed((await db.scalars(stmt)).all()))
    if any(m.sender_id != user.id and m.delivered_at is None for m in rows):
        await chat_service.mark_delivered(db, user.id, [conv_id])
        for m in rows:
            await db.refresh(m)
    return [MessageOut.of(m) for m in rows]


@router.post("/conversations/{conv_id}/messages", response_model=MessageOut, status_code=201)
async def send_message(conv_id: uuid.UUID, body: MessageIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await ensure_member(db, conv_id, user)
    if await blocked_conversation(db, conv_id, user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, block_service.BLOCKED_MSG)
    images = body.image_urls if body.image_urls is not None else ([body.image_url] if body.image_url else [])
    if not (body.content or "").strip() and not images:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Bo'sh xabar")
    msg = await save_message(db, conv_id, user.id, (body.content or "").strip() or None, images)
    await db.commit()
    return MessageOut.of(msg)


@router.put("/messages/{message_id}/read", response_model=MessageOut)
async def mark_read(message_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    msg = await db.get(Message, message_id)
    if msg is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Xabar topilmadi")
    await ensure_member(db, msg.conversation_id, user)
    if msg.sender_id != user.id:
        # shu xabargacha bo'lgan barcha xabarlarni o'qilgan deb belgilaymiz
        await chat_service.mark_read(db, user.id, msg.conversation_id, until=msg.created_at)
        await db.refresh(msg)
    return MessageOut.of(msg)


@router.put("/conversations/{conv_id}/read", status_code=204)
async def read_conversation(conv_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """TZ S15 menyusi: o'qilgan deb belgilash."""
    await ensure_member(db, conv_id, user)
    await chat_service.mark_read(db, user.id, conv_id)


class MuteIn(BaseModel):
    muted: bool


@router.put("/conversations/{conv_id}/mute", response_model=ConversationOut)
async def mute_conversation(conv_id: uuid.UUID, body: MuteIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """TZ S15/S16: ovozsiz — bu suhbatdan bildirishnoma kelmaydi."""
    conv = await ensure_member(db, conv_id, user)
    part = await my_part(db, conv_id, user)
    part.muted = body.muted
    await db.commit()
    return await conv_out(db, conv, user)


@router.delete("/conversations/{conv_id}", status_code=204)
async def hide_conversation(conv_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """TZ S15: suhbatni faqat o'z ro'yxatidan yashirish. Boshqa ishtirokchi xabarlari o'chmaydi;
    yangi xabar kelsa suhbat qayta paydo bo'ladi."""
    await ensure_member(db, conv_id, user)
    part = await my_part(db, conv_id, user)
    part.hidden_at = utcnow()
    await db.commit()
