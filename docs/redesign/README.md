# Qayta loyihalash (0.2)

Bosqichma-bosqich: har bir bosqich prototipda ko'rib chiqiladi va tasdiqlangandan keyin keyingisiga o'tiladi.

| # | Bosqich | Holat | Prototip |
|---|---|---|---|
| 1 | Tuzilma: rollar, ekranlar, yo'llar | ✅ tasdiqlandi | https://claude.ai/artifact/31r6AYudsnhp5mjyRw34F9 |
| 2 | Dizayn tizimi "Yashil dala 2.0" | ✅ tasdiqlandi (keyin to'ldirib boriladi) | https://claude.ai/artifact/YDVzxLYy3nk3wcimFtsohM |
| 3 | Dehqon ekranlari | ko'rib chiqilmoqda | https://claude.ai/artifact/Eem1jBJwa5EAb5S8cjPrjj |
| 4 | Agronom ekranlari | — | |
| 5 | Admin web panel | — | |
| 6 | Kod: rollar, ekranlar, admin panel; so'ng AI va dataset | — | |

## 1-bosqichda tasdiqlangan qarorlar

- **Rollar:** dehqon (`user`), agronom (`agronomist`, yangi), admin. Moderator roli admin ichiga kiradi.
- **Agronom vazifalari:** AI tashxisini tasdiqlash/tuzatish, dehqonga chatda maslahat, bilimlar bazasini yuritish, jamoatda "Agronom javobi".
- **Bitta mobil ilova:** agronom kirganda o'z menyusi ochiladi (Savollar · Jamoat · [Navbat] · Bilimlar · Profil).
- **Dehqon menyusi:** Bosh · Bog'im · [Tashxis] · Maslahat · Profil. "Maslahat" = Agronomlar + AI yordamchi + Jamoat.
- **Agronom maslahati:** oyiga 2 ta savol bepul, Premium'da cheksiz.
- **Agronom bo'lish:** Profil → "Men agronomman" arizasi → admin tasdiqlaydi.
- **Admin:** alohida web panel `/admin` (faqat kompyuter); mobil ilovadan admin bo'limi olib tashlanadi.
- **Tashxis → agronom:** AI ishonchi 70% dan past bo'lsa "Agronomga yuborish" taklif qilinadi; agronom tasdiqlagan rasm datasetga "tasdiqlangan" bo'lib tushadi.

## Dizayn tizimi

`tokens.json` — "Yashil dala 2.0" tokenlari (ranglar ikki mavzuda, tipografiya, bo'shliq, radius, soya, o'lcham, harakat).
To'liq qoidalar va komponentlar — yuqoridagi 2-bosqich havolasida.

## 3-bosqich: qo'shimcha talab

- **Ma'lumotnoma — to'liq katalog**, bosh ekrandan ochiladi, uch bo'lim: **O'simliklar** (har birida uchraydigan kasalliklar va ishlatiladigan dorilar), **Kasalliklar** (ekin bo'yicha filtr, xavflilari birinchi), **Dorilar** (turi, me'yori, ehtiyot choralari, qaysi kasalliklarga qarshi). Umumiy qidiruv uchala bo'limdan.
- Rasmli bo'ladi: har bir ekinning sog'lom barg rasmi va har bir kasallikning belgilari ko'rinadigan rasmi.
  Manba — PlantVillage dataseti (AI modeli shu rasmlarda o'qitilgan). Hozir 28 kasallikdan 25 tasining rasmi bor;
  bodring un shudringi, uzum oidiumi va bodring ildiz chirishi uchun rasm dala datasetidan to'ldiriladi.
- Kasallik sahifasida sog'lom va kasal bargni yonma-yon solishtirish.
