from fastapi import APIRouter

from app.api.v1 import (
    admin, ai, auth, catalog, chat, community, crops, dataset, diagnoses, notifications, reminders, reports, subscriptions,
    payments, uploads, users,
)

api_router = APIRouter(prefix="/api/v1")
for r in (auth, users, catalog, crops, diagnoses, community, chat, reminders, notifications, ai, reports,
          subscriptions, admin, uploads, payments):
    api_router.include_router(r.router)
api_router.include_router(dataset.router)
api_router.include_router(dataset.download_router)
