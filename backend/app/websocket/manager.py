import asyncio
import logging
from collections import defaultdict

from fastapi import WebSocket

log = logging.getLogger(__name__)


class Hub:
    """Kalit (conversation_id yoki user_id) bo'yicha ulangan WebSocket'lar."""

    def __init__(self) -> None:
        self._conns: dict[str, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, key: str, ws: WebSocket) -> None:
        async with self._lock:
            self._conns[key].add(ws)

    async def disconnect(self, key: str, ws: WebSocket) -> None:
        async with self._lock:
            self._conns[key].discard(ws)
            if not self._conns[key]:
                self._conns.pop(key, None)

    async def send(self, key: str, payload: dict) -> None:
        dead = []
        for ws in list(self._conns.get(key, ())):
            try:
                await ws.send_json(payload)
            except Exception:  # pragma: no cover - uzilgan ulanish
                dead.append(ws)
        for ws in dead:
            await self.disconnect(key, ws)

    def online(self, key: str) -> bool:
        return bool(self._conns.get(key))


chat_hub = Hub()
notifications_hub = Hub()
