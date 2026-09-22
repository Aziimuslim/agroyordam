import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import Crop, Diagnosis, Reminder, User
from app.schemas.reminder import ReminderIn, ReminderOut, ReminderUpdate

router = APIRouter(prefix="/reminders", tags=["Reminders"])


async def rem_out(db: AsyncSession, r: Reminder) -> ReminderOut:
    crop = await db.get(Crop, r.crop_id) if r.crop_id else None
    return ReminderOut.model_validate(r).model_copy(update={"crop_name": crop.name if crop else None})


async def own(db: AsyncSession, rid: uuid.UUID, user: User) -> Reminder:
    r = await db.get(Reminder, rid)
    if r is None or r.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Eslatma topilmadi")
    return r


async def check_refs(db: AsyncSession, user: User, crop_id, diagnosis_id) -> None:
    if crop_id:
        c = await db.get(Crop, crop_id)
        if c is None or c.user_id != user.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Ekin topilmadi")
    if diagnosis_id:
        d = await db.get(Diagnosis, diagnosis_id)
        if d is None or d.user_id != user.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Tashxis topilmadi")


@router.get("", response_model=list[ReminderOut])
async def list_reminders(
    completed: bool | None = None, reminder_type: str | None = None, crop_id: uuid.UUID | None = None,
    date_from: date | None = None, date_to: date | None = None,
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db),
):
    stmt = select(Reminder).where(Reminder.user_id == user.id).order_by(Reminder.is_completed, Reminder.reminder_date, Reminder.reminder_time)
    if completed is not None:
        stmt = stmt.where(Reminder.is_completed.is_(completed))
    if reminder_type:
        stmt = stmt.where(Reminder.reminder_type == reminder_type)
    if crop_id:
        stmt = stmt.where(Reminder.crop_id == crop_id)
    if date_from:
        stmt = stmt.where(Reminder.reminder_date >= date_from)
    if date_to:
        stmt = stmt.where(Reminder.reminder_date <= date_to)
    return [await rem_out(db, r) for r in (await db.scalars(stmt)).all()]


@router.post("", response_model=ReminderOut, status_code=201)
async def create_reminder(body: ReminderIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await check_refs(db, user, body.crop_id, body.diagnosis_id)
    r = Reminder(user_id=user.id, **body.model_dump())
    db.add(r)
    await db.commit()
    await db.refresh(r)
    return await rem_out(db, r)


@router.put("/{rid}", response_model=ReminderOut)
async def update_reminder(rid: uuid.UUID, body: ReminderUpdate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    r = await own(db, rid, user)
    data = body.model_dump(exclude_unset=True)
    await check_refs(db, user, data.get("crop_id"), None)
    for k, v in data.items():
        setattr(r, k, v)
    await db.commit()
    await db.refresh(r)
    return await rem_out(db, r)


@router.put("/{rid}/complete", response_model=ReminderOut)
async def complete_reminder(rid: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    r = await own(db, rid, user)
    r.is_completed = not r.is_completed
    # Parvarish vazifasi bajarilsa ekin sog'lig'i biroz yaxshilanadi
    if r.is_completed and r.crop_id:
        crop = await db.get(Crop, r.crop_id)
        if crop:
            crop.health_score = min(100, crop.health_score + 3)
    await db.commit()
    await db.refresh(r)
    return await rem_out(db, r)


@router.delete("/{rid}", status_code=204)
async def delete_reminder(rid: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await db.delete(await own(db, rid, user))
    await db.commit()
