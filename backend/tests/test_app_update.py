from app.api.v1 import app_update

BODY = """AgroYordam — Android APK.

## 0.8.20 — ilova ichida yangilanish
- Yangi versiya chiqsa, ilova o'zi taklif qiladi.

## 0.8.19 — manzara
- Eski.
"""


def test_parse_release_and_notes():
    rel = {
        "tag_name": "v0.8.20",
        "body": BODY,
        "published_at": "2026-10-30T18:00:00Z",
        "assets": [
            {"name": "AgroYordam.apk", "size": 10, "browser_download_url": "https://x/AgroYordam.apk"},
            {"name": "AgroYordam-0.8.20.apk", "size": 63_000_000, "browser_download_url": "https://x/AgroYordam-0.8.20.apk"},
        ],
    }
    d = app_update._parse(rel)
    assert d["version"] == "0.8.20"
    assert d["apk_url"].endswith("AgroYordam-0.8.20.apk") and d["size"] == 63_000_000
    assert d["notes"] == "- Yangi versiya chiqsa, ilova o'zi taklif qiladi."


def test_parse_rejects_bad_release():
    assert app_update._parse({"tag_name": "nightly", "assets": []}) is None
    assert app_update._parse({"tag_name": "v1.0.0", "assets": [{"name": "other.zip"}]}) is None


async def test_latest_endpoint_uses_cache(client, monkeypatch):
    app_update._cache.update(at=0.0, data=None)
    calls = []

    class FakeResp:
        def raise_for_status(self):
            pass

        def json(self):
            return {"tag_name": "v0.9.0", "body": "## 0.9.0\n- x\n", "assets": [{"name": "AgroYordam-0.9.0.apk", "size": 5, "browser_download_url": "u"}]}

    class FakeClient:
        def __init__(self, *a, **k):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *a):
            return False

        async def get(self, url, headers=None):
            calls.append(url)
            return FakeResp()

    monkeypatch.setattr(app_update.httpx, "AsyncClient", FakeClient)
    r1 = await client.get("/api/v1/app/latest")
    r2 = await client.get("/api/v1/app/latest")
    assert r1.status_code == 200 and r1.json()["version"] == "0.9.0" and r1.json()["notes"] == "- x"
    assert r2.json() == r1.json() and len(calls) == 1
    app_update._cache.update(at=0.0, data=None)
