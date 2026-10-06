# Zaxira nusxalar (backup)

## Qanday ishlaydi

`backup` servisi (`deploy/backup/backup.sh`) har kuni **03:00 (Toshkent)** da:

1. PostgreSQL bazasining to'liq nusxasini oladi: foydalanuvchilar, bog'lar, tashxislar, eslatmalar, jamoat, to'lovlar.
2. Yuklangan rasmlarni (tashxis rasmlari va AI dataset) arxivlaydi.
3. Ikkalasini serverdagi `/opt/agroyordam/backups` papkasiga yozadi. U yerda **7 kun** saqlanadi.
4. Tashqi xotira sozlangan bo'lsa, nusxani **server tashqarisiga** ham yuboradi:
   - `db/agroyordam-<sana>.sql.gz` — bazaning nusxalari, **30 kun** saqlanadi;
   - `media/` — rasmlar. Har safar faqat yangilari yuboriladi.

Zaxira xato bilan tugasa, servis 1 soatdan keyin qayta urinadi. GitHub Actions'dagi **"Backup tekshiruvi"** har kuni
10:17 da holatni tekshiradi. Oxirgi muvaffaqiyatli nusxa 26 soatdan eski bo'lsa yoki zaxira xato bilan tugagan bo'lsa,
workflow qizil bo'ladi va GitHub sizga email yuboradi.

> Serverdagi nusxa disk yoki server yo'qolganda yordam bermaydi. Shuning uchun tashqi xotirani albatta yoqing.

---

## Tashqi xotirani yoqish — Oracle Object Storage (bepul, 20 GB)

### 1. Bucket yaratish
1. https://cloud.oracle.com ga kiring.
2. ☰ menyu → **Storage** → **Object Storage & Archive Storage** → **Buckets** ni oching.
3. Chap tomondagi **Compartment** maydonida **root** compartment tanlanganini tekshiring.
   Bu sizning akkaunt nomingiz, `(root)` belgisi bilan.
4. **Create Bucket** tugmasini bosing:
   - Bucket name: `agroyordam-backups`;
   - Default storage tier: **Standard**;
   - qolgan maydonlarni o'zgartirmang.

   So'ng **Create** ni bosing.
5. Yaratilgan bucket'ni oching. **Bucket information** bo'limidan **Namespace** qiymatini nusxalab oling
   (masalan, `frabc1xyz2de`).

   ⚠️ Bucket'ni **Public** qilmang. Odatiy holatda u **Private** bo'ladi, shunday qolsin.

### 2. Kalit olish (Customer secret key)
1. O'ng yuqoridagi profil belgisi → **My profile** ni oching.
2. Pastda **Customer secret keys** bo'limini toping. U **Tokens and keys** yorlig'i ichida bo'lishi mumkin.
3. **Generate secret key** ni bosing, nomini `agroyordam-backup` qo'ying va **Generate secret key** ni bosing.
4. Chiqqan **Secret key** ni darhol nusxalab oling — u faqat **bir marta** ko'rsatiladi.
5. **Close** ni bosgandan keyin ro'yxatda **Access key** ustuni paydo bo'ladi. Uni ham nusxalab oling.

### 3. Serverda yoqish
```bash
ssh -i ~/.ssh/agroyordam ubuntu@130.61.36.184
cd /opt/agroyordam
sudo bash deploy/enable-offsite-backup.sh
```
Skript quyidagilarni so'raydi:

| Savol | Javob |
|---|---|
| Namespace | 1-qadamdagi namespace |
| Region | `eu-frankfurt-1` (Enter) |
| Bucket nomi | `agroyordam-backups` (Enter) |
| Access key / Secret key | 2-qadamdagi kalitlar |
| Necha kun saqlash | `30` (Enter) |

Skript darhol sinov zaxirasini oladi. Hammasi to'g'ri bo'lsa, `✅ Tayyor` yozuvi chiqadi. Oracle'dagi bucket ichida
`agroyordam/db/...` va `agroyordam/media/...` paydo bo'ladi.

Kalitlar faqat serverdagi `.env` faylida (`chmod 600`) saqlanadi. GitHub'ga yoki boshqa joyga yuborilmaydi.

### Boshqa xizmatlar
Cloudflare R2, Backblaze B2, AWS S3 va boshqa S3-mos xotiralar ham ishlaydi. Namespace so'ralganda to'liq Endpoint
URL'ni kiriting (masalan, `https://<account>.r2.cloudflarestorage.com`). Region uchun R2'da `auto` deb yozing.

---

## Kundalik foydalanish

| Nima | Qanday |
|---|---|
| Holatni ko'rish | GitHub → Actions → **Backup tekshiruvi** → Run workflow (`backup-status`) |
| Hozir zaxira olish | xuddi shu, `backup-now` |
| Nusxalar ro'yxati | xuddi shu, `backup-list` |
| Serverda | `cd /opt/agroyordam && sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml exec backup backup.sh check` |

---

## Tiklash

```bash
cd /opt/agroyordam
sudo bash deploy/restore.sh                    # mavjud nusxalar ro'yxati
sudo bash deploy/restore.sh latest             # eng oxirgisi
sudo bash deploy/restore.sh 2026-10-06_2200    # aniq nusxa (sana_soat, UTC)
```
Tiklash paytida backend to'xtatiladi, baza nusxadagi holatga **almashtiriladi**, rasmlar esa qaytarib qo'shiladi.
Bu bir necha daqiqa oladi.

### Server butunlay yo'qolsa
1. Yangi server oching va `docs/ORACLE_FREE.md` bo'yicha `setup-server.sh` gacha bajaring.
2. `sudo bash deploy/enable-offsite-backup.sh` ni ishga tushirib, xuddi o'sha bucket va kalitlarni kiriting.
3. `sudo bash deploy/restore.sh latest` buyrug'i bilan hamma ma'lumot qaytadi.
4. DuckDNS'da IP manzilni yangilang. GitHub secret'idagi `SERVER_HOST` ni ham yangilang va
   `deploy/enable-autodeploy.sh` ni qayta ishga tushiring.

Yangi serverda `SECRET_KEY` boshqacha bo'ladi. Shuning uchun foydalanuvchilar ilovaga qaytadan kirishadi.
Parollari va ma'lumotlari saqlanib qoladi.

> Maslahat: `.env` faylining nusxasini (to'lov kalitlari bilan birga) parol menejerida saqlang. U zaxiraga kirmaydi.
