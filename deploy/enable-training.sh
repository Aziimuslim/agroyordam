#!/usr/bin/env bash
# AI'ni admin paneldan qayta o'qitishni yoqish — serverda BIR MARTA:
#   cd /opt/agroyordam && sudo bash deploy/enable-training.sh
#
# Kerak: GitHub "fine-grained" token (faqat shu repo, Actions — Read and write). Yo'riqnoma: docs/DATASET.md
# Token faqat serverdagi .env da saqlanadi (chmod 600); ekranga chiqmaydi.
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(id -u)" -eq 0 ] || { echo "sudo bilan ishga tushiring: sudo bash deploy/enable-training.sh"; exit 1; }
[ -f .env ] || { echo ".env topilmadi — avval deploy/setup-server.sh"; exit 1; }
COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.prod.yml)
REPO="$(grep -E '^GITHUB_REPO=' .env | tail -1 | cut -d= -f2- || true)"; REPO="${REPO:-Aziimuslim/agroyordam}"

echo "=== AI qayta o'qitish (GitHub Actions) — $REPO ==="
read -rsp "GitHub token (github_pat_...): " TOKEN; echo
TOKEN="$(printf '%s' "$TOKEN" | tr -d '[:space:]')"
[ -n "$TOKEN" ] || { echo "Bo'sh bo'lmasligi kerak"; exit 1; }

# Token shu repo'ning Actions'iga kira oladimi (hech narsa ishga tushirmaydi)
code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/actions/workflows/train-model.yml")
if [ "$code" != "200" ]; then
  echo "❌ Token ishlamadi (GitHub javobi: $code). Tekshiring: repo tanlanganmi, Actions — Read and write, muddati o'tmaganmi."
  exit 1
fi

set_env() { # .env dagi qiymatni almashtiradi yoki qo'shadi
  if grep -qE "^$1=" .env; then
    local tmp; tmp="$(mktemp)"; awk -v k="$1" -v v="$2" -F= '$1==k{print k"="v; next}{print}' .env > "$tmp"
    cat "$tmp" > .env; rm -f "$tmp"
  else echo "$1=$2" >> .env; fi
}
grep -q "GITHUB_TRAIN_TOKEN" .env || printf '\n# AI qayta o'"'"'qitish (deploy/enable-training.sh)\n' >> .env
set_env GITHUB_TRAIN_TOKEN "$TOKEN"
chmod 600 .env

echo "Backend qayta ishga tushirilmoqda..."
"${COMPOSE[@]}" up -d backend
echo "✅ Tayyor. Admin panel → AI va dataset → «Qayta o'qitishni boshlash»."
