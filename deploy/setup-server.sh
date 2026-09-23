#!/usr/bin/env bash
# AgroYordam — serverni bir buyruqda sozlash (Ubuntu 22.04/24.04, amd64 yoki arm64/Oracle Ampere).
#
#   curl -fsSL https://raw.githubusercontent.com/Aziimuslim/if-else-son-kiritish/HEAD/deploy/setup-server.sh | sudo bash -s -- agroyordam.duckdns.org
#
# Qayta ishga tushirish xavfsiz: mavjud .env va ma'lumotlar saqlanadi, faqat kod yangilanadi.
set -euo pipefail

DOMAIN="${1:-}"
REPO="${REPO:-https://github.com/Aziimuslim/if-else-son-kiritish.git}"
DIR="${DIR:-/opt/agroyordam}"
OWNER="${SUDO_USER:-root}"

[ "$(id -u)" -eq 0 ] || { echo "sudo bilan ishga tushiring"; exit 1; }
[ -n "$DOMAIN" ] || { echo "Foydalanish: sudo bash setup-server.sh DOMEN (masalan agroyordam.duckdns.org)"; exit 1; }

echo "==> 1/6 Tizim paketlari"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get upgrade -y
apt-get install -y git curl openssl ca-certificates

echo "==> 2/6 Firewall: 22, 80, 443"
if [ -f /etc/iptables/rules.v4 ]; then
  # Oracle Cloud Ubuntu image'larida iptables standart holatda 80/443 ni bloklaydi
  for rule in "-p tcp --dport 80" "-p tcp --dport 443" "-p udp --dport 443"; do
    iptables -C INPUT -m state --state NEW $rule -j ACCEPT 2>/dev/null || iptables -I INPUT 5 -m state --state NEW $rule -j ACCEPT
  done
  netfilter-persistent save >/dev/null 2>&1 || iptables-save > /etc/iptables/rules.v4
elif command -v ufw >/dev/null; then
  ufw allow OpenSSH && ufw allow 80/tcp && ufw allow 443/tcp && ufw allow 443/udp && ufw --force enable
fi

echo "==> 3/6 Docker"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker
[ "$OWNER" != root ] && usermod -aG docker "$OWNER" || true

MEM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if [ "$MEM_MB" -lt 3500 ] && ! swapon --show | grep -q swapfile; then
  echo "==> RAM ${MEM_MB}MB — 4GB swap qo'shilmoqda"
  fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> 4/6 Loyiha kodi → $DIR"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only
else
  git clone "$REPO" "$DIR"
fi
chown -R "$OWNER":"$OWNER" "$DIR"
cd "$DIR"

echo "==> 5/6 .env"
if [ ! -f .env ]; then
  cp .env.production.example .env
  sed -i "s|^DOMAIN=.*|DOMAIN=$DOMAIN|" .env
  sed -i "s|^SECRET_KEY=.*|SECRET_KEY=$(openssl rand -hex 32)|" .env
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(openssl rand -hex 16)|" .env
  sed -i "s|^IMAGE_REGISTRY=.*|IMAGE_REGISTRY=agroyordam|" .env
  chown "$OWNER":"$OWNER" .env && chmod 600 .env
  echo "    yangi .env yaratildi (maxfiy kalitlar avtomatik)"
else
  sed -i "s|^DOMAIN=.*|DOMAIN=$DOMAIN|" .env
  echo "    mavjud .env saqlandi"
fi

echo "==> 6/6 Yig'ish va ishga tushirish (birinchi marta 10–20 daqiqa)"
COMPOSE="docker compose -f docker-compose.yml -f docker-compose.prod.yml"
$COMPOSE up -d --build

echo "    backend tayyor bo'lishini kutish..."
for i in $(seq 1 60); do
  $COMPOSE exec -T backend python -c "import urllib.request as u; u.urlopen('http://localhost:8000/health')" >/dev/null 2>&1 && break
  sleep 5
done
echo "    HTTPS sertifikatini kutish..."
for i in $(seq 1 24); do
  curl -sf "https://$DOMAIN/health" -o /dev/null && break
  sleep 5
done
echo
if curl -sf "https://$DOMAIN/health" >/dev/null 2>&1; then
  echo "✅ Tayyor: https://$DOMAIN"
else
  echo "⚠️  Servislar ishga tushdi, lekin https://$DOMAIN hali javob bermayapti."
  echo "    Tekshiring: DNS (domen → server IP), Oracle Security List'da 80/443 ochiqmi."
  echo "    Loglar: cd $DIR && $COMPOSE logs --tail=50 caddy backend"
fi
echo
echo "Admin yaratish:"
echo "  cd $DIR && sudo $COMPOSE exec backend python -m app.create_admin --username admin --email admin@example.com"
