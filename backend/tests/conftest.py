import io
import os
import tempfile

_tmp = tempfile.mkdtemp()
os.environ.update({
    "DATABASE_URL": f"sqlite+aiosqlite:///{_tmp}/test.db",
    "ENVIRONMENT": "test",
    "BCRYPT_ROUNDS": "4",
    "MEDIA_ROOT": f"{_tmp}/media",
    "PAYMENT_MODE": "sandbox",
})

import pytest  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from PIL import Image  # noqa: E402

import app.models  # noqa: E402,F401
from app.core.database import Base, SessionLocal, engine  # noqa: E402
from app.core.rate_limit import limiter  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.main import app  # noqa: E402
from app.models import User  # noqa: E402
from app.seed import seed_catalog  # noqa: E402
from app.services import ai_client  # noqa: E402
from app.services.ai_client import Prediction  # noqa: E402


class FakeAI:
    """AI service kontraktini taqlid qiladi; testlar natijani `next` orqali belgilaydi."""

    def __init__(self):
        self.next = Prediction("Pomidor", "Tomato_Late_blight", 91.5, True)

    async def predict(self, image, filename, content_type, plant_hint=None):
        self.last_hint = plant_hint
        return self.next


@pytest.fixture
def fake_ai(monkeypatch):
    fake = FakeAI()
    monkeypatch.setattr(ai_client, "_client", fake)
    return fake


@pytest.fixture(autouse=True)
async def db_reset():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    async with SessionLocal() as db:
        await seed_catalog(db)
        await db.commit()
    limiter.reset()
    yield


@pytest.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


async def register(client, username="farmer", **extra):
    body = {"full_name": "Test Fermer", "username": username, "email": f"{username}@test.uz", "password": "Secret123!"}
    body.update(extra)
    r = await client.post("/api/v1/auth/register", json=body)
    assert r.status_code == 201, r.text
    return r.json()


def auth(tokens):
    return {"Authorization": f"Bearer {tokens['access_token']}"}


@pytest.fixture
async def user_headers(client):
    return auth(await register(client))


@pytest.fixture
async def admin_headers(client):
    async with SessionLocal() as db:
        db.add(User(full_name="Admin", username="admin", email="admin@test.uz",
                    password_hash=hash_password("Admin12345!"), role="admin"))
        await db.commit()
    r = await client.post("/api/v1/auth/login", json={"login": "admin", "password": "Admin12345!"})
    return auth(r.json())


def image_bytes(fmt="PNG") -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (300, 300), (60, 140, 50)).save(buf, fmt)
    return buf.getvalue()
