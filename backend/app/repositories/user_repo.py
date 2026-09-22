from sqlalchemy import or_, select

from app.models import User
from app.repositories.base import Repository


class UserRepository(Repository[User]):
    model = User

    async def by_login(self, login: str) -> User | None:
        login = login.strip()
        stmt = select(User).where(or_(User.username == login, User.email == login.lower(), User.phone == login))
        return await self.db.scalar(stmt)

    async def exists(self, *, username: str | None = None, email: str | None = None, phone: str | None = None) -> str | None:
        for field, value in (("username", username), ("email", email), ("phone", phone)):
            if value and await self.db.scalar(select(User.id).where(getattr(User, field) == value)):
                return field
        return None
