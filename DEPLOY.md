# AgroYordam'ni internetga chiqarish (VPS + domen)

Natija: `https://sizning-domen.uz` da web ilova, APK esa shu serverga o'zi ulanadi.

Umumiy yo'l: **domen olish → VPS olish → domenni serverga ulash → serverda bir necha buyruq → (ixtiyoriy) avtomatik deploy**.

> 💡 **Bepul variant:** Oracle Cloud (Always Free) + DuckDNS bo'yicha rasmli qadam-baqadam yo'riqnoma —
> **[docs/ORACLE_FREE.md](docs/ORACLE_FREE.md)**

---

## 1. Domen olish

### Variant A — `.uz` domeni (tavsiya)
- `.uz` zonasini **Uzinfocom** boshqaradi. Domen to'g'ridan-to'g'ri ro'yxatdan o'tkazilmaydi, balki **akkreditatsiyalangan registrator** orqali olinadi.
- Registratorlar ro'yxati: **https://cctld.uz** saytida ("Registratorlar" bo'limi). Ulardan birini tanlang.
- Registrator saytida `agroyordam.uz` (yoki boshqa nom) bo'shligini tekshirasiz, ro'yxatdan o'tasiz va to'laysiz (odatda Uzcard/Humo, Click yoki Payme orqali).
- Shaxsingizni tasdiqlovchi ma'lumotlar (pasport yoki tashkilot rekvizitlari) so'ralishi mumkin.
- Narx yillik bo'ladi, aniq summani registrator saytidan ko'ring.

### Variant B — xalqaro domen (`.com`, `.app`, ...)
- Namecheap, Porkbun yoki Cloudflare Registrar kabi registratorlar. To'lov uchun xalqaro karta (Visa/Mastercard) kerak.

### Domenni serverga ulash (DNS)
VPS olganingizdan keyin (2-bo'lim), registrator panelidagi **DNS sozlamalari**ga ikkita yozuv qo'shasiz:

| Turi | Nomi (Host) | Qiymati | TTL |
|---|---|---|---|
| `A` | `@` | `SERVER_IP` | 3600 |
| `A` | `www` | `SERVER_IP` | 3600 |

DNS yangilanishi bir necha daqiqadan 24 soatgacha davom etadi. Tekshirish: `ping agroyordam.uz` server IP'sini ko'rsatishi kerak.

---

## 2. VPS (server) olish

### Minimal talablar
| | Minimal | Tavsiya |
|---|---|---|
| CPU | 2 vCPU | 2–4 vCPU |
| RAM | 2 GB (image'lar GitHub'da yig'ilsa) | **4 GB** (serverning o'zida yig'ish uchun) |
| Disk | 40 GB SSD | 60+ GB SSD |
| OS | Ubuntu 24.04 LTS | |
| Tarmoq | Ochiq (public) IPv4 manzil | |

### Qayerdan olish mumkin
- **O'zbekistondagi provayderlar (data-markaz O'zbekistonda).** "VPS" yoki "Cloud server" xizmatini qidiring. To'lov odatda Uzcard/Humo bilan qilinadi.
- **Xalqaro provayderlar:** Hetzner Cloud (Germaniya/Finlandiya), DigitalOcean (Frankfurt), Contabo va boshqalar. Xalqaro karta kerak; ba'zilari shaxsni tasdiqlashni so'raydi.

> ⚠️ **Muhim — shaxsiy ma'lumotlar qonuni.** O'zbekistonning "Shaxsga doir ma'lumotlar to'g'risida"gi qonuniga ko'ra, O'zbekiston fuqarolarining shaxsiy ma'lumotlari
> O'zbekiston hududidagi serverlarda saqlanishi talab qilinadi. Ilova ism, telefon va email saqlaydi. Shuning uchun haqiqiy
> foydalanuvchilar bilan ishlaganda **mahalliy data-markazdagi VPS** tanlash tavsiya etiladi. Aniq talablar bo'yicha yurist bilan maslahatlashing.
> Sinov (test) uchun xalqaro VPS ham yetarli.

### Buyurtma berayotganda
1. OS: **Ubuntu 24.04**.
2. Kirish usuli: **SSH kalit** (xavfsizroq). Kalitni o'z kompyuteringizda yaratasiz:
   ```bash
   ssh-keygen -t ed25519 -C "agroyordam"
   cat ~/.ssh/id_ed25519.pub     # shu matnni provayder paneliga qo'yasiz
   ```
   Windows'da PowerShell'da ham xuddi shu buyruqlar ishlaydi.
3. Server yaratilgach, uning **IP manzilini** yozib oling va 1-bo'limdagi DNS yozuvlarini qo'shing.

---

## 3. Serverni sozlash (bir marta, ~15 daqiqa)

**Tez yo'l — bitta buyruq** (Ubuntu, amd64 yoki arm64). Serverga SSH orqali kirib:
```bash
curl -fsSL https://raw.githubusercontent.com/Aziimuslim/if-else-son-kiritish/HEAD/deploy/setup-server.sh | sudo bash -s -- agroyordam.uz
```
Skript firewall, Docker, loyiha kodi (`/opt/agroyordam`), maxfiy kalitlar bilan `.env` va ishga tushirishni o'zi bajaradi.
Keyin faqat admin yaratasiz (pastda). Qo'lda qilishni istasangiz — quyidagi buyruqlar:

```bash
ssh root@SERVER_IP

# Tizimni yangilash va firewall (faqat SSH, HTTP, HTTPS ochiq)
apt update && apt upgrade -y
ufw allow OpenSSH && ufw allow 80 && ufw allow 443/tcp && ufw allow 443/udp && ufw --force enable

# Docker
curl -fsSL https://get.docker.com | sh

# RAM 2 GB bo'lsa — swap qo'shing
fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Loyiha
git clone https://github.com/Aziimuslim/if-else-son-kiritish.git /opt/agroyordam
cd /opt/agroyordam
cp .env.production.example .env
```

`.env` faylini to'ldiring (`nano .env`):
```bash
DOMAIN=agroyordam.uz                          # o'z domeningiz
SECRET_KEY=...        # openssl rand -hex 32 natijasi
POSTGRES_PASSWORD=... # openssl rand -hex 16
```
Tasodifiy qiymat olish: `openssl rand -hex 32`.

Ishga tushirish:
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
# birinchi yig'ish 10–20 daqiqa davom etadi

# Admin hisobini yaratish (parolni so'raydi)
docker compose -f docker-compose.yml -f docker-compose.prod.yml exec backend \
  python -m app.create_admin --username admin --email admin@agroyordam.uz
```

Tekshirish: brauzerda `https://agroyordam.uz` ochilishi kerak. SSL sertifikatni Caddy birinchi so'rovda avtomatik oladi.

Foydali buyruqlar:
```bash
alias dc='docker compose -f docker-compose.yml -f docker-compose.prod.yml'
dc ps                 # servislar holati
dc logs -f backend    # backend loglari
dc restart backend    # qayta ishga tushirish
ls backups/           # kunlik zaxira nusxalar (baza + rasmlar)
```

Zaxiradan tiklash:
```bash
gunzip -c backups/agroyordam-2026-09-23.sql.gz | dc exec -T db psql -U agro agroyordam
```

---

## 4. Avtomatik yangilanish (ixtiyoriy, tavsiya)

Asosiy (default) branch'ga push qilinganda GitHub Actions ("Docker stack" workflow) quyidagilarni bajaradi:
1. Butun stack'ni production rejimida ko'tarib, smoke-test qiladi.
2. Test o'tsa — serverga SSH orqali kirib, `/opt/agroyordam` da kodni yangilaydi va qayta yig'adi.

Sozlash: GitHub → repo → **Settings → Secrets and variables → Actions**:

| Nomi | Turi | Qiymati |
|---|---|---|
| `SERVER_HOST` | Secret | server IP manzili |
| `SERVER_USER` | Secret | `ubuntu` yoki `root` (serverga kiradigan foydalanuvchi) |
| `SERVER_SSH_KEY` | Secret | **alohida** deploy kalitining *maxfiy* qismi (`~/.ssh/agroyordam_deploy`) |
| `API_URL` | **Variable** | `https://agroyordam.uz` — APK shu serverga o'zi ulanadi |

Deploy kaliti:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/agroyordam_deploy -N ""
ssh-copy-id -i ~/.ssh/agroyordam_deploy.pub root@SERVER_IP
cat ~/.ssh/agroyordam_deploy       # → SERVER_SSH_KEY secret'iga
```

---

## 5. Haqiqiy to'lovlarni yoqish

Hozir `PAYMENT_MODE=sandbox`: ilova ichida test to'lov ishlaydi, pul yechilmaydi.
Haqiqiy to'lov uchun Payme va Click'ning **merchant (biznes) hisobi** kerak. Ular yuridik shaxs yoki YaTT sifatida ariza orqali ochiladi.

**Payme** (business.paycom.uz):
- Kassa yaratishda "Endpoint URL": `https://DOMAIN/api/v1/payments/payme`
- Hisob (account) maydoni: `order_id`
- `.env`: `PAYME_MERCHANT_ID`, `PAYME_SECRET_KEY` (kassa kaliti).
  Sinov uchun test kaliti va `PAYME_CHECKOUT_URL=https://test.paycom.uz` ni qo'ying.

**Click** (merchant.click.uz):
- Prepare URL: `https://DOMAIN/api/v1/payments/click/prepare`
- Complete URL: `https://DOMAIN/api/v1/payments/click/complete`
- `.env`: `CLICK_SERVICE_ID`, `CLICK_MERCHANT_ID`, `CLICK_SECRET_KEY`

Keyin `.env` da `PAYMENT_MODE=live` qiling va `dc up -d` ni ishga tushiring.

Ikkala protokol ham avtomatik testlar bilan tekshirilgan. Jonli ishga tushirishdan oldin provayderning test kabinetidagi tekshiruvidan (Payme'da "sandbox testlari") o'tkazing.

**Uzum Bank** integratsiyasi hozircha umumiy HMAC-webhook ko'rinishida. Uzum'ning rasmiy spetsifikatsiyasi olingach, unga moslashtiriladi.
