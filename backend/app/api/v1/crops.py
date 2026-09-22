import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import Crop, CropLog, Diagnosis, Disease, Plant, User
from app.schemas.crop import CropIn, CropLogIn, CropLogOut, CropOut, CropUpdate, HealthPoint
from app.services.limits import ensure_can_add_crop

router = APIRouter(prefix="/crops", tags=["Crops"])


async def own_crop(db: AsyncSession, crop_id: uuid.UUID, user: User) -> Crop:
    c = await db.get(Crop, crop_id)
    if c is None or c.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Ekin topilmadi")
    return c


async def crop_out(db: AsyncSession, c: Crop) -> CropOut:
    plant = await db.get(Plant, c.plant_id) if c.plant_id else None
    last = await db.scalar(
        select(Disease.name).join(Diagnosis, Diagnosis.disease_id == Disease.id)
        .where(Diagnosis.crop_id == c.id).order_by(Diagnosis.diagnosed_at.desc()).limit(1)
    )
    return CropOut.model_validate(c).model_copy(update={"plant_name": plant.name if plant else None, "last_disease": last})


@router.get("", response_model=list[CropOut])
async def list_crops(status_: str | None = Query(default="active", alias="status"),
                     user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(Crop).where(Crop.user_id == user.id).order_by(Crop.created_at.desc())
    if status_:
        stmt = stmt.where(Crop.status == status_)
    return [await crop_out(db, c) for c in (await db.scalars(stmt)).all()]


@router.post("", response_model=CropOut, status_code=201)
async def create_crop(body: CropIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await ensure_can_add_crop(db, user)
    if body.plant_id and await db.get(Plant, body.plant_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "O'simlik turi topilmadi")
    c = Crop(user_id=user.id, **body.model_dump())
    db.add(c)
    await db.commit()
    await db.refresh(c)
    return await crop_out(db, c)


@router.get("/{crop_id}", response_model=CropOut)
async def get_crop(crop_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await crop_out(db, await own_crop(db, crop_id, user))


@router.put("/{crop_id}", response_model=CropOut)
async def update_crop(crop_id: uuid.UUID, body: CropUpdate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    c = await own_crop(db, crop_id, user)
    data = body.model_dump(exclude_unset=True)
    if data.get("status") == "active" and c.status != "active":
        await ensure_can_add_crop(db, user)
    for k, v in data.items():
        setattr(c, k, v)
    await db.commit()
    await db.refresh(c)
    return await crop_out(db, c)


@router.delete("/{crop_id}", status_code=204)
async def delete_crop(crop_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    c = await own_crop(db, crop_id, user)
    await db.delete(c)
    await db.commit()


@router.get("/{crop_id}/health-history", response_model=list[HealthPoint])
async def health_history(crop_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.services.diagnosis_service import health_from

    c = await own_crop(db, crop_id, user)
    rows = (await db.execute(
        select(Diagnosis, Disease).outerjoin(Disease, Disease.id == Diagnosis.disease_id)
        .where(Diagnosis.crop_id == c.id).order_by(Diagnosis.diagnosed_at)
    )).all()
    points = [HealthPoint(date=c.created_at, health_score=100)]
    for diag, disease in rows:
        healthy = disease is None and diag.risk_level == "low"
        score = health_from(disease, healthy, float(diag.confidence or 0))
        if score is not None:
            points.append(HealthPoint(date=diag.diagnosed_at, health_score=score,
                                      disease=disease.name if disease else None, diagnosis_id=diag.id))
    return points


@router.get("/{crop_id}/logs", response_model=list[CropLogOut])
async def list_logs(crop_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await own_crop(db, crop_id, user)
    stmt = select(CropLog).where(CropLog.crop_id == crop_id).order_by(CropLog.created_at.desc())
    return list((await db.scalars(stmt)).all())


@router.post("/{crop_id}/logs", response_model=CropLogOut, status_code=201)
async def add_log(crop_id: uuid.UUID, body: CropLogIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await own_crop(db, crop_id, user)
    log = CropLog(crop_id=crop_id, user_id=user.id, **body.model_dump())
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log
