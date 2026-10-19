"""A02 Saqlanganlar."""
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import Bookmark, Disease, Medicine, Plant, Post, User
from app.services.block_service import hidden_ids

router = APIRouter(prefix="/bookmarks", tags=["Bookmarks"])
KINDS = {"post": Post, "plant": Plant, "disease": Disease, "medicine": Medicine}


class BookmarkIn(BaseModel):
    kind: str = Field(pattern=r"^(post|plant|disease|medicine)$")
    target_id: uuid.UUID


class BookmarkOut(BaseModel):
    kind: str
    target_id: uuid.UUID
    exists: bool  # obyekt o'chirilgan bo'lsa false — ilova placeholder ko'rsatadi
    title: str | None = None
    subtitle: str | None = None
    image_url: str | None = None
    ai_label: str | None = None  # kasallik: ilovadagi katalog rasmi uchun
    created_at: str | None = None


async def _out(db: AsyncSession, b: Bookmark, hidden: set[uuid.UUID]) -> BookmarkOut:
    obj = await db.get(KINDS[b.kind], b.target_id)
    if obj is not None and b.kind == "post" and obj.user_id in hidden:
        obj = None  # bloklangan muallif posti ko'rsatilmaydi
    base = dict(kind=b.kind, target_id=b.target_id, created_at=b.created_at.isoformat() if b.created_at else None)
    if obj is None:
        return BookmarkOut(**base, exists=False)
    match b.kind:
        case "post":
            return BookmarkOut(**base, exists=True, title=obj.title, subtitle=(obj.content or "")[:140], image_url=obj.image_url)
        case "plant":
            return BookmarkOut(**base, exists=True, title=obj.name, subtitle=obj.scientific_name, image_url=obj.image_url)
        case "disease":
            return BookmarkOut(**base, exists=True, title=obj.name, subtitle=(obj.symptoms or obj.description or "")[:140], image_url=obj.image_url,
                               ai_label=obj.ai_label)
        case _:
            return BookmarkOut(**base, exists=True, title=obj.name, subtitle=obj.active_ingredient, image_url=obj.image_url)


@router.get("", response_model=list[BookmarkOut])
async def list_bookmarks(kind: str | None = Query(default=None, pattern=r"^(post|plant|disease|medicine)$"),
                         user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(Bookmark).where(Bookmark.user_id == user.id).order_by(Bookmark.created_at.desc())
    if kind:
        stmt = stmt.where(Bookmark.kind == kind)
    hidden = await hidden_ids(db, user.id)
    return [await _out(db, b, hidden) for b in (await db.scalars(stmt)).all()]


@router.post("", response_model=BookmarkOut, status_code=201)
async def add_bookmark(body: BookmarkIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if await db.get(KINDS[body.kind], body.target_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Topilmadi")
    b = await db.scalar(select(Bookmark).where(Bookmark.user_id == user.id, Bookmark.kind == body.kind, Bookmark.target_id == body.target_id))
    if b is None:  # ikki marta bosish bitta yozuv
        b = Bookmark(user_id=user.id, kind=body.kind, target_id=body.target_id)
        db.add(b)
        await db.commit()
        await db.refresh(b)
    return await _out(db, b, await hidden_ids(db, user.id))


@router.delete("/{kind}/{target_id}", status_code=204)
async def remove_bookmark(kind: str, target_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    b = await db.scalar(select(Bookmark).where(Bookmark.user_id == user.id, Bookmark.kind == kind, Bookmark.target_id == target_id))
    if b is not None:
        await db.delete(b)
        await db.commit()
