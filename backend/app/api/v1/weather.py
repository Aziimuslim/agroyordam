import httpx
from fastapi import APIRouter, Depends, HTTPException, status

from app.core.deps import get_current_user
from app.models import User
from app.services.weather import as_dict, get_weather

router = APIRouter(prefix="/weather", tags=["Ob-havo"])


@router.get("")
async def weather(region: str | None = None, user: User = Depends(get_current_user)):
    """Foydalanuvchi viloyati (yoki ?region=) bo'yicha ob-havo va zamburug' kasalliklari xavfi."""
    try:
        return as_dict(await get_weather(region or user.region))
    except (httpx.HTTPError, KeyError, ValueError) as exc:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Ob-havo ma'lumoti vaqtincha mavjud emas") from exc
