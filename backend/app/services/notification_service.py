import logging
import uuid

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models import Notification
from app.websocket.manager import notifications_hub

log = logging.getLogger(__name__)


async def notify(
    db: AsyncSession,
    user_id: uuid.UUID,
    type_: str,
    title: str,
    body: str | None = None,
    reference_id: uuid.UUID | None = None,
) -> Notification:
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
