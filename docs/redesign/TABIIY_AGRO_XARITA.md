# Tabiiy Agro — ekranlar xaritasi va yetishmayotgan imkoniyatlar

Manba: «AgroYordam dizayn va funksional texnik topshiriq» v1.1 (19.10.2026), Tabiiy Agro light/dark maketlari.
Holat: 0.8.4 (dizayn tizimi, S01; bog' S02/S05/S06; tashxis S03/S04/S07/S08; vazifalar S25–S27; ma'lumotnoma S17–S22). Agronom va admin panellari bu bosqichda o'zgarmaydi.

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
| S09 | Maslahat (AI) | `/help?tab=ai` | ✅ 0.8.5 | Bugungi bepul limit ko'rsatiladi; tayyor savol faqat yozish maydoniga qo'yiladi. Suhbatlar ro'yxati ⛔ — backend'da bitta AI tarix |
| S10 | AI suhbat | `/assistant?q=` | ✅ 0.8.5 | Yuborilmoqda/xato + qayta urinish, qoralama saqlanadi, avto-scroll faqat pastda bo'lsa. Streaming, to'xtatish, bir nechta suhbat ⛔ (backend) |
| S11 | Jamoat | `/help?tab=comm` | ✅ 0.8.5 | Barchasi/Obunalar/Tajriba/Savollar; like optimistik (xatoda qaytadi). Bookmark ⛔ |
| S12 | Yangi post | `/community/new`, `?edit=` | ✅ 0.8.5 | Tur majburiy, sarlavha 3–100, matn 10–3000 (server ham tekshiradi); tahrirlash. 5 tagacha rasm ⛔ (backend bitta `image_url`) |
| S13 | Post tafsiloti | `/community/:id?comment=1` | ✅ 0.8.5 | Agronom javoblari tepada; izoh o'chirish/shikoyat (sabab majburiy); o'chirilgan post holati. Izohga javob ⛔, bookmark ⛔ |
| S14 | Fermer profili | `/users/:id` | ✅ 0.8.5 | Postlar/Haqida, obuna, xabar yozish, o'z profilida tahrirlash; telefon/manzil ko'rsatilmaydi. Bloklash ⛔ |
| S15 | Xabarlar | `/messages` | ✅ 0.8.5 | Ism bo'yicha qidiruv, o'qilmaganlar, «Rasm» preview. A07 foydalanuvchi qidiruvi ⛔, suhbatni o'chirish/ovozsiz ⛔ |
| S16 | Shaxsiy chat | `/messages/:id` | ✅ 0.8.5 | Yuborish REST orqali: yuborilmoqda → yuborildi/o'qildi yoki xato + qayta yuborish; «yozmoqda...»; soxta «Onlayn» olib tashlandi (backend'da presence yo'q). Rasm yuborish UI ⛔ |
| S17 | O'simliklar | `/catalog?tab=plants` | ✅ 0.8.4 | — |
| S18 | Kasalliklar | `/catalog?tab=diseases` | ✅ 0.8.4 | «Belgilarni solishtirish» alohida oqimi yo'q (solishtirish S21 ichida) |
| S19 | Dorilar | `/catalog?tab=medicines` | ✅ 0.8.4 | Mintaqaviy ro'yxatdan o'tish ma'lumoti ⛔ |
| S20 | O'simlik tafsiloti | `/catalog/plant/:id` | ✅ 0.8.4 | Bookmark (A02) ⛔ |
| S21 | Kasallik tafsiloti | `/catalog/disease/:id` | ✅ 0.8.4 | Manba matni hali to'ldirilmagan (agronom KB tahririda kiritiladi); bookmark ⛔ |
| S22 | Dori tafsiloti | `/catalog/medicine/:id` | ✅ 0.8.4 | Yorliq hujjati (PDF) ⛔; `label_verified`ni belgilash UI agronom/admin panelida yo'q |
| S23 | Profil | `/profile` | ✅ 0.8.6 | Hisob/Faoliyat/Sozlamalar guruhlari; Ekin/Post serverdan. Saqlanganlar (A02) ⛔; agronom/admin bandlari faqat shu rolga ega foydalanuvchiga |
| S24 | Shaxsiy ma'lumotlar | `/profile/edit` | ✅ (0.7.0) | Username tahriri; aloqa tasdiqlash (S35) ⛔ |
| S25 | Eslatmalar | `/reminders?crop=` | ✅ 0.8.3 | — |
| S26 | Yangi eslatma | `/reminders/add`, `/reminders/:id/edit` | ✅ 0.8.3 | Qurilma push'i ⛔ (ilovada FCM yo'q — eslatma ilova ichidagi Bildirishnomalarda); takrorlash turini tahrirda o'zgartirish yo'q |
| S27 | Bildirishnomalar | `/notifications` | ✅ 0.8.3 | Bildirishnoma sozlamalari (A05) ⛔ |
| S28 | Parolni o'zgartirish | `/profile/password` | ✅ 0.8.6 | Har maydonda ko'z, 8–128, yangi ≠ joriy, kuch yordamchisi, «boshqa qurilmalardan chiqish» ixtiyoriy (standart o'chiq), chiqish tasdig'i |
| S29 | Obunam | `/premium` (`/subscription`) | ✅ 0.8.6 | Narx faqat serverdan; A08 buyurtma xulosasi; qaytishda buyurtma holati tekshiriladi; avto-yangilanish va'dasi olib tashlandi (yechish amalga oshirilmagan) |
| S30 | To'lovlar tarixi | `/premium/payments` (`/payments`) | ✅ 0.8.6 | Filtr, tafsilot, kutilayotganini yangilash; to'langan/kutilmoqda/amalga oshmagan/qaytarilgan alohida. Chek ⛔ (provayder integratsiyasida yo'q) |
| S31 | Mavzu tanlash | `/settings/appearance` | ✅ 0.8.6 | Namuna, matn Oddiy/Katta, harakat Tizimga mos/Kamaytirilgan; saqlamasdan chiqilsa eski qiymat |
| S32 | Til tanlash | `/settings/language` | ✅ 0.8.6 | Qidiruv, tanlangan tildagi namuna, saqlamasdan chiqish dialogi. Katalog tarjimasi yo'qligi belgisi ⛔ |
| S33 | Kirish | `/auth/login` (`/login`) | ✅ 0.8.7 | Telefon (E.164)/Email; umumiy xato; 429 taymer; xavfsiz returnTo; kod bilan kirish faqat kanal bo'lsa. Kanal (SMS/email provayder) ⛔ |
| S34 | Ro'yxatdan o'tish | `/auth/register` | ✅ 0.8.7 | Ism 2–80, kanal tanlovi, parol+tasdiq, rozilik (belgilanmagan, versiya va vaqt saqlanadi). Kanal bo'lsa hisob kod tasdig'idan keyin; productionda kanal yo'q — darhol yaratiladi va bu ochiq yoziladi |
| S35 | Kodni tasdiqlash | `/auth/verify` | ✅ 0.8.7 (sinov rejimida) | 6 raqam, TTL 5 daq, qayta yuborish 60 s, 5 urinish, eski kod yaroqsiz, noto'g'ri/eskirgan farqlanadi. Haqiqiy SMS/email yuborish ⛔ (provayder) |
| S36 | Parolni tiklash | `/auth/recovery` (`/forgot`) | ✅ 0.8.7 | Kod → yangi parol (recovery token 10 daq, bir martalik, login emas, barcha seanslar tugaydi). Kanal yo'q bo'lsa — administrator orqali yo'l ko'rsatiladi |
| A01 | Tahlil jarayoni | S03 ichida bosqichlar | 🟡 | Yuklash → tahlil bosqichlari, yuklashda bekor qilish, 60 s xabari ✅; server job holatlari (queued/processing) ⛔ — backend sinxron |
| A02 | Saqlanganlar | — | ⛔ | Bookmark API ⛔ |
| A03 | Vazifa tafsiloti | pastki oyna | ✅ 0.8.3 | — (tahrir, seriya: faqat shu / shu va keyingilar) |
| A04 | Kuzatuv/kundalik | S06 «Kundalik» tabi | 🟡 | Matn ✅ (2000 belgi); rasm biriktirish va yozuvni tahrirlash/o'chirish API ⛔ |
| A05 | Sozlamalar va hujjatlar | `/settings/about` | 🟡 0.8.6 | Versiya, yordam, manbalar, maxfiylik qoidalari; server manzili productionda yashirildi. Rasmiy shartlar/maxfiylik hujjati ⛔ (matn tasdiqlanmagan); bildirishnoma turlari sozlamasi ⛔ |
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

## 0.8.3 da backend'ga qo'shilgan

- `reminders`: `completed_at`, `series_id`, `repeat` (daily/weekly/monthly/custom), `repeat_every`, `repeat_until`, `remind_before` (migratsiya 0010). Takrorlash har sana uchun alohida yozuv yaratadi (≤ 200, ≤ 1 yil); oylikda oyning oxirgi kuni qoidasi.
- `GET /reminders/{id}`; `PUT`/`DELETE /reminders/{id}?scope=one|future`.
- Scheduler endi sana/vaqtni `APP_TIMEZONE` (Asia/Tashkent) bo'yicha talqin qiladi — avval UTC deb olinib, eslatma 5 soat kech kelardi. Kun bo'yi vazifa 08:00 da, `remind_before` hisobga olinadi.

## 0.8.4 da backend'ga qo'shilgan

- Migratsiya 0011: `plants.category` (vegetable/fruit/vine/grain/berry/melon; uzum — `vine`), `medicines.category`, `medicines.kind` (active/product/mixture), `medicines.label_verified`, `diseases/medicines.source` va `updated_at`. Seed yozuvlari nom bo'yicha tasniflandi.
- Doza siyosati (TZ S22): `label_verified = false` bo'lsa me'yor dehqonga ko'rsatilmaydi (katalog, S08, reja yaratish); parvarish rejasi vazifalariga ham tasdiqlanmagan doza yozilmaydi — purkash jadvali saqlanadi.

## 0.8.5 da backend'ga qo'shilgan

- Post: sarlavha 3–100, matn ≤ 3000; izoh 1–1000 belgi; bo'sh joylar kesiladi (avval 1 belgili sarlavha va cheksiz matn o'tardi).
- AI savol ≤ 4000 belgi; chat xabari bo'sh joylardan tozalanadi.
- `GET /users/{id}`: `about` va `district` qaytadi (telefon, email, manzil — yo'q).

## 0.8.6 da backend'ga qo'shilgan

- Migratsiya 0012: `subscriptions.paid_at`, `refunded_at`. API `payment_status` (paid/pending/failed/refunded) beradi — avval avto-yangilanishni o'chirish ham, muvaffaqiyatsiz to'lov ham bir xil `cancelled` edi.
- `GET /subscriptions/{id}` — buyurtma holati (faqat egasi). Tarixda oxirgi 24 soatdagi kutilayotgan buyurtma ham ko'rinadi.
- Avtomatik qayta yechish amalga oshirilmaganligi sababli yangi buyurtmalarda `auto_renew = false`; `/cancel` to'langan obunani endi «bekor qilingan» qilmaydi.
- `PUT /users/me/password`: `logout_others` (ixtiyoriy). Yuborilmasa — eski ilovalar uchun avvalgidek boshqa seanslar tugatiladi.

## 0.8.7 da backend'ga qo'shilgan

- Migratsiya 0013: `auth_challenges` (kod faqat HMAC-hash, maqsad, kanal, urinishlar, muddat, qayta yuborish) va `users.terms_version`, `terms_accepted_at`.
- `GET /auth/options` (kanallar, sinov rejimi, qoidalar versiyasi), `POST /auth/challenges`, `/challenges/{id}/resend`, `/challenges/{id}/verify`, `POST /auth/recovery/reset`.
- Kod yuborish provayderi yo'q: productionda kanallar e'lon qilinmaydi (`OTP_DEV_CODES`), development/test'da kod javobda qaytadi. Provayder ulanganda faqat `otp_service.deliver()` o'zgaradi.
- `/auth/register`: username ixtiyoriy (server yaratadi), `accept_terms`. 429 javoblarida `Retry-After`; CORS `Retry-After`, `X-Attempts-Left` ni ochadi.

## Ekin holati qoidasi (TZ 1-bo'lim)

Foiz ko'rsatilmaydi. `last_diagnosis_at` yo'q → «Ma'lumot yetarli emas»; oxirgi tashxisda kasallik va
`health_score < 45` → «E'tibor kerak»; kasallik bor yoki `< 70` → «Kuzatuv kerak»; aks holda «Sog'lom · {sana}»
(oxirgi kuzatuv sanasi bilan vaqtli xulosa).
