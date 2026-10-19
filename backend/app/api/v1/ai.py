"""AI yordamchi (TZ S09/S10): bir nechta suhbat, oqimli javob (SSE), to'xtatish → qisman javob, qayta javob."""
import asyncio
import json
import uuid
from collections.abc import AsyncIterator

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy import delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import SessionLocal, get_db
from app.core.deps import get_current_user
from app.core.security import utcnow
from app.models import AIChatMessage, AIConversation, User
from app.schemas.ai import AIChatIn, AIChatMessageOut, AIChatReply, AIConversationOut, AIConversationUpdate, AISendIn
from app.services.ai_assistant import answer, answer_stream
from app.services.limits import ensure_can_chat

router = APIRouter(prefix="/ai", tags=["AI Yordamchi"])


def _title(text: str) -> str:
    t = " ".join(text.split())
    if len(t) <= 60:
        return t
    cut = t[:60].rsplit(" ", 1)[0]
    return (cut or t[:60]) + "…"


async def own_conv(db: AsyncSession, conv_id: uuid.UUID, user: User) -> AIConversation:
    c = await db.get(AIConversation, conv_id)
    if c is None or c.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Suhbat topilmadi")
    return c


def _sse(event: str, data) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False, default=str)}\n\n"


async def _save_reply(user_id: uuid.UUID, conv_id: uuid.UUID, reply_to: uuid.UUID, content: str, state: str) -> AIChatMessage:
    async with SessionLocal() as db:
        msg = AIChatMessage(user_id=user_id, conversation_id=conv_id, reply_to_id=reply_to, role="assistant", content=content, status=state)
        db.add(msg)
        conv = await db.get(AIConversation, conv_id)
        if conv is not None:
            conv.updated_at = utcnow()
        await db.commit()
        await db.refresh(msg)
        return msg


async def _stream(user_id: uuid.UUID, conv_id: uuid.UUID, question_msg: AIChatMessage, remaining: int | None,
                  first: list[str]) -> AsyncIterator[str]:
    """`first` — oqim boshida yuboriladigan hodisalar. Mijoz uzilsa/to'xtatsa — shu paytgacha kelgan qism `partial`."""
    chunks: list[str] = []
    finished = False
    try:
        for ev in first:
            yield ev
        async with SessionLocal() as db:
            async for part in answer_stream(db, question_msg.content):
                chunks.append(part)
                yield _sse("delta", {"text": part})
        reply = await _save_reply(user_id, conv_id, question_msg.id, "".join(chunks).strip(), "done")
        finished = True
        yield _sse("done", {"reply": AIChatMessageOut.model_validate(reply).model_dump(mode="json"), "remaining_today": remaining})
    except Exception:  # pragma: no cover - javob tuzishda kutilmagan xato
        if not finished:
            yield _sse("error", {"detail": "AI javob bera olmadi. Qayta urinib ko'ring."})
    finally:
        if not finished and chunks:
            # to'xtatilgan yoki uzilgan oqim: qisman javob tugallangan deb saqlanmaydi
            await asyncio.shield(_save_reply(user_id, conv_id, question_msg.id, "".join(chunks).strip(), "partial"))


def _streaming(gen: AsyncIterator[str]) -> StreamingResponse:
    return StreamingResponse(gen, media_type="text/event-stream", headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})


@router.get("/conversations", response_model=list[AIConversationOut])
async def list_conversations(q: str | None = None, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """TZ S09 tarix menyusi: nomi yoki xabarlari bo'yicha qidiruv."""
    stmt = select(AIConversation).where(AIConversation.user_id == user.id).order_by(AIConversation.updated_at.desc())
    if q and q.strip():
        like = f"%{q.strip()}%"
        stmt = stmt.where(or_(AIConversation.title.ilike(like), AIConversation.id.in_(
            select(AIChatMessage.conversation_id).where(AIChatMessage.user_id == user.id, AIChatMessage.content.ilike(like)))))
    out = []
    for c in (await db.scalars(stmt)).all():
        last = await db.scalar(select(AIChatMessage.content).where(AIChatMessage.conversation_id == c.id)
                               .order_by(AIChatMessage.created_at.desc()).limit(1))
        count = await db.scalar(select(func.count()).select_from(AIChatMessage).where(AIChatMessage.conversation_id == c.id)) or 0
        out.append(AIConversationOut(id=c.id, title=c.title, last_message=(last or "")[:160] or None, message_count=count,
                                     created_at=c.created_at, updated_at=c.updated_at))
    return out


@router.patch("/conversations/{conv_id}", response_model=AIConversationOut)
async def rename_conversation(conv_id: uuid.UUID, body: AIConversationUpdate, user: User = Depends(get_current_user),
                              db: AsyncSession = Depends(get_db)):
    c = await own_conv(db, conv_id, user)
    c.title = body.title
    await db.commit()
    await db.refresh(c)
    return AIConversationOut(id=c.id, title=c.title, created_at=c.created_at, updated_at=c.updated_at)


@router.delete("/conversations/{conv_id}", status_code=204)
async def delete_conversation(conv_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """O'z suhbatini o'chirish (xabarlari bilan). Kunlik limit hisobi o'zgarmaydi."""
    c = await own_conv(db, conv_id, user)
    await db.execute(delete(AIChatMessage).where(AIChatMessage.conversation_id == c.id))
    await db.delete(c)
    await db.commit()


@router.get("/conversations/{conv_id}/messages", response_model=list[AIChatMessageOut])
async def conversation_messages(conv_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await own_conv(db, conv_id, user)
    return (await db.scalars(select(AIChatMessage).where(AIChatMessage.conversation_id == conv_id)
                             .order_by(AIChatMessage.created_at, AIChatMessage.id))).all()


@router.post("/messages")
async def send_message(body: AISendIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """TZ S10: savol saqlanadi (`user` hodisasi — tasdiqlandi), javob `delta` bo'laklari bilan, oxirida `done`.
    Limit va suhbat xatolari oqim boshlanmasdan oddiy HTTP xato bo'lib qaytadi."""
    remaining = await ensure_can_chat(db, user)
    if body.conversation_id:
        conv = await own_conv(db, body.conversation_id, user)
    else:
        conv = AIConversation(user_id=user.id, title=_title(body.message))
        db.add(conv)
        await db.flush()
    msg = AIChatMessage(user_id=user.id, conversation_id=conv.id, role="user", content=body.message)
    db.add(msg)
    conv.updated_at = utcnow()
    await db.commit()
    await db.refresh(msg)
    first = [_sse("user", {"message": AIChatMessageOut.model_validate(msg).model_dump(mode="json"), "conversation_title": conv.title})]
    return _streaming(_stream(user.id, conv.id, msg, remaining, first))


@router.post("/messages/{message_id}/retry")
async def retry_message(message_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Qayta javob: aynan shu savolga bog'langan avvalgi javob(lar) almashtiriladi. Yangi savol emas — limitdan hisoblanmaydi."""
    msg = await db.get(AIChatMessage, message_id)
    if msg is None or msg.user_id != user.id or msg.role != "user" or msg.conversation_id is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Xabar topilmadi")
    await db.execute(delete(AIChatMessage).where(AIChatMessage.reply_to_id == msg.id, AIChatMessage.role == "assistant"))
    await db.commit()
    return _streaming(_stream(user.id, msg.conversation_id, msg, None, []))


# --- Eski ilova versiyalari uchun (bitta tarix) ---

@router.post("/chat", response_model=AIChatReply)
async def chat(body: AIChatIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    remaining = await ensure_can_chat(db, user)
    conv = await db.scalar(select(AIConversation).where(AIConversation.user_id == user.id).order_by(AIConversation.updated_at.desc()).limit(1))
    if conv is None:
        conv = AIConversation(user_id=user.id, title=_title(body.message))
        db.add(conv)
        await db.flush()
    q = AIChatMessage(user_id=user.id, conversation_id=conv.id, role="user", content=body.message)
    db.add(q)
    await db.flush()
    reply = AIChatMessage(user_id=user.id, conversation_id=conv.id, reply_to_id=q.id, role="assistant", content=await answer(db, body.message))
    db.add(reply)
    conv.updated_at = utcnow()
    await db.commit()
    await db.refresh(reply)
    return AIChatReply(reply=AIChatMessageOut.model_validate(reply), remaining_today=remaining)


@router.get("/chat/history", response_model=list[AIChatMessageOut])
async def history(limit: int = 100, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(AIChatMessage).where(AIChatMessage.user_id == user.id).order_by(AIChatMessage.created_at.desc()).limit(min(limit, 500))
    return list(reversed((await db.scalars(stmt)).all()))
