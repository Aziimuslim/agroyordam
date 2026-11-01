"""Yangi lotin harflari (ó, ǵ, ş, ç): post, izoh va foydalanuvchi ismi bazaga yozilishidan oldin o'tkaziladi.

Har qanday yo'l (yaratish, tahrirlash, ro'yxatdan o'tish, profil) shu yerdan o'tadi. Login (username, email,
telefon) va shaxsiy xabarlar o'zgarmaydi.
"""
from sqlalchemy import event

from app.core.alphabet import to_new_latin
from app.models.comment import Comment
from app.models.post import Post
from app.models.user import User

FIELDS = {Post: ("title", "content"), Comment: ("content",), User: ("full_name",)}


def _convert(_mapper, _conn, target) -> None:
    for f in FIELDS[type(target)]:
        v = getattr(target, f, None)
        if v:
            nv = to_new_latin(v)
            if nv != v:
                setattr(target, f, nv)


for _model in FIELDS:
    event.listen(_model, "before_insert", _convert)
    event.listen(_model, "before_update", _convert)
