"""AI Yordamchi — bilimlar bazasiga (KB) tayangan erkin savol-javob.

MVP: kalit so'zlar bo'yicha KB'dan qidiradi va javob tuzadi. Keyinchalik LLM
provayderi shu `answer()` interfeysi ortiga ulanadi.
"""
import re

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Disease, Medicine, Plant
from app.repositories.catalog_repo import DiseaseRepository

GENERAL_TIPS = {
    ("sug'or", "suv", "namlik"): "Sug'orishni erta tongda yoki kechqurun, ildiz tagidan qiling. Barglarni ho'llamaslik zamburug' kasalliklari xavfini kamaytiradi.",
    ("o'g'it", "ogit", "azot", "fosfor", "kaliy"): "O'g'itlashda tuproq tahliliga tayaning: azot — o'sish, fosfor — ildiz va gullash, kaliy — meva sifati uchun. Me'yordan oshirmang.",
    ("zararkunanda", "qurt", "hasharot", "shira"): "Zararkunandalarni erta aniqlash uchun barg ostini haftada 2 marta tekshiring. Avval biologik vositalarni (Bt, Trichoderma) sinab ko'ring.",
    ("ekish", "ko'chat", "urug'"): "Ko'chatni tuproq harorati 12–15°C dan oshganda eking, qatorlar orasida havo aylanishi uchun yetarli masofa qoldiring.",
}


def _words(text: str) -> list[str]:
    return [w for w in re.findall(r"[a-zA-Z'ʻʼ‘’]+", text.lower()) if len(w) > 3]


async def answer(db: AsyncSession, question: str) -> str:
    q = question.lower()
    words = _words(question)

    diseases = list((await db.scalars(select(Disease))).all())
    best, best_score = None, 0
    for d in diseases:
        hay = " ".join(filter(None, [d.name, d.symptoms, d.description, d.ai_label])).lower()
        score = sum(2 if w in d.name.lower() else 1 for w in words if w in hay)
        if score > best_score:
            best, best_score = d, score

    if best and best_score >= 2:
        plant = await db.get(Plant, best.plant_id) if best.plant_id else None
        meds = await DiseaseRepository(db).medicines_for(best.id)
        parts = [f"Bu {best.name.lower()}ga o'xshaydi" + (f" ({plant.name.lower()})" if plant else "") + "."]
        if best.symptoms:
            parts.append(f"Belgilari: {best.symptoms}")
        if best.treatment:
            parts.append(f"Davolash: {best.treatment}")
        if meds:
            parts.append("Tavsiya etilgan vositalar: " + "; ".join(
                f"{m.name}" + (f" — {r}" if r else "") for m, r in meds))
        if best.prevention:
            parts.append(f"Oldini olish: {best.prevention}")
        parts.append("Aniq tashxis uchun barg rasmini AI Tashxis bo'limiga yuboring.")
        return "\n\n".join(parts)

    for m in (await db.scalars(select(Medicine))).all():
        if m.name.lower() in q:
            return f"{m.name}: {m.description or ''}\n\nQo'llash: {m.usage or '—'}\n\nEhtiyot choralari: {m.precautions or '—'}"

    for keys, tip in GENERAL_TIPS.items():
        if any(k in q for k in keys):
            return tip

    return ("Savolingizni aniqroq yozing: qaysi ekin, qanday belgilar (dog'lar rangi, barg sarg'ayishi, so'lish) "
            "va qachondan beri kuzatilyapti. Yoki barg rasmini AI Tashxis orqali yuboring — aniqroq javob beraman.")
