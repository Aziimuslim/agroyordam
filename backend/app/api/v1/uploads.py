from fastapi import APIRouter, Depends, File, Query, UploadFile

from app.core.deps import get_current_user
from app.models import User
from app.services.storage import get_storage, read_image

router = APIRouter(prefix="/uploads", tags=["Uploads"])


@router.post("", status_code=201)
async def upload(file: UploadFile = File(...), folder: str = Query(default="posts", pattern="^(posts|messages|crops|catalog)$"),
                 _: User = Depends(get_current_user)):
    """Post/xabar/katalog rasmlari uchun umumiy yuklash (image_url qaytaradi)."""
    data, ext = await read_image(file)
    return {"url": get_storage().save(data, ext, folder)}
