# Qabul sinovi skriptlari (TZ 10, 13.7)

Playwright (Node) bilan. Natijalar `out/` ga yoziladi (repoga kirmaydi).

- `crawl.js` — barcha S/A sahifalarini o'lchamlar × mavzular × matn shkalasi bo'yicha aylanadi va Flutter
  konsolidagi toshish/istisnolarni yig'adi. **Debug** build kerak (release'da Flutter toshishni yozmaydi):
  `flutter run -d web-server --no-web-resources-cdn --web-port 8090 --dart-define=API_URL=http://localhost:8000`
  - `BASE` (standart `http://127.0.0.1:8090`), `SIZES=320,390,768,1440`, `SCHEMES=light,dark`, `SCALE=2` (200% matn), `LANG_CODE=ru`, `ONLY=S12,S13` (faqat shu sahifalar)
- `flows.js` — QA02 returnTo, QA04 Back/Forward, QA13 chiqishdan keyin Back, QA14 klaviatura (release build, `BASE` standart `:8080`).
- `dm.js` — DM01/DM02 ilk ochilish foni (release build).

`ids.json` (`IDS` bilan boshqa joydan): sinov bazasidagi `crop`, `diag`, `post`, `author`, `plant`, `disease`,
`medicine`, `conv` identifikatorlari; foydalanuvchi `akmal` / `Secret123!`.
