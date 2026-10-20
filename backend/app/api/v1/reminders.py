import calendar
import uuid
from datetime import date, timedelta
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models import Crop, Diagnosis, Reminder, User
from app.core.security import utcnow
from app.schemas.reminder import MAX_OCCURRENCES, ReminderIn, ReminderOut, ReminderUpdate, check_repeat_rule

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
    else:
        # TZ S02: arxivlangan ekinning vazifalari umumiy ro'yxatdan chiqadi (tarix ekin sahifasida qoladi)
        archived = select(Crop.id).where(Crop.user_id == user.id, Crop.status == "archived")
        stmt = stmt.where((Reminder.crop_id.is_(None)) | (Reminder.crop_id.not_in(archived)))
    if date_from:
        stmt = stmt.where(Reminder.reminder_date >= date_from)
    if date_to:
        stmt = stmt.where(Reminder.reminder_date <= date_to)
    return [await rem_out(db, r) for r in (await db.scalars(stmt)).all()]


def occurrences(start: date, repeat: str | None, every: int | None, until: date | None) -> list[date]:
    """Takrorlanish sanalari. Oylikda oy 31 kunsiz bo'lsa — oyning oxirgi kuni (TZ S26)."""
    if not repeat or until is None:
        return [start]
    out: list[date] = []
    i = 0
    while len(out) < MAX_OCCURRENCES:
        if repeat == "monthly":
            m = start.month - 1 + i
            y, m = start.year + m // 12, m % 12 + 1
            d = date(y, m, min(start.day, calendar.monthrange(y, m)[1]))
        else:
            step = {"daily": 1, "weekly": 7}.get(repeat, every or 1)
            d = start + timedelta(days=step * i)
        if d > until:
            break
        out.append(d)
        i += 1
    return out


@router.post("", response_model=ReminderOut, status_code=201)
async def create_reminder(body: ReminderIn, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Bitta vazifa yoki takrorlanuvchi seriya (har sana — alohida yozuv, umumiy series_id). Birinchisi qaytadi."""
    await check_refs(db, user, body.crop_id, body.diagnosis_id)
    data = body.model_dump()
    dates = occurrences(body.reminder_date, body.repeat, body.repeat_every, body.repeat_until)
    series = uuid.uuid4() if len(dates) > 1 else None
    if series is None:
        data.update(repeat=None, repeat_every=None, repeat_until=None)
    rows = [Reminder(user_id=user.id, **{**data, "reminder_date": d, "series_id": series}) for d in dates]
    db.add_all(rows)
    await db.commit()
    await db.refresh(rows[0])
    return await rem_out(db, rows[0])


@router.get("/{rid}", response_model=ReminderOut)
async def get_reminder(rid: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await rem_out(db, await own(db, rid, user))


def _series_scope(r: Reminder, scope: str):
    """scope=future: shu va keyingi (sanasi ≥) occurrence'lar; aks holda faqat shu yozuv."""
    if scope == "future" and r.series_id:
        return (Reminder.series_id == r.series_id, Reminder.reminder_date >= r.reminder_date)
    return (Reminder.id == r.id,)


@router.put("/{rid}", response_model=ReminderOut)
async def update_reminder(rid: uuid.UUID, body: ReminderUpdate, scope: Literal["one", "future"] = Query(default="one"),
                          user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    r = await own(db, rid, user)
    data = body.model_dump(exclude_unset=True)
    await check_refs(db, user, data.get("crop_id"), None)
    if "repeat" in data:
        return await _reschedule(db, user, r, data)
    if scope == "future" and r.series_id:
        # Seriyada sana har occurrence'ning o'zida qoladi; qolgan maydonlar keyingilarga ham yoziladi
        shared = {k: v for k, v in data.items() if k not in ("reminder_date", "is_completed")}
        for x in (await db.scalars(select(Reminder).where(*_series_scope(r, scope)))).all():
            for k, v in shared.items():
                setattr(x, k, v)
        for k in ("reminder_date", "is_completed"):
            if k in data:
                setattr(r, k, data[k])
    else:
        for k, v in data.items():
            setattr(r, k, v)
    if "is_completed" in data:
        r.completed_at = utcnow() if r.is_completed else None
    await db.commit()
    await db.refresh(r)
    return await rem_out(db, r)


async def _reschedule(db: AsyncSession, user: User, r: Reminder, data: dict) -> ReminderOut:
    """TZ S26: takrorlash qoidasi o'zgardi — shu vazifa va keyingi bajarilmagan takrorlar yangi qoida bo'yicha.
    Oldingi sanalar va bajarilganlari eski seriyada (tarix) qoladi."""
    rule = {k: data.pop(k, None) for k in ("repeat", "repeat_every", "repeat_until")}
    data.pop("is_completed", None)
    start = data.get("reminder_date", r.reminder_date)
    try:
        check_repeat_rule(start, rule["repeat"], rule["repeat_every"], rule["repeat_until"])
    except ValueError as e:
        raise HTTPException(422, str(e))
    if r.series_id:
        await db.execute(delete(Reminder).where(
            Reminder.user_id == user.id, Reminder.series_id == r.series_id, Reminder.id != r.id,
            Reminder.reminder_date >= r.reminder_date, Reminder.is_completed.is_(False)))
    for k, v in data.items():
        setattr(r, k, v)
    dates = occurrences(start, rule["repeat"], rule["repeat_every"], rule["repeat_until"])
    series = uuid.uuid4() if len(dates) > 1 else None
    r.reminder_date, r.series_id = dates[0], series
    r.repeat, r.repeat_every, r.repeat_until = (rule["repeat"], rule["repeat_every"], rule["repeat_until"]) if series else (None, None, None)
    copy = ("crop_id", "diagnosis_id", "title", "description", "reminder_type", "reminder_time", "remind_before",
            "repeat", "repeat_every", "repeat_until")
    for d in dates[1:]:
        db.add(Reminder(user_id=user.id, reminder_date=d, series_id=series, **{k: getattr(r, k) for k in copy}))
    await db.commit()
    await db.refresh(r)
    return await rem_out(db, r)


@router.put("/{rid}/complete", response_model=ReminderOut)
async def complete_reminder(rid: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    r = await own(db, rid, user)
    r.is_completed = not r.is_completed
    r.completed_at = utcnow() if r.is_completed else None
    # Parvarish vazifasi bajarilsa ekin sog'lig'i biroz yaxshilanadi
    if r.is_completed and r.crop_id:
        crop = await db.get(Crop, r.crop_id)
        if crop:
            crop.health_score = min(100, crop.health_score + 3)
    await db.commit()
    await db.refresh(r)
    return await rem_out(db, r)


@router.delete("/{rid}", status_code=204)
async def delete_reminder(rid: uuid.UUID, scope: Literal["one", "future"] = Query(default="one"),
                          user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    r = await own(db, rid, user)
    await db.execute(delete(Reminder).where(Reminder.user_id == user.id, *_series_scope(r, scope)))
    await db.commit()
