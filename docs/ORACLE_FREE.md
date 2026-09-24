# Bepul server: Oracle Cloud + DuckDNS (qadam-baqadam)

Natija: `https://agroyordam.duckdns.org` (yoki siz tanlagan nom) manzilida web ilova ishlaydi, APK esa shu serverga o'zi ulanadi.
Hammasi bepul. Taxminiy vaqt: **1–1,5 soat** (asosiy qismi kutish).

Kerak bo'ladigan narsalar:
- Bank kartasi (Visa/Mastercard). Oracle faqat tekshirish uchun so'raydi, bepul limitda pul yechmaydi.
- Email va telefon raqam.
- Kompyuter (Windows, Mac yoki Linux).

---

## 1-qadam. Oracle Cloud'da ro'yxatdan o'tish (~15 daqiqa)

1. Ro'yxatdan o'tish sahifasini oching: **https://signup.cloud.oracle.com**
2. Ma'lumotlarni to'ldiring:
   - **Country/Territory:** Uzbekistan
   - Ism, email → emailga kelgan havola orqali tasdiqlang.
   - **Cloud Account Name** — istalgan nom (masalan `agroyordam`). Buni eslab qoling, kirishda so'raladi.
   - **Home Region** — ⚠️ keyin **o'zgartirib bo'lmaydi**. Yaqin hududni tanlang, masalan **Germany Central (Frankfurt)**.
     Ampere A1 serveri hamma hududda bo'lavermaydi. Frankfurtda "joy yo'q" xatosi tez-tez chiqsa, boshqa Yevropa hududi ham bo'ladi.
3. Manzil, telefon (SMS kod) va karta ma'lumotlarini kiriting. Kartadan kichik summa vaqtincha ushlab turilib, keyin qaytariladi.
4. "Account is being provisioned" yozuvi chiqadi. Hisob tayyor bo'lgach, email keladi (odatda 5–15 daqiqa).
5. Kirish sahifasi: **https://cloud.oracle.com** → Cloud Account Name → email/parol.

## 2-qadam. SSH kalit yaratish (o'z kompyuteringizda, 2 daqiqa)

Windows'da **PowerShell**, Mac/Linux'da **Terminal**ni oching:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/agroyordam -C "agroyordam"
```
(parol so'rasa — Enter bosib o'tkazib yuborsangiz bo'ladi)

Ochiq (public) qismini ko'rish:
```bash
cat ~/.ssh/agroyordam.pub
```
Chiqqan `ssh-ed25519 AAAA... agroyordam` qatorini to'liq nusxalab qo'ying — keyingi qadamda kerak.

## 3-qadam. Server yaratish (~10 daqiqa)

1. Instance'lar sahifasini oching: **https://cloud.oracle.com/compute/instances**
   - Chap tomonda **Compartment** — `(root)` tanlangan bo'lsin.
2. **Create instance** tugmasini bosing.
3. **Name:** `agroyordam`
4. **Image and shape** bo'limida **Edit** ni bosing:
   - **Change image** → **Canonical Ubuntu** → **24.04** → Select.
   - **Change shape** → **Ampere** → **VM.Standard.A1.Flex**.
     **Number of OCPUs: 2**, **Amount of memory (GB): 12** → Select shape.
     "Always Free-eligible" yozuvi turganini tekshiring.
5. **Networking:** o'zgartirmang. "Create new virtual cloud network" va **"Assign a public IPv4 address"** tanlangan bo'lishi kerak.
6. **Add SSH keys:** **Paste public keys** → 2-qadamda nusxalagan qatorni joylang.
7. **Boot volume:** standart (≈47–50 GB) yetarli.
8. **Create** tugmasini bosing. 1–2 daqiqada holati **RUNNING** bo'ladi.
9. Instance sahifasidagi **Public IP address** ni yozib oling (masalan `141.147.12.34`).

> **"Out of capacity for shape VM.Standard.A1.Flex"** xatosi chiqsa:
> - Shu sahifada **Placement** bo'limida boshqa **Availability Domain** (AD-2 yoki AD-3) tanlab qayta urinib ko'ring;
> - yoki OCPU/RAM'ni kamaytiring (masalan 1 OCPU / 6 GB — loyihaga yetadi);
> - yoki bir necha soatdan keyin qayta urinib ko'ring (ertalab yoki kechasi ko'pincha joy bo'ladi).

## 4-qadam. Oracle'da 80 va 443 portlarini ochish (~3 daqiqa)

⚠️ Bu qadamni o'tkazib yuborsangiz, sayt ochilmaydi.

1. Instance sahifasida **Primary VNIC** bo'limidagi **Subnet** havolasini bosing (masalan `subnet-2026...`).
2. **Security** yoki **Security Lists** yorlig'ida **Default Security List for vcn-...** ni oching.
3. **Security rules** → **Add Ingress Rules** ni bosing va uchta qoida qo'shing:

| Source CIDR | IP Protocol | Destination Port Range |
|---|---|---|
| `0.0.0.0/0` | TCP | `80` |
| `0.0.0.0/0` | TCP | `443` |
| `0.0.0.0/0` | UDP | `443` |

4. **Add Ingress Rules** tugmasi bilan saqlang. (22-port — SSH — allaqachon ochiq.)

## 5-qadam. DuckDNS'da bepul domen olish (~3 daqiqa)

1. **https://www.duckdns.org** ni oching va yuqoridagi **GitHub** yoki **Google** tugmasi orqali kiring.
2. **sub domain** maydoniga nom yozing (masalan `agroyordam`) → **add domain**.
   Nom band bo'lsa, boshqasini tanlang (`agroyordam-uz`, `agroyordam01`...).
3. Paydo bo'lgan qatordagi **current ip** maydoniga serverning **Public IP**'sini yozing → **update ip**.
4. Sizning manzilingiz: **`agroyordam.duckdns.org`**.

Tekshirish (kompyuterda):
```bash
ping agroyordam.duckdns.org
```
Server IP'si ko'rinsa — tayyor (javob kelmasa ham IP ko'rinsa yetarli).

## 6-qadam. Serverni sozlash — bitta buyruq (~20 daqiqa, asosan kutish)

Kompyuteringizdan serverga ulaning (IP'ni o'zingiznikiga almashtiring):
```bash
ssh -i ~/.ssh/agroyordam ubuntu@141.147.12.34
```
Birinchi ulanishda "Are you sure you want to continue connecting" so'raladi → `yes` deb yozing.

Serverda shu buyruqni bajaring (oxiridagi domenni o'zingiznikiga almashtiring):
```bash
curl -fsSL https://raw.githubusercontent.com/Aziimuslim/agroyordam/HEAD/deploy/setup-server.sh | sudo bash -s -- agroyordam.duckdns.org
```

Skript o'zi quyidagilarni bajaradi:
- tizimni yangilaydi;
- server ichidagi firewall'da 80/443 portlarini ochadi (Oracle Ubuntu'da ular standart holatda yopiq);
- Docker'ni o'rnatadi;
- loyihani `/opt/agroyordam` ga yuklab oladi;
- maxfiy kalitlarni avtomatik yaratib, `.env` faylini tayyorlaydi;
- butun tizimni yig'ib ishga tushiradi va HTTPS sertifikatini oladi.

Oxirida **`✅ Tayyor: https://agroyordam.duckdns.org`** yozuvi chiqishi kerak.

Admin hisobini yarating (parol so'raladi, kamida 10 belgi):
```bash
cd /opt/agroyordam
sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml exec backend \
  python -m app.create_admin --username admin --email sizning@email.uz
```

Tekshirish: telefon yoki kompyuter brauzerida **https://agroyordam.duckdns.org** ni oching → ro'yxatdan o'ting → AI tashxisni sinab ko'ring.

## 7-qadam. APK'ni shu serverga ulash (~10 daqiqa)

1. GitHub'da repo sahifasini oching: **https://github.com/Aziimuslim/agroyordam/settings/variables/actions**
   (Settings → Secrets and variables → Actions → **Variables** yorlig'i)
2. **New repository variable** tugmasini bosing:
   - **Name:** `API_URL`
   - **Value:** `https://agroyordam.duckdns.org`
   - → **Add variable**
3. APK'ni qayta yig'dirish: **https://github.com/Aziimuslim/agroyordam/actions/workflows/android-apk.yml**
   → **Run workflow** → **Run workflow**. Taxminan 8 daqiqa kutasiz.
4. Yangi APK havolasi o'zgarmaydi:
   **https://github.com/Aziimuslim/agroyordam/releases/latest/download/AgroYordam.apk**
   Telefonda eski ilovani o'chirib, yangisini o'rnating — u serverga o'zi ulanadi.

   Eski APK'ni o'chirmasangiz ham bo'ladi: birinchi ekrandagi **"Server: ..."** tugmasi orqali `https://agroyordam.duckdns.org` ni kiritsangiz yetarli.

## 8-qadam (ixtiyoriy). Avtomatik yangilanish

Kodga o'zgarish push qilinganda serverning o'zi yangilanishi uchun kompyuteringizda alohida deploy kaliti yaratasiz:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/agroyordam_deploy -N ""
cat ~/.ssh/agroyordam_deploy.pub
```
Chiqqan qatorni serverdagi `~/.ssh/authorized_keys` fayliga qo'shing:
```bash
ssh -i ~/.ssh/agroyordam ubuntu@SERVER_IP "echo '<shu qator>' >> ~/.ssh/authorized_keys"
```
Keyin **https://github.com/Aziimuslim/agroyordam/settings/secrets/actions** → **New repository secret** orqali uchta secret qo'shasiz:

| Name | Value |
|---|---|
| `SERVER_HOST` | server Public IP |
| `SERVER_USER` | `ubuntu` |
| `SERVER_SSH_KEY` | `cat ~/.ssh/agroyordam_deploy` natijasi (maxfiy kalit to'liq, `-----BEGIN` dan `-----END` gacha) |

Shundan keyin har push'da: testlar → smoke-test → serverda `git pull` va qayta yig'ish avtomatik bajariladi.

---

## Muammolar va yechimlar

| Belgi | Sabab / yechim |
|---|---|
| `ssh: Connection timed out` | IP noto'g'ri yoki instance hali RUNNING emas |
| `Permission denied (publickey)` | `-i ~/.ssh/agroyordam` yozilmagan yoki 3-qadamda boshqa kalit qo'yilgan |
| Sayt ochilmaydi, skript "⚠️" deydi | 4-qadam (Security List) bajarilmagan yoki DuckDNS'dagi IP noto'g'ri |
| Brauzer "sertifikat xato" deydi | DNS endi yangilangan bo'lsa, 5 daqiqa kutib `sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml restart caddy` |
| Loglarni ko'rish | `cd /opt/agroyordam && sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml logs --tail=100 backend caddy` |

**Oracle bepul serverlar haqida eslatma.** Uzoq vaqt deyarli ishlatilmagan "Always Free" instance'larni Oracle qaytarib olishi mumkin.
Ilovadan muntazam foydalanilsa, bu muammo bo'lmaydi. Zaxira nusxalar `/opt/agroyordam/backups` papkasida saqlanadi — vaqti-vaqti bilan kompyuteringizga ko'chirib qo'ying:
```bash
scp -i ~/.ssh/agroyordam -r ubuntu@SERVER_IP:/opt/agroyordam/backups ./agroyordam-backups
```
