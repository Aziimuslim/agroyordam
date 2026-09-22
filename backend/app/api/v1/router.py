from fastapi import APIRouter

from app.api.v1 import (
    admin, ai, auth, catalog, chat, community, crops, diagnoses, notifications, reminders, reports, subscriptions,
    uploads, users,
)

api_router = APIRouter(prefix="/api/v1")
for r in (auth, users, catalog, crops, diagnoses, community, chat, reminders, notifications, ai, reports,
          subscriptions, admin, uploads):
    api_router.include_router(r.router)
