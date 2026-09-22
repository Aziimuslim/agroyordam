"""APScheduler vazifalari: eslatma bildirishnomalari va obuna muddati tekshiruvi."""
import logging
from datetime import datetime

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy import and_, select

from app.core.database import SessionLocal
from app.core.security import utcnow
from app.models import Notification, Reminder, Subscription, User
from app.services.notification_service import notify

log = logging.getLogger(__name__)
_scheduler = AsyncIOScheduler(timezone="UTC")


async def send_due_reminders() -> int:
    now = utcnow()
    sent = 0
    async with SessionLocal() as db:
        due = (await db.scalars(select(Reminder).where(
            Reminder.is_completed.is_(False), Reminder.reminder_date <= now.date()))).all()
        for r in due:
            if r.reminder_date == now.date() and r.reminder_time and datetime.combine(r.reminder_date, r.reminder_time) > now:
                continue
            already = await db.scalar(select(Notification.id).where(
                and_(Notification.reference_id == r.id, Notification.type == "reminder")))
            if already:
                continue
            await notify(db, r.user_id, "reminder", r.title, r.description or "Vazifa vaqti keldi", r.id)
            sent += 1
        await db.commit()
    return sent


async def expire_subscriptions() -> int:
    now = utcnow()
    n = 0
    async with SessionLocal() as db:
        subs = (await db.scalars(select(Subscription).where(
            Subscription.status.in_(("active", "cancelled")), Subscription.expires_at.is_not(None),
            Subscription.expires_at < now))).all()
        for s in subs:
            s.status = "expired"
            n += 1
        users = (await db.scalars(select(User).where(User.is_premium.is_(True), User.premium_until < now))).all()
        for u in users:
            u.is_premium = False
            await notify(db, u.id, "subscription", "Premium muddati tugadi", "Premium imkoniyatlarni davom ettirish uchun obunani yangilang")
        await db.commit()
    return n


def start() -> None:
    _scheduler.add_job(send_due_reminders, "interval", minutes=5, id="reminders", replace_existing=True)
    _scheduler.add_job(expire_subscriptions, "interval", hours=1, id="subscriptions", replace_existing=True)
    _scheduler.start()
    log.info("Scheduler ishga tushdi")


def stop() -> None:
    if _scheduler.running:
        _scheduler.shutdown(wait=False)
