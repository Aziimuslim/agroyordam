# Agronom rejimi — TZ xaritasi (P01–P44 → Y01–Y16)

Manba: «AgroYordam — Agronom rejimi. Dizayn va funksional TZ». Holat: ✅ tayyor · ⏳ keyingi guruh.

| Guruh | ID | Ekran | Holat | Versiya |
|---|---|---|---|---|
| 1 | P01–P04 | Y01 Navbat: hisoblagichlar, filtrlar (son bilan), karta, mavjudlik | ✅ | 0.8.23 |
| 1 | P05, P07, P08 | Y02 Tekshirish: claim, AI taxmini, boshqa kasallik, rasm viewer, qayta surat | ✅ | 0.8.23 |
| 1 | P06 | Y03 Ekspert xulosasi: majburiy izoh, manba (https), preview, keyingi ish | ✅ | 0.8.23 |
| 1 | — | Pastki navigatsiya (5 bo'lim), agronom rejimi Tabiiy Agro mavzusida | ✅ | 0.8.23 |
| 2 | P09–P11, P44 | Y04 Savollar, Y05 maslahat chat | ⏳ | |
| 3 | P12–P16, P43 | Y06 Jamoat, Y07 Post, Y08 Xabarlar | ⏳ | |
| 4 | P17–P29 | Y09–Y12 Bilimlar: katalog, tafsilot, editor, taklif | ⏳ | |
| 5 | P30–P34, P36–P42 | Y13–Y16 Profil, jadval, bildirishnomalar, ma'lumotlar | ⏳ | |
| 6 | P35 | Dark/responsive/accessibility yakuniy tekshiruv | ⏳ | |

## 1-guruh backend
- `diagnoses`: `review_claimed_by/at`, `expert_source`, `retake_reason` (migratsiya 0020).
- `POST /experts/queue/{id}/claim` (30 daqiqa, atomik; band bo'lsa 409), `POST /queue/{id}/release`.
- `GET /experts/queue-counts`; `stats/me` → `today_new`, `reviewed_7d`.
- Review: izoh majburiy (3–2000), `rejected` uchun sabab majburiy, manba faqat `https://`.
- Dehqon tashxis sahifasida: agronom manbasi havolasi va qayta surat sababi.
