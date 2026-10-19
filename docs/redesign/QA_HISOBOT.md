# Qabul sinovlari hisoboti — 0.8.10

TZ 10 (QA01–QA16), 11 va 13.7 (DM01–DM12) bo'yicha. Sinov sanasi: 2026-10-20. Agronom va admin panellari bu
bosqichda sinalmadi (o'zgartirilmagan).

## Muhit va usul

| | |
|---|---|
| Backend | FastAPI, SQLite (lokal), `pytest` — 87 test |
| Mobil | Flutter web; `flutter test` — 23 test; `dart analyze` toza |
| Sahifa aylanishi | **debug** web build (`flutter run -d web-server`) + Playwright. Debug rejimda Flutter har bir toshish (overflow) va istisnoni konsolga yozadi — skript ularni yig'adi |
| Qamrov | 46 sahifa (S01–S36, A02–A08, Welcome, Yordam) × 320 / 390 / 768 / 1440 px × yorug' / qorong'i = **368 tekshiruv**; 200% matn: 46 × 320 / 390 × 2 mavzu = **184 tekshiruv** |
| 200% matn | brauzer shrift o'lchami 32 px (Flutter web matn shkalasini shundan oladi) |
| Oqim sinovlari | release build + Playwright: returnTo, Back/Forward, chiqishdan keyin Back, faqat klaviatura bilan kirish, ilk ochilish foni |
| Cheklov | Sandbox tashqi internetga chiqmaydi: Open-Meteo, SMS/email, to'lov provayderlari mock/sandbox bilan; jismoniy Android qurilma va ekran o'quvchisi yo'q |

Skriptlar: `mobile/tool/qa/` (crawl, flows, dm). Natija JSON va skrinshotlar artefakt sifatida saqlanmaydi — skript qayta ishga tushirib olinadi.

## Natija

| ID | Ssenariy | Holat | Dalil |
|---|---|---|---|
| QA01 | Ro'yxatdan o'tish: noto'g'ri telefon, roziliksiz, xato/eskirgan OTP, resend, dublikat yo'q | ✅ (sinov rejimi) | `test_otp`: register_by_code, register_rules, resend_expiry_and_attempts; 0.8.7 e2e. Haqiqiy SMS ⛔ provayder yo'q |
| QA02 | Sessiyasiz shaxsiy havola → kirish → shu sahifa; tashqi returnTo rad | ✅ | e2e: `/garden/:id?tab=diary` → `/welcome` → kirish → `/garden/:id?tab=diary`; unit: `safeReturnTo` (`//`, `https://`, `/auth/*` rad) |
| QA03 | Ekin yaratish/tahrir/arxiv/tiklash, dublikat yo'q | ✅ / 🟡 | `test_crops_crud_logs_and_limit`, `test_crop_photo_validation_and_archive`; ikki marta bosish himoyasi UI'da. Tarmoq uzilganda takroriy so'rov uchun idempotentlik kaliti yo'q |
| QA04 | Back: query/tab saqlanadi; dirty forma dialogi; Forward | ✅ | e2e: `/catalog?tab=diseases` → tafsilot → Back → tab saqlangan → Forward. Dirty forma dialogi: S05, S12, S24, S26, S28, S31, S32, S34, A04 |
| QA05 | Kamera ruxsati, galereya, katta/buzilgan fayl, bekor qilish | 🟡 | Katta/buzilgan fayl: `test_invalid_image_and_daily_limit`; galereya web'da. OS ruxsat oqimlari faqat qurilmada — sinalmadi |
| QA06 | AI: holatlar, past ishonch, noma'lum ekin, servis ishlamasa | 🟡 | `test_healthy_and_low_confidence`, `test_ai_service_down`. queued/processing ⛔ — backend sinxron (A01) |
| QA07 | Reja: preview, checkbox rollback, takrorlash, muddati o'tgan, vaqt zonasi | ✅ | `test_care_plan_adds_diagnosis_to_garden`, `test_reminder_series_scope_and_validation`, `test_scheduler_sends_due_reminders_once` (Asia/Tashkent) |
| QA08 | Jamoat: post, like rollback, izoh/delete, bookmark, bloklangan muallif | 🟡 | `test_posts_likes_comments`, `test_bookmarks`, `test_search_and_block`, `test_community_limits`. 5 rasmli post ⛔ (backend bitta rasm), izohga javob ⛔ |
| QA09 | Chat: pending/sent/read/failed, reconnect, eski xabarlar sahifasi | ✅ / 🟡 | UI holatlari (0.8.5); **0.8.10: eski xabarlar sahifasi qo'shildi** — `test_message_pagination`. "delivered" va rasm yuborish ⛔ — soxta holat ko'rsatilmaydi |
| QA10 | Katalog: bo'sh natija, rasm yo'q, noto'g'ri ID | ✅ | `test_public_catalog`, `test_catalog_meta`; aylanishda barcha katalog sahifalari 0 xato |
| QA11 | Push | ⛔ | Ilovada FCM mijozi yo'q (A05 da ochiq yozilgan) |
| QA12 | To'lov: paid/pending/failed/cancelled/refunded, takroriy callback | ✅ | `test_payme_full_cycle`, `test_payme_cancel_before_perform_and_timeout`, `test_click_*`, `test_subscription_webhook_flow` (idempotent), `test_order_status_pending_and_owner_only`. Chek ⛔ |
| QA13 | Hisob: band username, parol mismatch, token muddati, chiqishdan keyin Back | ✅ | `test_register_duplicate_and_validation`, `test_refresh_rotation_and_logout`, `test_change_password_logout_others_optional`; e2e: chiqish → Back → `/welcome`. Aloqa tasdiqlash ⛔ (provayder) |
| QA14 | 320/390/768/1440, ikki mavzu, 200% matn, klaviatura, ekran o'quvchisi, kam harakat, uzun tarjima | ✅ / 🟡 | Aylanish: 368 + 184 tekshiruv — tuzatishlardan keyin **0 toshish**; klaviatura bilan kirish (Tab/Enter) e2e ✅; kam harakat — S31; rus tilida 320 px aylanish. Haqiqiy ekran o'quvchisi bilan sinov ⛔ (semantik yorliqlar kod darajasida) |
| QA15 | Ob-havo: kun/tun/yomg'ir, eskirgan kesh, provayder xatosi | ✅ | `test_weather_night`, `test_get_weather_parses_and_caches`, `test_weather_endpoint` (503), `test_forecast_hourly_daily`. Fon holatida animatsiya: Flutter yashirin tabda kadrlarni to'xtatadi |
| QA16 | Parallel qurilmalar: konfliktda ma'lumot jim yo'qolmaydi | 🟡 | Kundalik: versiya konflikti 409 (`test_diary`); o'qilgan belgisi serverda. Vazifa/profil uchun versiya nazorati yo'q (oxirgi yozuv ustun) |
| DM01 | Ilk ochilishda oq chaqnash yo'q | ✅ **tuzatildi** | e2e: tizim qorong'i → fon `#101912` 150 ms da; Android splash `values-night` |
| DM02 | Light → Dark → System saqlanadi, restartdan keyin ham | ✅ **tuzatildi** | Tanlov `main()` da birinchi kadrdan oldin o'qiladi; e2e: saqlangan "dark" + tizim yorug' → qorong'i fon |
| DM03 | S31 namunasi saqlanmasa global o'zgarmaydi | ✅ | 0.8.6 (namuna lokal `Theme`) |
| DM04 | Har sahifa qorong'i mavzuda | ✅ | 46 sahifa × 4 o'lcham qorong'i — 0 xato, kontakt varaqlarida tasodifiy oq panel yo'q |
| DM05 | Forma to'ldirilganda mavzu almashsa qiymat yo'qolmaydi | 🟡 | Mavzu `MaterialApp` darajasida, sahifa holati qayta yaratilmaydi; alohida avtomatik sinov yo'q |
| DM06 | Chat/tahlil/to'lov paytida OS mavzusi o'zgarishi | 🟡 | Mavzu o'zgarishi API'ni qayta chaqirmaydi (provayderlar mavzuga bog'liq emas); avtomatik sinov yo'q |
| DM07 | 320/390/768/1440, 200% matn, klaviatura ikkala mavzuda | ✅ | QA14 bilan bir xil |
| DM08 | Kontrast | ✅ | `DM08` unit test: matn, ikkilamchi matn, asosiy tugma, olive, xato, forma chegarasi — ikkala mavzu |
| DM09 | Rasmlar invert qilinmaydi | ✅ | Rasmlarga rang filtri qo'llanmaydi (kod) |
| DM10 | Ob-havo holatlari ikkala mavzuda, kam harakat | ✅ | Manzara effekti `disableAnimations` ga bo'ysunadi; S31 "Kamaytirilgan" |
| DM11 | Holat faqat rang bilan emas | ✅ | To'lov holatlari yorliq bilan, o'qilmagan — nuqta + son, xabar holati — ikonka + matn |
| DM12 | Chekka oqimlar (login, OTP, tiklash, to'lovdan qaytish) mavzuga mos | ✅ | S33–S36 ikkala mavzuda aylanishda; web fonida saqlangan tanlov |

## Yakuniy aylanish (tuzatishlardan keyin)

| O'tish | Tekshiruv | Xato |
|---|---|---|
| 1x: 46 sahifa × 320/390/768/1440 × yorug'/qorong'i | 368 | 0 |
| 200% matn: 46 sahifa × 320/390 × yorug'/qorong'i | 184 | 0 |
| Rus tili (uzun tarjima): 46 sahifa × 320 px | 46 | 0 |
| Oqimlar: QA02, QA04, QA13, QA14 | 7 | 0 |
| DM01/DM02 ilk ochilish foni (4 kombinatsiya) | 4 | 0 |

**Cheklov:** 320 px va 200% matn birga bo'lganda tor ustunlardagi (masalan, kalit yonidagi sarlavha) uzun so'zlar
keyingi qatorga bo'linib ketadi. Toshish yo'q va matn o'qiladi, lekin ko'rinish qo'pol. 390 px va undan kengda,
yoki 200% dan kichik shkalada bunday holat kuzatilmadi.

## 0.8.10 da topilgan va tuzatilgan nuqsonlar

| # | Daraja | Joy | Nuqson | Tuzatish |
|---|---|---|---|---|
| 1 | P2 | Web (DM01) | `index.html` foni qattiq och rang — qorong'i rejimda ilova yuklanguncha oq chaqnash; `theme-color` eski yashil | Fon tizim rejimiga va saqlangan tanlovga mos; `theme-color` ikki rejim uchun |
| 2 | P2 | Android (DM01) | Splash ikkala rejimda oq | `values` / `values-night` ranglari |
| 3 | P2 | Ilova (DM02) | Mavzu, matn o'lchami, harakat sozlamasi birinchi kadrdan keyin yuklanardi — noto'g'ri mavzu chaqnashi | `main()` da oldindan o'qiladi |
| 4 | P2 | S01, S25 (320 px) | Vazifa qatorida "Kechikkan" so'z o'rtasidan bo'linardi | Bir qatorda, kerak bo'lsa kichrayadi |
| 5 | P2 | S07 (320 px) | Holat yorlig'i 32 px toshardi | Moslashuvchan matn |
| 6 | P2 | 18 fayl, 33 tugma | Tugmalar qattiq 52 px — katta matnda matn kesilish xavfi (S31 qabul mezoni) | "Kamida 52 px" |
| 7 | P2 | S01, S08, S16, S18, A06, Yordam (200%) | Toshish 2.7–85 px | Moslashuvchan qatorlar, Wrap, ob-havo kartalari matn shkalasiga mos |
| 8 | P2 | Barcha bo'lim sarlavhalari (200%) | Sarlavha yonidagi amal joy olib, sarlavha harfma-harf vertikal yozilardi | Sig'masa amal keyingi qatorga; **nochiziqli matn shkalasi** — oddiy matn 200%, yirik sarlavhalar kamroq |
| 9 | P2 | S16 (QA09) | Suhbat faqat oxirgi 100 xabarni ko'rsatardi, eskilariga yo'l yo'q | `before` kursori, "Oldingi xabarlar" (50 tadan) |
| 10 | P3 | Welcome | Eski "Yashil dala" dizayni | Tabiiy Agro manzarasi |

P0 va P1 darajadagi ochiq nuqson yo'q.

## Ochiq qolganlar (tashqi qaror yoki katta ish kerak)

- SMS/email provayderi (QA01, QA13) va rasmiy qoidalar matni — buyurtmachi qarori.
- Push (QA11): Firebase loyihasi va ilovada FCM mijozi.
- ~~AI tahlil holatlari (QA06/A01)~~ — 0.8.12 da bajarildi (e2e: real ONNX model bilan oddiy oqim, AI to'xtatilgan holda bekor qilish — tashxis yaratilmadi, ekrandan chiqilganda fonda tugab bildirishnoma keldi).
- ~~5 rasmli post va izohga javob (QA08), rasmli xabar va "delivered" (QA09)~~ — 0.8.11 da bajarildi (e2e: post 5 rasm + ko'ruvchi, javob va o'chirilgan ota izoh, chatda rasm, yuborildi → yetkazildi → o'qildi; crawler S11–S16, A02: 1x 56, 200% 20, RU 320px 8 tekshiruv — 0 xato).
- Haqiqiy qurilmada: kamera ruxsatlari (QA05), ekran o'quvchisi (QA14), Android splash vizual tekshiruvi.
