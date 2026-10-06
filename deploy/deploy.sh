#!/usr/bin/env bash
# AgroYordam — serverda yangilash (GitHub Actions avtomatik deploy shu skriptni chaqiradi).
#
# Deploy SSH kaliti authorized_keys'da `command="sudo /opt/agroyordam/deploy/deploy.sh"` bilan cheklangan:
# kalit o'g'irlansa ham, u faqat shu skriptni ishga tushira oladi (shell, port-forward yo'q).
#
# Qadamlar: kod yangilanadi → image'lar yig'iladi → /health tekshiriladi →
# o'tmasa, oldingi versiyaga avtomatik qaytariladi (rollback).
#
# Qo'lda: sudo /opt/agroyordam/deploy/deploy.sh [branch | backup-status | backup-now | backup-list]
set -euo pipefail

# Skript o'zi `git reset` bilan yangilanadi — ishlayotgan faylni o'zgartirmaslik uchun nusxadan ishlaymiz
if [ -z "${AGRO_DEPLOY_COPY:-}" ]; then
  tmp="$(mktemp /tmp/agroyordam-deploy.XXXXXX.sh)"
  cp "$0" "$tmp"
  AGRO_DEPLOY_COPY=1 exec bash "$tmp" "$@"
fi
trap 'rm -f "$0"' EXIT

DIR="${AGRO_DIR:-/opt/agroyordam}"
REPO="${AGRO_REPO:-https://github.com/Aziimuslim/agroyordam.git}"
COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.prod.yml)

# SSH orqali so'ralgan buyruq. `sudo` muhitni tozalaydi (SSH_ORIGINAL_COMMAND yo'qoladi) — shuning uchun
# uni ota jarayonlardan (sshd ishga tushirgan shell) o'qiymiz. Qiymat pastda qat'iy tekshiriladi.
ssh_command() {
  if [ -n "${SSH_ORIGINAL_COMMAND:-}" ]; then printf '%s' "$SSH_ORIGINAL_COMMAND"; return 0; fi
  local pid=$PPID v
  for _ in 1 2 3 4 5 6; do
    [ "${pid:-0}" -gt 1 ] 2>/dev/null || return 0
    v="$( (tr '\0' '\n' < "/proc/$pid/environ" | sed -n 's/^SSH_ORIGINAL_COMMAND=//p' | head -n1) 2>/dev/null || true)"
    if [ -n "$v" ]; then printf '%s' "$v"; return 0; fi
    pid="$(sed 's/.*) //' "/proc/$pid/stat" 2>/dev/null | cut -d' ' -f2 || true)"
  done
}

# Branch: argument yoki SSH buyrug'idan ("deploy <branch>"), aks holda hozirgi branch
REQ="${1:-$(ssh_command)}"
cd "$DIR"
# Zaxira buyruqlari (GitHub Actions "Backup tekshiruvi" shu yerdan chaqiradi)
case "$REQ" in
  backup-status) "${COMPOSE[@]}" exec -T backup backup.sh check; exit ;;
  backup-now)    "${COMPOSE[@]}" exec -T backup backup.sh now; exit ;;
  backup-list)   "${COMPOSE[@]}" exec -T backup backup.sh list; exit ;;
esac
REQ="${REQ#deploy}"; REQ="${REQ# }"
BRANCH="${REQ:-$(git rev-parse --abbrev-ref HEAD)}"
if ! [[ "$BRANCH" =~ ^[A-Za-z0-9._/-]{1,100}$ ]] || [[ "$BRANCH" == *..* ]]; then
  echo "Noto'g'ri branch nomi: $BRANCH" >&2
  exit 2
fi

# Bir vaqtda ikkita deploy bo'lmasin
exec 9>/tmp/agroyordam-deploy.lock
flock -n 9 || { echo "Boshqa deploy hali tugamagan" >&2; exit 3; }

log() { echo "[$(date '+%F %T')] $*"; }

PREV="$(git rev-parse HEAD)"
git remote set-url origin "$REPO"
git fetch --quiet origin "$BRANCH"
git checkout --quiet --force -B "$BRANCH" "origin/$BRANCH"
NEW="$(git rev-parse HEAD)"
log "Deploy: ${PREV:0:7} → ${NEW:0:7} ($BRANCH)"

DOMAIN="$(grep -E '^DOMAIN=' .env | cut -d= -f2-)"
healthy() {
  # Server o'z domeniga tashqi IP orqali chiqa olmasligi mumkin — to'g'ridan-to'g'ri 127.0.0.1 ga
  for _ in $(seq 1 48); do
    if out="$(curl -sfk --max-time 5 --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/health")"; then
      log "Health: $out"
      return 0
    fi
    sleep 5
  done
  return 1
}

"${COMPOSE[@]}" up -d --build --remove-orphans
if healthy; then
  docker image prune -f >/dev/null || true
  log "✅ Tayyor: https://$DOMAIN (${NEW:0:7})"
  exit 0
fi

log "❌ Health tekshiruvi o'tmadi — ${PREV:0:7} ga qaytarilmoqda"
"${COMPOSE[@]}" logs --tail=60 backend caddy || true
git checkout --quiet --force --detach "$PREV"
"${COMPOSE[@]}" up -d --build --remove-orphans
healthy && log "Oldingi versiya tiklandi" || log "Oldingi versiya ham javob bermayapti — qo'lda tekshiring"
exit 1
