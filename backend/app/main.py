import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.database import Base, engine
from app.websocket import chat_ws, notifications_ws

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")


@asynccontextmanager
async def lifespan(app: FastAPI):
    if settings.DATABASE_URL.startswith("sqlite"):
        # Dev rejimi: SQLite'da jadvallarni avtomatik yaratamiz (PostgreSQL'da — Alembic)
        import app.models  # noqa: F401

        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    if settings.ENVIRONMENT != "test":
        from app.seed import run_seed

        await run_seed()
        if settings.ENABLE_SCHEDULER:
            from app.tasks import scheduler

            scheduler.start()
    yield
    if settings.ENVIRONMENT != "test" and settings.ENABLE_SCHEDULER:
        from app.tasks import scheduler

        scheduler.stop()


app = FastAPI(
    title="AgroYordam API",
    version=settings.APP_VERSION,
    description="AI yordamida ekin kasalliklarini tashxislash platformasi",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?" if settings.ENVIRONMENT != "production" else None,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(api_router)
app.include_router(chat_ws.router)
app.include_router(notifications_ws.router)

if settings.STORAGE_BACKEND == "local":
    Path(settings.MEDIA_ROOT).mkdir(parents=True, exist_ok=True)
    app.mount(settings.MEDIA_URL, StaticFiles(directory=settings.MEDIA_ROOT), name="media")


@app.get("/health", tags=["System"])
async def health():
    from sqlalchemy import text

    db_ok = True
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception:  # pragma: no cover
        db_ok = False
    return {"status": "ok" if db_ok else "degraded", "version": settings.APP_VERSION, "database": db_ok}
