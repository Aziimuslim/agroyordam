import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import Diagnosis, Disease, Post, User
from app.schemas.community import PostOut
from app.schemas.diagnosis import DiagnosisOut, ShareIn
from app.services.community_service import post_out
from app.services.diagnosis_service import run_diagnosis, to_out

router = APIRouter(prefix="/diagnoses", tags=["Diagnoses"])


async def own(db: AsyncSession, diag_id: uuid.UUID, user: User) -> Diagnosis:
    d = await db.get(Diagnosis, diag_id)
    if d is None or d.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tashxis topilmadi")
    return d


@router.post("", response_model=DiagnosisOut, status_code=201)
async def create_diagnosis(
    image: UploadFile = File(...),
    crop_id: uuid.UUID | None = Form(default=None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await run_diagnosis(db, user, image, crop_id)


@router.get("", response_model=list[DiagnosisOut])
async def list_diagnoses(crop_id: uuid.UUID | None = None, limit: int = 50,
                         user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(Diagnosis).where(Diagnosis.user_id == user.id).order_by(Diagnosis.diagnosed_at.desc()).limit(min(limit, 200))
    if crop_id:
        stmt = stmt.where(Diagnosis.crop_id == crop_id)
    return [await to_out(db, d) for d in (await db.scalars(stmt)).all()]


@router.get("/{diag_id}", response_model=DiagnosisOut)
async def get_diagnosis(diag_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await to_out(db, await own(db, diag_id, user))


@router.delete("/{diag_id}", status_code=204)
async def delete_diagnosis(diag_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await db.delete(await own(db, diag_id, user))
    await db.commit()


@router.post("/{diag_id}/share", response_model=PostOut, status_code=201)
async def share_diagnosis(diag_id: uuid.UUID, body: ShareIn | None = None,
                          user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    d = await own(db, diag_id, user)
    disease = await db.get(Disease, d.disease_id) if d.disease_id else None
    body = body or ShareIn()
    default_title = f"{disease.name} aniqlandi" if disease else "O'simligim sog'lom"
    default_content = (
        f"AI tashxis qo'ydi: {disease.name.lower()}, {float(d.confidence or 0):.0f}% ishonch. {d.recommendations or ''}".strip()
        if disease else "AI tahlili bo'yicha o'simligim sog'lom."
    )
    post = Post(user_id=user.id, diagnosis_id=d.id, title=body.title or default_title,
                content=body.content or default_content, image_url=d.image_url,
                category="disease" if disease else "experience")
    db.add(post)
    await db.commit()
    await db.refresh(post)
    return await post_out(db, post, user)
