import httpx

from app.services import weather as W


def fake_transport(payload, status=200):
    def handler(request: httpx.Request):
        assert request.url.host == "api.open-meteo.com"
        return httpx.Response(status, json=payload)
    return httpx.MockTransport(handler)


def payload(temp, hum, rain, **cur):
    return {"current": {"temperature_2m": temp, "relative_humidity_2m": hum, "weather_code": 61, **cur},
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
    assert w.is_day is True and w.code == 61 and w.updated_at.endswith("+00:00")  # is_day berilmasa — kunduz
    # keshdan — tarmoqqa chiqmaydi (xato transport ham ishlatilmaydi)
    async with httpx.AsyncClient(transport=fake_transport({}, 500)) as client:
        assert (await W.get_weather("andijon", client)).temperature == 17.4


async def test_weather_night():
    W._cache.clear()
    async with httpx.AsyncClient(transport=fake_transport(payload(9.0, 50, 0, is_day=0))) as client:
        assert (await W.get_weather("Buxoro", client)).is_day is False


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


async def test_forecast_hourly_daily():
    W._cache.clear()
    hours = [f"2026-10-20T{h:02d}:00" for h in range(24)] + [f"2026-10-21T{h:02d}:00" for h in range(24)]
    data = {
        "current": {"time": "2026-10-20T14:15", "temperature_2m": 21, "relative_humidity_2m": 50, "weather_code": 0, "is_day": 1},
        "hourly": {"time": hours, "temperature_2m": [10 + i % 24 for i in range(48)], "weather_code": [0] * 48,
                   "precipitation_probability": [5] * 48, "is_day": [1] * 48},
        "daily": {"time": ["2026-10-20", "2026-10-21", "2026-10-22"], "precipitation_sum": [1.0, 2.0, 30.0],
                  "temperature_2m_max": [24, 22, 18], "temperature_2m_min": [9, 8, 6], "weather_code": [0, 61, 95],
                  "precipitation_probability_max": [10, 80, 90]},
    }
    async with httpx.AsyncClient(transport=fake_transport(data)) as client:
        w = await W.get_weather("Namangan", client)
    assert len(w.hourly) == 24 and w.hourly[0]["time"] == "2026-10-20T14:00"  # joriy soatdan
    assert [d["code"] for d in w.daily] == [0, 61, 95] and w.daily[1]["condition"] == "yomg'ir"
    assert w.rain_next_48h_mm == 3.0  # faqat 2 kun — xavf hisobi o'zgarmadi
