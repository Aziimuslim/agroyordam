import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_admin
from app.core.security import utcnow
from app.models import Comment, ConversationParticipant, Message, Post, Report, User
from app.services.community_service import remove_comment
from app.schemas.community import ReportIn, ReportOut

router = APIRouter(prefix="/reports", tags=["Reports"])


@router.post("", response_model=ReportOut, status_code=201)
async def create_report(body: ReportIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if sum(x is not None for x in (body.post_id, body.comment_id, body.message_id)) != 1:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "post_id, comment_id yoki message_id kerak")
    if body.message_id:
        msg = await db.get(Message, body.message_id)
        member = msg and await db.scalar(select(ConversationParticipant.id).where(
            ConversationParticipant.conversation_id == msg.conversation_id, ConversationParticipant.user_id == user.id))
        # faqat o'zi qatnashgan suhbatdagi, boshqa odam yozgan xabar
        if msg is None or not member or msg.sender_id == user.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Xabar topilmadi")
    if body.post_id and await db.get(Post, body.post_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Post topilmadi")
    if body.comment_id and await db.get(Comment, body.comment_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Izoh topilmadi")
    # A08: bir obyektga ikkinchi shikoyat yaratilmaydi — avvalgisi qaytadi
    dup = await db.scalar(select(Report).where(
        Report.reporter_id == user.id, Report.status == "pending",
        Report.post_id == body.post_id if body.post_id else Report.post_id.is_(None),
        Report.comment_id == body.comment_id if body.comment_id else Report.comment_id.is_(None),
        Report.message_id == body.message_id if body.message_id else Report.message_id.is_(None)).limit(1))
    if dup is not None:
        return dup
    r = Report(reporter_id=user.id, **body.model_dump())
    db.add(r)
    await db.commit()
    await db.refresh(r)
    return r


@router.get("", response_model=list[ReportOut], dependencies=[Depends(require_admin)])
async def list_reports(status_: str | None = None, db: AsyncSession = Depends(get_db)):
    stmt = select(Report).order_by(Report.created_at.desc())
    if status_:
        stmt = stmt.where(Report.status == status_)
    return list((await db.scalars(stmt)).all())


@router.put("/{rid}/resolve", response_model=ReportOut, dependencies=[Depends(require_admin)])
async def resolve(rid: uuid.UUID, remove_content: bool = False, db: AsyncSession = Depends(get_db)):
    r = await db.get(Report, rid)
    if r is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shikoyat topilmadi")
    r.status = "resolved"
    r.reviewed_at = utcnow()
    await db.flush()
    out = ReportOut.model_validate(r)
    if remove_content:
        target = (await db.get(Comment, r.comment_id) if r.comment_id else await db.get(Post, r.post_id) if r.post_id
                  else await db.get(Message, r.message_id) if r.message_id else None)
        if isinstance(target, Comment):
            await remove_comment(db, target)
        elif target is not None:
            await db.delete(target)  # shikoyat ham cascade bilan o'chadi
    await db.commit()
    return out
