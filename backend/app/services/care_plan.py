"""Tashxisdan kunlik parvarish rejasi: AI natijasi + bilimlar bazasi (kasallik, dori, o'simlik parvarishi) asosida.

Reja — kunlarga bo'lingan vazifalar ro'yxati; "Bog'imga qo'shish"da ular eslatma (reminders) sifatida saqlanadi
va APScheduler vaqti kelganda bildirishnoma yuboradi.
"""
import re
from dataclasses import dataclass
from datetime import date, time, timedelta

from app.models import Disease, Plant

DURATION_BY_RISK = {"low": 10, "medium": 14, "high": 21}
HEALTHY_DAYS = 7
DEFAULT_SPRAY_INTERVAL = 7
WATER_EVERY = 2

_INTERVAL_RE = re.compile(r"(\d+)\s*kun\s*oralig")
_TIMES_RE = re.compile(r"(\d+)\s*marta")


@dataclass
class Task:
    day: int
    title: str
    description: str | None
    reminder_type: str
    at: time

    def on(self, start: date) -> date:
        return start + timedelta(days=self.day)


def _spray_schedule(recommendation: str | None, duration: int) -> list[int]:
    """'40 g / 10 l suv, 3 marta 7 kun oralig'ida' → [0, 7, 14]."""
    text = recommendation or ""
    m = _INTERVAL_RE.search(text)
    interval = int(m.group(1)) if m else DEFAULT_SPRAY_INTERVAL
    interval = min(max(interval, 3), 21)
    t = _TIMES_RE.search(text)
    times = int(t.group(1)) if t else None
    days = list(range(0, duration, interval))
    return days[:times] if times else days


def build_plan(disease: Disease | None, plant: Plant | None, medicines: list[tuple[str, str | None]],
               healthy: bool) -> tuple[int, list[Task]]:
    """→ (davomiylik kunlarda, vazifalar). medicines: [(dori nomi, tavsiya)]."""
    plant_name = plant.name if plant else "Ekin"
    care = plant.care_info if plant and plant.care_info else None
    tasks: list[Task] = []

    if healthy or disease is None:
        duration = HEALTHY_DAYS
        for d in range(0, duration, WATER_EVERY):
            tasks.append(Task(d, f"{plant_name}: sug'orish", care or "Ertalab ildiz ostidan sug'oring.", "watering", time(7, 0)))
        tasks.append(Task(3, "Barglarni ko'zdan kechirish", "Dog', sarg'ayish yoki zararkunanda bor-yo'qligini tekshiring.", "other", time(9, 0)))
        tasks.append(Task(duration, "Qayta AI tashxis", "Barg rasmini olib, holatini AI tashxis bilan tekshiring.", "recheck", time(10, 0)))
        return duration, sorted(tasks, key=lambda t: (t.day, t.at))

    duration = DURATION_BY_RISK.get(disease.risk_level or "medium", 14)
    name = disease.name

    tasks.append(Task(0, "Zararlangan barglarni olib tashlang",
                      "Kasallangan barg va shoxlarni kesib, maydondan chiqarib yo'q qiling (kompostga solmang). "
                      + (disease.treatment or ""), "treatment", time(8, 0)))

    if medicines:
        med, rec = medicines[0]
        dose = rec or "Yo'riqnomaga ko'ra"
        days = _spray_schedule(rec, duration)
        for i, d in enumerate(days, 1):
            tasks.append(Task(d, f"{med} bilan ishlov berish ({i}/{len(days)})",
                              f"{dose}. Ertalab yoki kechqurun, shamolsiz havoda purkang; "
                              "himoya qo'lqop va niqobidan foydalaning.", "treatment", time(17, 0)))
    else:
        tasks.append(Task(0, f"{name}: davolash", disease.treatment or "Mutaxassis tavsiyasiga ko'ra ishlov bering.",
                          "treatment", time(17, 0)))

    symptoms = f"Belgilar: {disease.symptoms}" if disease.symptoms else "Yangi dog'lar paydo bo'lganini tekshiring."
    for d in range(1, duration):
        tasks.append(Task(d, "Kunlik ko'rik", f"{name} tarqalmayaptimi? {symptoms}", "other", time(9, 0)))

    watering = "Faqat ildiz ostidan sug'oring, barglarga suv tegizmang — namlik kasallikni kuchaytiradi."
    for d in range(1, duration, WATER_EVERY):
        tasks.append(Task(d, f"{plant_name}: sug'orish", watering, "watering", time(7, 0)))

    if disease.prevention:
        tasks.append(Task(1, "Oldini olish choralari", disease.prevention, "other", time(10, 0)))

    tasks.append(Task(duration // 2, "Oraliq AI tashxis", "Davolash natijasini ko'rish uchun yangi barg rasmini tekshiring.",
                      "recheck", time(10, 0)))
    tasks.append(Task(duration, "Yakuniy AI tashxis",
                      f"{name} yo'qolganini tasdiqlang. Belgilar qolsa, rejani qayta tuzing.", "recheck", time(10, 0)))
    return duration, sorted(tasks, key=lambda t: (t.day, t.at))
