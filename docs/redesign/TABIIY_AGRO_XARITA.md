# Tabiiy Agro — ekranlar xaritasi va yetishmayotgan imkoniyatlar

Manba: «AgroYordam dizayn va funksional texnik topshiriq» v1.1 (19.10.2026), Tabiiy Agro light/dark maketlari.
Holat: 0.8.2 (dizayn tizimi, S01; bog' guruhi S02/S05/S06; tashxis guruhi S03/S04/S07/S08). Agronom va admin panellari bu bosqichda o'zgarmaydi.

## Mavjud arxitektura (saqlanadi)

| Qatlam | Texnologiya | Joylashuv |
|---|---|---|
| UI | Flutter 3.35 (Android + web) | `mobile/lib/presentation/screens/` |
| Routing | go_router, `redirect` orqali auth/rol himoyasi | `mobile/lib/presentation/router.dart` |
| State | Riverpod (`FutureProvider`, `Notifier`) | `mobile/lib/application/` |
| API | Dio + `BaseRepository.call` → `ApiException` | `mobile/lib/data/repositories/` |
| Tema | `AppColors` ThemeExtension (`context.c`) | `mobile/lib/core/theme/` |
| Til | `tr()` / `trf()` (uz, uz-Cyrl, ru, en, kaa) | `mobile/lib/core/i18n/`, `mobile/tool/i18n/` |
| Backend | FastAPI + PostgreSQL + Alembic | `backend/app/` |

## Ekranlar mosligi

Belgilar: ✅ bor · 🟡 bor, lekin TZ bo'yicha qayta ishlanadi · ⛔ yo'q (yangi ekran yoki backend kerak).

| ID | TZ ekrani | Mavjud yo'l / ekran | Holat | Yetishmaydi |
|---|---|---|---|---|
| S01 | Bosh sahifa | `/home` · `HomeScreen` | ✅ 0.8.0 da yangilandi | A03, A06 (pastda) |
| S02 | Mening bog'im | `/garden` · `GardenScreen` | ✅ 0.8.1 | — (qidiruv, Barchasi/E'tibor kerak/Arxiv, ⋮ tahrir/arxiv, bekor qilish) |
| S03 | AI tashxis | `/diagnose?crop=` · `DiagnoseScreen` | ✅ 0.8.2 | Rasmni aylantirish/kesish yo'q; tahlil limiti tugaganda qoralama saqlanmaydi |
| S04 | Parvarish rejasi | `/garden/:id/care` · `CareScreen`; reja yaratish `/diagnosis/:id/plan` | ✅ 0.8.2 | Rejani qayta yaratishda farq previewi ⛔; vazifa seriyasi (occurrence) ⛔ |
| S05 | Ekin qo'shish | `/garden/add`, `/garden/:id/edit` · `AddCropScreen` | ✅ 0.8.1 | Ekin turi serverda ixtiyoriy qoldi (eski APK mosligi uchun); ilovada majburiy |
| S06 | Ekin tafsiloti | `/garden/:id?tab=` · `CropDetailScreen` | ✅ 0.8.1 | A04 da rasmli kuzatuv (UI); "o'chirish" TZ bo'yicha olib tashlandi |
| S07 | Tashxislar tarixi | `/diagnoses` | ✅ 0.8.2 | Server pagination (hozir 200 tagacha bitta so'rov) |
| S08 | Tashxis natijasi | `/diagnosis/:id` | ✅ 0.8.2 | Fikrga ixtiyoriy sabab yozish ⛔ (API faqat ha/yo'q) |
| S09 | Maslahat (AI) | `/help?tab=ai` | 🟡 | Suhbatlar ro'yxati ⛔ — backend'da bitta AI tarix (`/ai/chat/history`) |
| S10 | AI suhbat | `/assistant` | 🟡 | Streaming, to'xtatish, bir nechta suhbat ⛔ (backend) |
| S11 | Jamoat | `/help?tab=comm` | 🟡 | Tajriba/Savollar filtri (`?category=` backend'da bor); bookmark ⛔ |
| S12 | Yangi post | `/community/new` | 🟡 | 5 tagacha rasm ⛔ (backend bitta `image_url`); ekin belgilash |
| S13 | Post tafsiloti | `/community/:id` | 🟡 | Izohga javob (`parent_comment_id` ⛔), bookmark ⛔ |
| S14 | Fermer profili | `/users/:id` | 🟡 | «Haqida» tabi; bloklash ⛔ |
| S15 | Xabarlar | `/messages` | 🟡 | Suhbat qidiruvi; A07 foydalanuvchi qidiruvi ⛔ |
| S16 | Shaxsiy chat | `/messages/:id` | 🟡 | Rasm yuborish UI (backend `messages.image_url` bor) |
| S17 | O'simliklar | `/catalog?tab=plants` | 🟡 | Sabzavot/Mevali/Donli filtri — `plants.category` ⛔ |
| S18 | Kasalliklar | `/catalog?tab=diseases` | 🟡 | — |
| S19 | Dorilar | `/catalog?tab=medicines` | 🟡 | — |
| S20 | O'simlik tafsiloti | `/catalog/plant/:id` | 🟡 | Tablar; bookmark ⛔; «Bog'imga qo'shish» → S05 tur bilan |
| S21 | Kasallik tafsiloti | `/catalog/disease/:id` | 🟡 | Manbalar tabi (backend'da manba maydoni ⛔) |
| S22 | Dori tafsiloti | `/catalog/medicine/:id` | 🟡 | Yorliq hujjati ⛔ |
| S23 | Profil | `/profile` | 🟡 | Saqlanganlar (A02) ⛔ |
| S24 | Shaxsiy ma'lumotlar | `/profile/edit` | ✅ (0.7.0) | Username tahriri; aloqa tasdiqlash (S35) ⛔ |
| S25 | Eslatmalar | `/reminders` | 🟡 | Bajarilgan tabi |
| S26 | Yangi eslatma | `/reminders/add` | 🟡 | Takrorlash va oldindan eslatish ⛔ (backend `reminders` da yo'q) |
| S27 | Bildirishnomalar | `/notifications` | 🟡 | O'qilmagan filtri (klient tomonda bajarsa bo'ladi) |
| S28 | Parolni o'zgartirish | `/profile/password` | 🟡 | Parol kuchi; «boshqa seanslardan chiqish» ixtiyoriy (hozir doim chiqaradi) |
| S29 | Obunam | `/premium` | 🟡 | Oylik/Yillik serverdan ✅; A08 buyurtma xulosasi |
| S30 | To'lovlar tarixi | `/premium/payments` | 🟡 | Chek ⛔ |
| S31 | Mavzu tanlash | profil ichidagi tanlagich | ⛔ ekran | Preview, matn o'lchami, kamaytirilgan harakat |
| S32 | Til tanlash | `showLanguageSheet` | 🟡 | Alohida ekran + qidiruv |
| S33 | Kirish | `/login` | 🟡 | SMS bilan kirish ⛔ (SMS provayder yo'q) |
| S34 | Ro'yxatdan o'tish | `/register` | 🟡 | Shartlarga rozilik belgisi; OTP ⛔ |
| S35 | Kodni tasdiqlash | — | ⛔ | SMS/email provayder va challenge API ⛔ |
| S36 | Parolni tiklash | `/forgot` | 🟡 | Hozir token orqali (dev); SMS ⛔ |
| A01 | Tahlil jarayoni | S03 ichida bosqichlar | 🟡 | Yuklash → tahlil bosqichlari, yuklashda bekor qilish, 60 s xabari ✅; server job holatlari (queued/processing) ⛔ — backend sinxron |
| A02 | Saqlanganlar | — | ⛔ | Bookmark API ⛔ |
| A03 | Vazifa tafsiloti | — | ✅ 0.8.0 (pastki oyna) | Tahrir (`PUT /reminders/:id` bor) |
| A04 | Kuzatuv/kundalik | S06 «Kundalik» tabi | 🟡 | Matn ✅ (2000 belgi); rasm biriktirish va yozuvni tahrirlash/o'chirish API ⛔ |
| A05 | Sozlamalar va hujjatlar | qisman | 🟡 | Server manzili productionda yashirilishi kerak |
| A06 | Hudud va ob-havo | — | ✅ 0.8.0 | Soatlik/kunlik prognoz (provayder qo'llaydi, keyingi bosqich) |
| A07 | Foydalanuvchi qidiruvi | — | ⛔ | Ommaviy qidiruv API ⛔ |
| A08 | Modal oqimlar | shikoyat ✅, agronomga yuborish ✅ | 🟡 | Bloklash ⛔, buyurtma xulosasi |

## 0.8.0 da backend'ga qo'shilgan (mavjud API kengaytirildi, almashtirilmadi)

- `GET /weather`: `is_day`, `code`, `updated_at` (keshlangan ma'lumot vaqti) — header effekti va «yangilangan vaqt» uchun.
- `GET /crops`: `last_diagnosis_at` — «Ma'lumot yetarli emas» holatini sog'lomdan ajratish uchun.

## 0.8.1 da backend'ga qo'shilgan

- `crops.photo_url` (migratsiya 0008), `POST/DELETE /crops/{id}/photo` — ekin surati (jpg/png/webp, ≤10 MB).
- `CropIn/CropUpdate` tekshiruvi TZ S05 bo'yicha: nom 2–80, nav ≤80, maydon > 0, joylashuv ≤120, izoh ≤1000, sana kelajakda emas.
- `GET /reminders` (crop_id siz): arxivlangan ekin vazifalari umumiy ro'yxatdan chiqadi; `?crop_id=` bilan tarix qoladi.

## 0.8.2 da backend'ga qo'shilgan

- `diagnoses.hidden_at` (migratsiya 0009): `DELETE /diagnoses/{id}` endi tarixdan **yashiradi** (yozuv, agronom javobi va dataset saqlanadi), `POST /diagnoses/{id}/restore` qaytaradi. Yashirilgan tashxis ekin holati va sog'liq tarixida hisobga olinmaydi.

## Ekin holati qoidasi (TZ 1-bo'lim)

Foiz ko'rsatilmaydi. `last_diagnosis_at` yo'q → «Ma'lumot yetarli emas»; oxirgi tashxisda kasallik va
`health_score < 45` → «E'tibor kerak»; kasallik bor yoki `< 70` → «Kuzatuv kerak»; aks holda «Sog'lom · {sana}»
(oxirgi kuzatuv sanasi bilan vaqtli xulosa).
