import logging
import uuid

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models import Notification, User
from app.websocket.manager import notifications_hub

log = logging.getLogger(__name__)


# A05: bildirishnoma turi → foydalanuvchi o'chira oladigan guruh. Ro'yxatda yo'q tur (masalan, parol tiklash
# — xavfsizlik) doim yuboriladi.
CATEGORIES: dict[str, str] = {
    "reminder": "tasks",
    "message": "messages", "question_message": "messages",
    "comment": "community", "like": "community", "follow": "community",
    "subscription": "service", "expert_approved": "service", "expert_rejected": "service", "moderation": "service",
    "broadcast": "service", "diagnosis_ready": "service", "diagnosis_reviewed": "service", "question_closed": "service",
}
DEFAULT_PREFS = {"tasks": True, "messages": True, "community": True, "service": True}


def prefs_of(user: User) -> dict[str, bool]:
    return {**DEFAULT_PREFS, **{k: bool(v) for k, v in (user.notification_prefs or {}).items() if k in DEFAULT_PREFS}}


async def notify(
    db: AsyncSession,
    user_id: uuid.UUID,
    type_: str,
    title: str,
    body: str | None = None,
    reference_id: uuid.UUID | None = None,
) -> Notification | None:
    cat = CATEGORIES.get(type_)
    if cat is not None:
        user = await db.get(User, user_id)
        if user is not None and not prefs_of(user).get(cat, True):
            return None  # foydalanuvchi bu turdagi bildirishnomani o'chirgan
    n = Notification(user_id=user_id, type=type_, title=title, body=body, reference_id=reference_id)
    db.add(n)
    await db.flush()
    await notifications_hub.send(
        str(user_id),
        {
            "event": "notification",
            "data": {"id": str(n.id), "type": type_, "title": title, "body": body,
                     "reference_id": str(reference_id) if reference_id else None},
        },
    )
    await send_push(user_id, title, body)
    return n


async def send_push(user_id: uuid.UUID, title: str, body: str | None) -> None:
    """FCM push. Kalit berilmagan bo'lsa (dev) — faqat log."""
    if not settings.FCM_SERVER_KEY:
        log.debug("FCM o'chirilgan: %s -> %s", user_id, title)
        return
    try:  # pragma: no cover - tashqi servis
        async with httpx.AsyncClient(timeout=5) as c:
            await c.post(
                "https://fcm.googleapis.com/fcm/send",
                headers={"Authorization": f"key={settings.FCM_SERVER_KEY}"},
                json={"to": f"/topics/user_{user_id}", "notification": {"title": title, "body": body or ""}},
            )
    except httpx.HTTPError as exc:  # pragma: no cover
        log.warning("FCM xatosi: %s", exc)
