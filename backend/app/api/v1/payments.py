"""To'lov provayderlari chaqiradigan endpointlar (foydalanuvchi emas, Payme/Click serverlari)."""
import json

from fastapi import APIRouter, Depends, Header, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.services import click_shop, payme_merchant
from app.services.payme_merchant import PaymeError

router = APIRouter(prefix="/payments", tags=["Payments (provider callbacks)"])


@router.post("/payme")
async def payme(request: Request, authorization: str | None = Header(default=None), db: AsyncSession = Depends(get_db)):
    try:
        body = json.loads(await request.body())
    except ValueError:
        return payme_merchant.error_response(None, -32700)
    req_id = body.get("id") if isinstance(body, dict) else None
    if not payme_merchant.check_auth(authorization):
        return payme_merchant.error_response(req_id, payme_merchant.AUTH_FAILED)
    handler = payme_merchant.METHODS.get(body.get("method"))
    if handler is None:
        return payme_merchant.error_response(req_id, payme_merchant.METHOD_NOT_FOUND)
    try:
        result = await handler(db, body.get("params") or {})
    except PaymeError as e:
        await db.rollback()
        return payme_merchant.error_response(req_id, e.code, e.data)
    await db.commit()
    return {"jsonrpc": "2.0", "id": req_id, "result": result}


async def _form(request: Request) -> dict:
    return {k: v for k, v in (await request.form()).items()}


@router.post("/click/prepare")
async def click_prepare(request: Request, db: AsyncSession = Depends(get_db)):
    result = await click_shop.prepare(db, await _form(request))
    await db.commit()
    return result


@router.post("/click/complete")
async def click_complete(request: Request, db: AsyncSession = Depends(get_db)):
    result = await click_shop.complete(db, await _form(request))
    await db.commit()
    return result
