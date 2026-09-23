"""Admin hisobini yaratish yoki mavjud foydalanuvchini admin qilish.

    docker compose exec backend python -m app.create_admin --username admin --email admin@domen.uz
(parol so'raladi; yoki --password bilan beriladi)
"""
import argparse
import asyncio
import getpass

from sqlalchemy import select

from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models import User


async def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--username", required=True)
    ap.add_argument("--email")
    ap.add_argument("--full-name", default="Administrator")
    ap.add_argument("--password")
    ap.add_argument("--role", default="admin", choices=["admin", "moderator"])
    a = ap.parse_args()
    password = a.password or getpass.getpass("Parol (kamida 10 belgi): ")
    if len(password) < 10:
        raise SystemExit("Parol juda qisqa")
    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.username == a.username))
        if user is None:
            user = User(username=a.username, email=a.email, full_name=a.full_name, password_hash=hash_password(password))
            db.add(user)
        else:
            user.password_hash = hash_password(password)
        user.role, user.is_active = a.role, True
        await db.commit()
    print(f"OK: {a.username} ({a.role})")


if __name__ == "__main__":
    asyncio.run(main())
