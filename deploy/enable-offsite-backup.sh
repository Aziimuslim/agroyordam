#!/usr/bin/env bash
# Server tashqarisidagi zaxira nusxani yoqish — serverda BIR MARTA:
#   cd /opt/agroyordam && sudo bash deploy/enable-offsite-backup.sh
#
# Oracle Object Storage (bepul 20 GB) uchun yo'riqnoma: docs/BACKUP.md
# Boshqa S3-mos xotira (Cloudflare R2, Backblaze B2, ...) ham ishlaydi — "Endpoint" so'ralganda to'liq URL bering.
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(id -u)" -eq 0 ] || { echo "sudo bilan ishga tushiring: sudo bash deploy/enable-offsite-backup.sh"; exit 1; }
[ -f .env ] || { echo ".env topilmadi — avval deploy/setup-server.sh"; exit 1; }
COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.prod.yml)

ask() { # ask VAR "savol" [default] [secret]
  local v def="${3:-}" cur; cur="$(grep -E "^$1=" .env | tail -1 | cut -d= -f2- || true)"
  [ -n "$cur" ] && def="$cur"
  local shown="$def"; [ -n "${4:-}" ] && [ -n "$def" ] && shown="(saqlangan)"
  if [ -n "${4:-}" ]; then read -rsp "$2${shown:+ [$shown]}: " v; echo; else read -rp "$2${shown:+ [$shown]}: " v; fi
  v="${v:-$def}"; v="$(printf '%s' "$v" | tr -d '[:space:]')"
  [ -n "$v" ] || { echo "Bo'sh bo'lmasligi kerak"; exit 1; }
  printf -v "$1" '%s' "$v"
}

echo "=== Server tashqarisidagi zaxira (S3) ==="
echo "Oracle uchun: Namespace va region Bucket sahifasida ko'rinadi (docs/BACKUP.md)."
ask NS "Namespace (Oracle) yoki to'liq Endpoint URL (boshqa xizmat)"
if [[ "$NS" == http* ]]; then
  ENDPOINT="$NS"; ask REGION "Region" "auto"
else
  ask REGION "Region" "eu-frankfurt-1"
  ENDPOINT="https://$NS.compat.objectstorage.$REGION.oraclecloud.com"
fi
ask BUCKET "Bucket nomi" "agroyordam-backups"
ask AK "Access key"
ask SK "Secret key" "" secret
ask DAYS "Bazani necha kun saqlash" "30"

set_env() { # .env dagi qiymatni almashtiradi yoki qo'shadi
  if grep -qE "^$1=" .env; then
    local tmp; tmp="$(mktemp)"; awk -v k="$1" -v v="$2" -F= '$1==k{print k"="v; next}{print}' .env > "$tmp"
    cat "$tmp" > .env; rm -f "$tmp"
  else echo "$1=$2" >> .env; fi
}
grep -q "OFFSITE_S3_" .env || printf '\n# Server tashqarisidagi zaxira nusxa (deploy/enable-offsite-backup.sh)\n' >> .env
set_env OFFSITE_S3_ENDPOINT "$ENDPOINT"
set_env OFFSITE_S3_REGION "$REGION"
set_env OFFSITE_S3_BUCKET "$BUCKET"
set_env OFFSITE_S3_ACCESS_KEY "$AK"
set_env OFFSITE_S3_SECRET_KEY "$SK"
set_env BACKUP_KEEP_DAYS "$DAYS"
chmod 600 .env

echo; echo "Zaxira servisi qayta ishga tushirilmoqda..."
"${COMPOSE[@]}" up -d --build backup
echo "Sinov zaxirasi olinmoqda (1–3 daqiqa)..."
if "${COMPOSE[@]}" exec -T backup backup.sh now; then
  echo; "${COMPOSE[@]}" exec -T backup backup.sh list
  echo; echo "✅ Tayyor. Har kuni 03:00 (Toshkent) da baza va rasmlar $BUCKET ga yuboriladi."
else
  echo; echo "❌ Yuborib bo'lmadi. Tekshiring: Namespace/region, bucket nomi, Access/Secret key."
  echo "   Qayta urinish: sudo bash deploy/enable-offsite-backup.sh"
  exit 1
fi
