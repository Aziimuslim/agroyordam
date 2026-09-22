import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status


class SlidingWindowLimiter:
    """Oddiy in-memory limiter (bitta instansiya uchun). Ko'p instansiyada Redis'ga almashtiriladi."""

    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def hit(self, key: str, limit: int, window_seconds: int) -> bool:
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


limiter = SlidingWindowLimiter()


def client_ip(request: Request) -> str:
    fwd = request.headers.get("x-forwarded-for")
    if fwd:
        return fwd.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def enforce(key: str, limit: int, window_seconds: int = 60) -> None:
    if not limiter.hit(key, limit, window_seconds):
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Juda ko'p urinish. Birozdan so'ng qayta urinib ko'ring.")
