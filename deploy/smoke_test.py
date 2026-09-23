"""Production stack smoke test (faqat standart kutubxona).

    python3 deploy/smoke_test.py https://localhost

Tekshiradi: HTTPS, web ilova, /docs yopiqligi, ro'yxatdan o'tish, katalog (KB), ekin, rasm yuklab
haqiqiy AI tashxis, yuklangan rasmning ochilishi, obuna rejalari, to'lov endpointlari.
"""
import json
import ssl
import struct
import sys
import time
import urllib.error
import urllib.request
import uuid
import zlib

BASE = sys.argv[1].rstrip("/")
CTX = ssl.create_default_context()
if "localhost" in BASE:
    CTX.check_hostname, CTX.verify_mode = False, ssl.CERT_NONE  # Caddy'ning lokal CA'si


def req(method, path, body=None, token=None, headers=None, raw=False):
    h = dict(headers or {})
    data = None
    if body is not None and not isinstance(body, bytes):
        data, h["Content-Type"] = json.dumps(body).encode(), "application/json"
    elif isinstance(body, bytes):
        data = body
    if token:
        h["Authorization"] = f"Bearer {token}"
    r = urllib.request.Request(BASE + path if path.startswith("/") else path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, context=CTX, timeout=60) as resp:
            content = resp.read()
            return resp.status, (content if raw else json.loads(content or b"null"))
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def leaf_png(size=320) -> bytes:
    """Yashil barg ustida qo'ng'ir dog'lar (Pillow'siz PNG)."""
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            spot = ((x // 40 + y // 40) % 3 == 0) and (x % 40 - 20) ** 2 + (y % 40 - 20) ** 2 < 120
            noise = (x * 7 + y * 13) % 23
            row += bytes((125, 75, 25) if spot else (60 + noise, 140 + noise, 45))
        rows.append(bytes(row))
    raw = zlib.compress(b"".join(rows))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")


def check(cond, msg):
    print(("OK   " if cond else "FAIL ") + msg, flush=True)
    if not cond:
        sys.exit(1)


st, body = req("GET", "/health")
check(st == 200 and body["database"] is True, f"/health → {body}")
st, html = req("GET", "/", raw=True)
check(st == 200 and b"flutter" in html.lower(), "web ilova (Flutter) ochiladi")
st, _ = req("GET", "/garden", raw=True)
check(st == 200, "SPA deep-link (/garden) ishlaydi")
st, _ = req("GET", "/docs", raw=True)
check(st == 404, "production'da /docs yopiq")

u = "smoke" + uuid.uuid4().hex[:8]
st, tok = req("POST", "/api/v1/auth/register", {"full_name": "Smoke Test", "username": u, "email": f"{u}@example.com", "password": "Smoke12345!"})
check(st == 201, "ro'yxatdan o'tish")
token = tok["access_token"]
st, _ = req("POST", "/api/v1/auth/login", {"login": "dilnoza", "password": "Demo12345!"})
check(st == 401, "demo hisoblar production'da yo'q")

st, plants = req("GET", "/api/v1/plants")
check(st == 200 and len(plants) >= 11, f"katalog: {len(plants)} o'simlik")
st, diseases = req("GET", "/api/v1/diseases")
check(st == 200 and len(diseases) >= 28, f"bilimlar bazasi: {len(diseases)} kasallik")
tomato = next(p for p in plants if p["name"] == "Pomidor")
st, crop = req("POST", "/api/v1/crops", {"name": "Smoke pomidor", "plant_id": tomato["id"]}, token)
check(st == 201, "ekin qo'shildi")

boundary = "----smoke" + uuid.uuid4().hex
img = leaf_png()
body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"crop_id\"\r\n\r\n{crop['id']}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"leaf.png\"\r\nContent-Type: image/png\r\n\r\n").encode() + img + f"\r\n--{boundary}--\r\n".encode()
t0 = time.time()
st, diag = req("POST", "/api/v1/diagnoses", body, token, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
check(st == 201, f"AI tashxis ({time.time() - t0:.1f}s): {diag.get('disease_name') if isinstance(diag, dict) else diag} "
      f"ishonch={diag.get('confidence') if isinstance(diag, dict) else '-'}")
check(diag["plant_name"] == "Pomidor" or diag["disease_name"] is None, "tashxis ekin turiga mos (Pomidor)")
st, _ = req("GET", diag["image_url"], raw=True)
check(st == 200, f"yuklangan rasm ochiladi: {diag['image_url']}")

st, plans = req("GET", "/api/v1/subscriptions/plans")
check(st == 200 and len(plans) == 3, "obuna rejalari")
st, pm = req("POST", "/api/v1/payments/payme", {"jsonrpc": "2.0", "id": 1, "method": "CheckTransaction", "params": {"id": "x"}})
check(st == 200 and pm["error"]["code"] == -32504, "Payme endpoint avtorizatsiyasiz so'rovni rad etadi")
print("\nHammasi joyida ✅")
