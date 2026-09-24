# Dala dataseti va AI'ni qayta o'qitish

Model hozir PlantVillage'da (laboratoriya rasmlari) o'qitilgan. Dala suratlarida aniqligi pastroq.
Uni yaxshilashning eng samarali yo'li — ilova foydalanuvchilari yuklagan **haqiqiy** rasmlar.

## 1. Rasmlar qanday yig'iladi

1. Foydalanuvchi AI tashxis qiladi — rasm serverda saqlanadi, AI sinfi (`ai_label`) yoziladi.
2. Natija ostida **"AI to'g'ri topdimi? Ha / Yo'q"** — "Yo'q" deganlar tekshiruv navbatida birinchi turadi.
3. Mutaxassis (agronom, `admin` yoki `moderator` roli) **Admin panel → Dataset** bo'limida har bir rasmni ko'radi:
   - **To'g'ri** — AI sinfi to'g'ri;
   - **Tuzatish** — to'g'ri sinfni tanlaydi (yoki yangi sinf yozadi: `Ekin_Kasallik`, masalan `Cucumber_Downy_mildew`);
   - **Yaroqsiz** — barg ko'rinmaydi, boshqa narsa, juda xira — datasetga kirmaydi.
4. Statistikada: har bir sinfda nechta tasdiqlangan rasm borligi (maqsad — 200 ta) va **AI dala aniqligi**
   (mutaxassis tekshirgan rasmlarda AI necha foiz to'g'ri chiqqani — haqiqiy sharoitdagi aniqlik).

Moderator qo'shish: `docker compose ... exec backend python -m app.create_admin --username agronom --email ... --role moderator`

## 2. Eksport

**Dataset → "ZIP yuklab olish"** — tasdiqlangan rasmlar papkalarga ajratilgan holda:

```
agroyordam-dataset-2026-10-01.zip
├── Tomato_Late_blight/<id>.jpg
├── Tomato_healthy/<id>.jpg
├── Cucumber_Downy_mildew/<id>.jpg   ← yangi sinf ham bo'lishi mumkin
├── manifest.csv                     (fayl, sinf, AI sinfi, ishonch, holat, sana)
└── README.txt
```

Havola 10 daqiqa amal qiladi va faqat admin/moderator uchun. ZIP'da foydalanuvchi ma'lumotlari yo'q (faqat rasm va sinf).

## 3. Qayta o'qitish (GitHub Actions, bepul)

1. ZIP'ni GitHub'ga yuklang: repo → **Releases → Draft a new release** → tag: `dataset-2026-10` →
   ZIP faylni tortib tashlang → **Publish**. Fayl havolasini nusxalang
   (`https://github.com/Aziimuslim/agroyordam/releases/download/dataset-2026-10/agroyordam-dataset-2026-10-01.zip`).
2. **Actions → "Train AI model" → Run workflow** → `dataset_url` maydoniga havolani qo'ying → **Run**.
3. ~1 soatdan keyin yangi model `model-v1` release'iga yuklanadi. `agro-mobilenetv3.metrics.json` da:
   - `val_accuracy_onnx` — umumiy aniqlik;
   - `val_accuracy_field` — **dala rasmlaridagi aniqlik** (asosiy ko'rsatkich);
   - `per_class_accuracy` — har bir sinf.
   Aniqlik 85% dan past bo'lsa, model yuklanmaydi (workflow xato beradi).
4. Serverda AI servisni qayta yig'ing (yangi modelni yuklab oladi):
   ```bash
   cd /opt/agroyordam
   sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache ai-service
   sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d ai-service
   ```

Lokal o'qitish (GPU/CPU): `python training/train_plantvillage.py --data <PlantVillage/raw/color> --extra <ochilgan ZIP papkasi>`.
Dala rasmlari o'qitishda 3 marta takrorlanadi (`--extra-weight`), chunki ular kam, lekin qimmatli.

## 4. Yangi ekin/kasallik qo'shish (masalan, bodring)

1. Katalogda kasallikni qo'shing va `ai_label` ni bering (masalan `Cucumber_Downy_mildew`) — shunda AI shu sinfni topganda
   foydalanuvchiga o'zbekcha ma'lumot va dorilar chiqadi.
2. Dataset'da shu sinf bo'yicha rasmlarni "Tuzatish" orqali belgilang (kamida 50–100 ta, yaxshisi 200+).
3. Qayta o'qiting — sinf modelga avtomatik qo'shiladi.

## Maslahatlar

- Har bir sinfda rasmlar soni taxminan teng bo'lsin; "sog'lom" rasmlar ham kerak.
- Bir xil bargning 10 ta surati 10 xil barg o'rnini bosmaydi — turli dala, vaqt, telefonlardan yig'ing.
- Shubhali rasmlarni "Yaroqsiz" qiling — noto'g'ri belgilangan rasm modelga yaxshi rasmdan ko'ra ko'proq zarar qiladi.
