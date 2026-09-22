import uuid
from typing import Any, Generic, TypeVar

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import Base

M = TypeVar("M", bound=Base)


class Repository(Generic[M]):
    """Umumiy CRUD. Barcha so'rovlar ORM orqali — xom SQL yo'q."""

    model: type[M]

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get(self, id_: uuid.UUID) -> M | None:
        return await self.db.get(self.model, id_)

    async def list(self, *where: Any, order_by: Any = None, limit: int = 50, offset: int = 0) -> list[M]:
        stmt = select(self.model).where(*where).limit(limit).offset(offset)
        if order_by is not None:
            stmt = stmt.order_by(order_by)
        return list((await self.db.scalars(stmt)).all())

    async def count(self, *where: Any) -> int:
        return (await self.db.scalar(select(func.count()).select_from(self.model).where(*where))) or 0

    async def create(self, **data: Any) -> M:
        obj = self.model(**data)
        self.db.add(obj)
        await self.db.flush()
        return obj

    async def update(self, obj: M, data: dict[str, Any]) -> M:
        for k, v in data.items():
            setattr(obj, k, v)
        await self.db.flush()
        return obj

    async def delete(self, obj: M) -> None:
        await self.db.delete(obj)
        await self.db.flush()
