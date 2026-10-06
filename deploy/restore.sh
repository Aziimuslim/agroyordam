#!/usr/bin/env bash
# Zaxira nusxadan tiklash (serverda):
#   sudo bash deploy/restore.sh                 — mavjud nusxalar ro'yxati
#   sudo bash deploy/restore.sh latest          — eng oxirgisini tiklash
#   sudo bash deploy/restore.sh 2026-10-06_2200 — aniq nusxani tiklash
#
# Yangi serverda: setup-server.sh → .env ga OFFSITE_S3_* ni qo'ying (enable-offsite-backup.sh) → shu skript.
# ⚠️ Hozirgi baza o'chiriladi va nusxadagi holatga almashtiriladi. Rasmlar ustiga qo'shiladi.
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(id -u)" -eq 0 ] || { echo "sudo bilan ishga tushiring"; exit 1; }
COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.prod.yml)

"${COMPOSE[@]}" up -d db
if [ $# -eq 0 ]; then
  "${COMPOSE[@]}" run --rm --no-deps backup list
  echo; echo "Tiklash: sudo bash deploy/restore.sh <nusxa>  (yoki latest)"
  exit 0
fi

WANT="$1"
if [ "${2:-}" != "--yes" ]; then
  read -rp "Hozirgi baza '$WANT' nusxasi bilan ALMASHTIRILADI. Davom etish uchun HA deb yozing: " ok
  [ "$ok" = "HA" ] || { echo "Bekor qilindi"; exit 1; }
fi

MEDIA_VOL="$(docker volume ls -q --filter label=com.docker.compose.volume=media \
  --filter "label=com.docker.compose.project=$("${COMPOSE[@]}" config --format json | python3 -c 'import json,sys;print(json.load(sys.stdin)["name"])')")"
[ -n "$MEDIA_VOL" ] || { "${COMPOSE[@]}" up -d --no-start backend; MEDIA_VOL="$(docker volume ls -q --filter label=com.docker.compose.volume=media | head -1)"; }

echo "Backend to'xtatilmoqda (tiklash vaqtida yozuv bo'lmasin)..."
"${COMPOSE[@]}" stop backend backup || true
rc=0
"${COMPOSE[@]}" run --rm --no-deps -v "$MEDIA_VOL:/media-rw" backup restore "$WANT" || rc=$?
"${COMPOSE[@]}" up -d backend backup
[ "$rc" -eq 0 ] && echo "✅ Tiklandi. Sayt 1–2 daqiqada ishlaydi." || { echo "❌ Tiklash xatosi (kod $rc)"; exit "$rc"; }
