import uuid

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status

from app.core.security import decode_access_token
from app.websocket.manager import notifications_hub

router = APIRouter()


@router.websocket("/ws/notifications/{user_id}")
async def notifications_ws(websocket: WebSocket, user_id: uuid.UUID, token: str = Query(...)):
    payload = decode_access_token(token)
    if payload is None or payload["sub"] != str(user_id):
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
    await websocket.accept()
    key = str(user_id)
    await notifications_hub.connect(key, websocket)
    try:
        while True:
            await websocket.receive_text()  # ping/keepalive
    except WebSocketDisconnect:
        pass
    finally:
        await notifications_hub.disconnect(key, websocket)
