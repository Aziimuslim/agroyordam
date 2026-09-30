import httpx

from app.services import weather as W


def fake_transport(payload, status=200):
    def handler(request: httpx.Request):
        assert request.url.host == "api.open-meteo.com"
        return httpx.Response(status, json=payload)
    return httpx.MockTransport(handler)


def payload(temp, hum, rain):
    return {"current": {"temperature_2m": temp, "relative_humidity_2m": hum, "weather_code": 61},
            "daily": {"precipitation_sum": [rain, 0]}}


def test_region_key_and_risk():
    assert W.region_key("Qoraqalpog‘iston") == "qoraqalpog'iston"
    assert W.region_key("Samarqand viloyati") == "samarqand"
    assert W.region_key(None) == "toshkent shahri"
    assert W.disease_risk(18, 85, 0)[0] == "high"
    assert W.disease_risk(30, 70, 0)[0] == "medium"
    assert W.disease_risk(33, 30, 0)[0] == "low"
    assert W.disease_risk(33, 30, 8)[0] == "high"


async def test_get_weather_parses_and_caches():
    W._cache.clear()
    async with httpx.AsyncClient(transport=fake_transport(payload(17.4, 86, 2.5))) as client:
        w = await W.get_weather("Andijon", client)
    assert (w.city, w.temperature, w.humidity, w.risk, w.condition) == ("Andijon", 17.4, 86, "high", "yomg'ir")
    # keshdan — tarmoqqa chiqmaydi (xato transport ham ishlatilmaydi)
    async with httpx.AsyncClient(transport=fake_transport({}, 500)) as client:
        assert (await W.get_weather("andijon", client)).temperature == 17.4


async def test_weather_endpoint(client, user_headers, monkeypatch):
    W._cache.clear()

    async def fake(region, client=None):
        return W.Weather("toshkent shahri", "Toshkent", 24.0, 40, 0, "ochiq osmon", 0.0, "low", "Quruq")
    monkeypatch.setattr("app.api.v1.weather.get_weather", fake)
    r = await client.get("/api/v1/weather", headers=user_headers)
    assert r.status_code == 200 and r.json()["city"] == "Toshkent" and r.json()["risk"] == "low"

    async def boom(region, client=None):
        raise httpx.ConnectError("offline")
    monkeypatch.setattr("app.api.v1.weather.get_weather", boom)
    assert (await client.get("/api/v1/weather", headers=user_headers)).status_code == 503
