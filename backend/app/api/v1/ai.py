from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import AIChatMessage, User
from app.schemas.ai import AIChatIn, AIChatMessageOut, AIChatReply
from app.services.ai_assistant import answer
from app.services.limits import ensure_can_chat

router = APIRouter(prefix="/ai", tags=["AI Yordamchi"])


@router.post("/chat", response_model=AIChatReply)
async def chat(body: AIChatIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    remaining = await ensure_can_chat(db, user)
    db.add(AIChatMessage(user_id=user.id, role="user", content=body.message.strip()))
    reply = AIChatMessage(user_id=user.id, role="assistant", content=await answer(db, body.message))
    db.add(reply)
    await db.commit()
    await db.refresh(reply)
    return AIChatReply(reply=AIChatMessageOut.model_validate(reply), remaining_today=remaining)


@router.get("/chat/history", response_model=list[AIChatMessageOut])
async def history(limit: int = 100, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(AIChatMessage).where(AIChatMessage.user_id == user.id).order_by(AIChatMessage.created_at.desc()).limit(min(limit, 500))
    return list(reversed((await db.scalars(stmt)).all()))
