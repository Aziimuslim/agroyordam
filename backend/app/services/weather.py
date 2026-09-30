"""Ob-havo va zamburug' kasalliklari xavfi (Open-Meteo — bepul, API kalitsiz).

Viloyat nomi → markaz koordinatasi → hozirgi harorat/namlik + keyingi 2 kun yog'in.
Xavf evristikasi (fitoftoroz, un shudring, alternarioz kabi zamburug' kasalliklari uchun):
  yuqori — namlik ≥ 80% va 10–26°C yoki yaqin kunlarda yomg'ir; o'rta — namlik ≥ 65%; aks holda past.
Natija viloyat bo'yicha 30 daqiqa keshlanadi.
"""
import time
from dataclasses import asdict, dataclass

import httpx

REGIONS: dict[str, tuple[float, float, str]] = {
    "toshkent shahri": (41.311, 69.279, "Toshkent"),
    "toshkent viloyati": (41.000, 69.600, "Toshkent vil."),
    "andijon": (40.783, 72.344, "Andijon"),
    "buxoro": (39.767, 64.423, "Buxoro"),
    "farg'ona": (40.386, 71.786, "Farg'ona"),
    "jizzax": (40.116, 67.842, "Jizzax"),
    "xorazm": (41.550, 60.631, "Urganch"),
    "namangan": (40.998, 71.672, "Namangan"),
    "navoiy": (40.103, 65.374, "Navoiy"),
    "qashqadaryo": (38.861, 65.790, "Qarshi"),
    "qoraqalpog'iston": (42.461, 59.600, "Nukus"),
    "samarqand": (39.654, 66.975, "Samarqand"),
    "sirdaryo": (40.490, 68.780, "Guliston"),
    "surxondaryo": (37.224, 67.278, "Termiz"),
}
DEFAULT_REGION = "toshkent shahri"
TTL = 30 * 60

# WMO weather codes → o'zbekcha
_CODES = [
    ((0,), "ochiq osmon"), ((1, 2), "qisman bulutli"), ((3,), "bulutli"), ((45, 48), "tuman"),
    ((51, 53, 55, 56, 57), "mayda yomg'ir"), ((61, 63, 65, 66, 67, 80, 81, 82), "yomg'ir"),
    ((71, 73, 75, 77, 85, 86), "qor"), ((95, 96, 99), "momaqaldiroq"),
]


def condition(code: int) -> str:
    return next((t for codes, t in _CODES if code in codes), "o'zgaruvchan")


def region_key(region: str | None) -> str:
    r = (region or "").strip().lower().replace("‘", "'").replace("’", "'").replace("`", "'")
    if not r:
        return DEFAULT_REGION
    if r in REGIONS:
        return r
    return next((k for k in REGIONS if k.split()[0] in r), DEFAULT_REGION)


@dataclass
class Weather:
    region: str
    city: str
    temperature: float
    humidity: int
    code: int
    condition: str
    rain_next_48h_mm: float
    risk: str  # low | medium | high
    risk_text: str


def disease_risk(temp: float, humidity: int, rain_mm: float) -> tuple[str, str]:
    if (humidity >= 80 and 10 <= temp <= 26) or rain_mm >= 5:
        return "high", "Nam va salqin — zamburug' kasalliklari (fitoftoroz, un shudring) xavfi yuqori. Profilaktik ishlov bering."
    if humidity >= 65 or rain_mm >= 1:
        return "medium", "Namlik yuqoriroq — barglarni kuzatib boring, kechqurun sug'ormang."
    return "low", "Quruq havo — zamburug' kasalliklari xavfi past. O'rgimchakkanaga e'tibor bering."


_cache: dict[str, tuple[float, Weather]] = {}


async def get_weather(region: str | None, client: httpx.AsyncClient | None = None) -> Weather:
    key = region_key(region)
    hit = _cache.get(key)
    if hit and time.time() - hit[0] < TTL:
        return hit[1]
    lat, lon, city = REGIONS[key]
    params = {
        "latitude": lat, "longitude": lon, "timezone": "Asia/Tashkent", "forecast_days": 2,
        "current": "temperature_2m,relative_humidity_2m,weather_code",
        "daily": "precipitation_sum",
    }
    own = client is None
    client = client or httpx.AsyncClient(timeout=8)
    try:
        resp = await client.get("https://api.open-meteo.com/v1/forecast", params=params)
        resp.raise_for_status()
        data = resp.json()
    finally:
        if own:
            await client.aclose()
    cur = data["current"]
    temp = float(cur["temperature_2m"])
    hum = int(round(cur["relative_humidity_2m"]))
    code = int(cur.get("weather_code") or 0)
    rain = float(sum(x or 0 for x in data.get("daily", {}).get("precipitation_sum", [])))
    risk, text = disease_risk(temp, hum, rain)
    w = Weather(region=key, city=city, temperature=round(temp, 1), humidity=hum, code=code, condition=condition(code),
                rain_next_48h_mm=round(rain, 1), risk=risk, risk_text=text)
    _cache[key] = (time.time(), w)
    return w


def as_dict(w: Weather) -> dict:
    return asdict(w)
