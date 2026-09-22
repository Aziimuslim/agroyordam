"""Rate limiting: REDIS_URL berilsa — Redis (ko'p instansiya uchun), aks holda in-memory."""
import logging
import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status

from app.core.config import settings

log = logging.getLogger(__name__)


class SlidingWindowLimiter:
    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    async def hit(self, key: str, limit: int, window_seconds: int) -> bool:
        now = time.monotonic()
        q = self._hits[key]
        while q and now - q[0] > window_seconds:
            q.popleft()
        if len(q) >= limit:
            return False
        q.append(now)
        return True

    def reset(self) -> None:
        self._hits.clear()


class RedisLimiter:
    """Fixed-window hisoblagich: INCR + EXPIRE."""

    def __init__(self, url: str) -> None:
        import redis.asyncio as redis

        self.r = redis.from_url(url)

    async def hit(self, key: str, limit: int, window_seconds: int) -> bool:
        bucket = f"rl:{key}:{int(time.time() // window_seconds)}"
        try:
            n = await self.r.incr(bucket)
            if n == 1:
                await self.r.expire(bucket, window_seconds)
            return n <= limit
        except Exception as exc:  # pragma: no cover - Redis ishlamasa so'rovni bloklamaymiz
            log.warning("Redis limiter xatosi: %s", exc)
            return True

    def reset(self) -> None:  # pragma: no cover
        pass


limiter = RedisLimiter(settings.REDIS_URL) if settings.REDIS_URL else SlidingWindowLimiter()


def client_ip(request: Request) -> str:
    fwd = request.headers.get("x-forwarded-for")
    if fwd:
        return fwd.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


async def enforce(key: str, limit: int, window_seconds: int = 60) -> None:
    if not await limiter.hit(key, limit, window_seconds):
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Juda ko'p urinish. Birozdan so'ng qayta urinib ko'ring.")
