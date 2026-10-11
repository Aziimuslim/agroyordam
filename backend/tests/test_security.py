import uuid

import jwt

from app.core.config import settings
from app.core.security import create_access_token, create_scoped_token, decode_access_token, decode_scoped_token


def test_access_token_roundtrip():
    uid = uuid.uuid4()
    payload = decode_access_token(create_access_token(uid, "farmer"))
    assert payload and payload["sub"] == str(uid) and payload["role"] == "farmer"


def test_forged_tokens_rejected():
    claims = {"sub": str(uuid.uuid4()), "role": "admin", "type": "access"}
    assert decode_access_token(jwt.encode(claims, "boshqa-kalit-" + "x" * 32, algorithm="HS256")) is None
    assert decode_access_token(jwt.encode(claims, None, algorithm="none")) is None
    assert decode_access_token("buzilgan.token.qiymat") is None


def test_expired_and_wrong_scope():
    expired = jwt.encode({"sub": "1", "type": "access", "exp": 1}, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    assert decode_access_token(expired) is None
    token = create_scoped_token("abc", "dataset-export")
    assert decode_scoped_token(token, "dataset-export") == "abc"
    assert decode_scoped_token(token, "reset") is None
    assert decode_access_token(token) is None
