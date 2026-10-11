# Dala dataseti va AI'ni qayta o'qitish

Model hozir PlantVillage'da (laboratoriya rasmlari) o'qitilgan. Dala suratlarida aniqligi pastroq.
Uni yaxshilashning eng samarali yo'li — ilova foydalanuvchilari yuklagan **haqiqiy** rasmlar.

## 1. Rasmlar qanday yig'iladi

1. Dehqon AI tashxis qiladi — rasm serverda saqlanadi; AI ning eng ehtimolli 3 sinfi yoziladi (`ai_label`, `ai_top`).
2. Ishonchi past bo'lsa yoki dehqon "Agronomga ko'rsatish"ni bossa, tashxis agronom navbatida birinchi turadi.
3. Agronom (mobil ilova → agronom rejimi → Navbat) rasmni ko'radi:
   - AI variantlaridan to'g'risini tanlaydi (**tasdiqlash** yoki **tuzatish**);
   - "Boshqa kasallik" — ma'lumotnoma rasmlari bilan solishtirib boshqa sinf (model hali bilmaydigan, masalan bodring kasalliklari ham);
   - "Rasm yaroqsiz" — barg ko'rinmaydi, xira — datasetga kirmaydi.
4. Tasdiqlangan/tuzatilgan rasm datasetga tushadi. Har 5 tadan biri (tashxis id'si bo'yicha, o'zgarmas) —
   **dala rasmlari testi**: u hech qachon o'qitilmaydi, faqat modellarni solishtirish uchun.

Admin panel → **AI va dataset** → "Sinflar bo'yicha dala rasmlari": har sinfda nechta rasm (o'qitish / test),
maqsad — 200 ta; model hali bilmaydigan sinflar birinchi ko'rsatiladi.

## 2. Qayta o'qitishni yoqish (bir marta)

1. GitHub → o'ng yuqorida rasm → **Settings → Developer settings → Personal access tokens → Fine-grained tokens →
   Generate new token**:
   - *Repository access*: **Only select repositories** → `Aziimuslim/agroyordam`;
   - *Permissions → Repository → Actions*: **Read and write** (boshqa hech narsa kerak emas);
   - *Expiration*: 1 yil.
2. Serverda: `cd /opt/agroyordam && sudo bash deploy/enable-training.sh` → tokenni qo'ying (ekranda ko'rinmaydi).
   Token faqat serverdagi `.env` da saqlanadi.

## 3. Qayta o'qitish va yangi modelni ishga tushirish

1. Admin panel → **AI va dataset → "Qayta o'qitishni boshlash"**.
   Server GitHub Actions'ni ("Train AI model") ishga tushiradi va unga datasetni **bir martalik, 3 soatlik** havola orqali beradi
   (havola yuklab olingach o'chadi; ZIP'da faqat rasm va sinf — foydalanuvchi ma'lumoti yo'q).
2. ~1 soat: PlantVillage + dala rasmlari (`train/`) bilan o'qitiladi, so'ng **dala rasmlari testi** (`test/`) da
   yangi model va hozir ishlayotgan model aynan bir xil rasmlarda baholanadi. Bosqichlar admin panelda ko'rinadi.
3. Natija — yangi **nomzod** versiya `model-vN` (GitHub Release). Jadvalda: PlantVillage testi, dala testi (yangi va hozirgi).
4. **"Ishga tushirish"** — faqat dala testida yangi model hozirgisidan yomon bo'lmasa. AI xizmati versiyani yuklab olib,
   tekshirib, to'xtamasdan almashtiradi; tanlov server qayta yuklanganda ham saqlanadi.
   Dala testi uchun rasm bo'lmasa — "Dala testisiz ishga tushirish" (ogohlantirish bilan).
5. Muammo bo'lsa — eski versiya qatorida **"Qaytarish"** (bir bosishda). Har bir almashtirish harakatlar jurnaliga yoziladi.

Qo'lda (token'siz) ham mumkin: Admin panel → "Dataset eksporti" → ZIP'ni GitHub Release'ga yuklang → **Actions → Train AI model →
Run workflow** → `dataset_url` ga havola, `baseline_tag` ga hozirgi versiya (masalan `model-v1`).

Lokal o'qitish: `python training/train_plantvillage.py --data <PlantVillage/raw/color> --extra <zip>/train --field-test <zip>/test
--baseline-model <hozirgi.onnx>`. Dala rasmlari o'qitishda 3 marta takrorlanadi (`--extra-weight`), chunki ular kam, lekin qimmatli.

## 4. Yangi ekin/kasallik qo'shish (masalan, bodring)

1. Katalogda kasallikni qo'shing va `ai_label` ni bering (masalan `Cucumber_Downy_mildew`) — shunda AI shu sinfni topganda
   foydalanuvchiga o'zbekcha ma'lumot va dorilar chiqadi. (Bodring: `Cucumber_Powdery_mildew`, `Cucumber_Root_rot` allaqachon bor.)
2. Dehqonlar bodring rasmini yuborganda agronom navbatda "Boshqa kasallik" orqali to'g'ri sinfni tanlaydi
   (kamida 30–50 ta, yaxshisi 200+; "sog'lom" bodring rasmlari ham kerak — `Cucumber_healthy`).
3. Qayta o'qiting — sinf modelga avtomatik qo'shiladi. Agronom shu sinf uchun ma'lumotnoma rasmini ham
   datasetdan tanlay oladi (agronom rejimi → Bilimlar → kasallik → "Datasetdan tanlash").

## Maslahatlar

- Har bir sinfda rasmlar soni taxminan teng bo'lsin; "sog'lom" rasmlar ham kerak.
- Bir xil bargning 10 ta surati 10 xil barg o'rnini bosmaydi — turli dala, vaqt, telefonlardan yig'ing.
- Shubhali rasmlarni "Yaroqsiz" qiling — noto'g'ri belgilangan rasm modelga yaxshi rasmdan ko'ra ko'proq zarar qiladi.
