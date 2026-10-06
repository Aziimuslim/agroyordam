#!/bin/sh
# AgroYordam zaxira nusxalari: PostgreSQL bazasi + yuklangan rasmlar.
#
#   backup.sh loop             — servis rejimi: har kuni BACKUP_HOUR_UTC da (default 22 = Toshkent 03:00)
#   backup.sh now              — hozir zaxira olish
#   backup.sh check            — oxirgi zaxira holati (26 soatdan eski yoki xato bo'lsa — exit 1)
#   backup.sh list             — mavjud nusxalar (serverda va tashqi xotirada)
#   backup.sh restore <nusxa>  — tiklash (deploy/restore.sh orqali chaqiriladi; nusxa = 2026-10-06_2200 | latest)
#
# Nusxalar /backups ga yoziladi (BACKUP_KEEP_LOCAL_DAYS kun). OFFSITE_S3_* berilgan bo'lsa, server tashqarisidagi
# S3-mos xotiraga (Oracle Object Storage, Cloudflare R2, Backblaze B2, ...) ham yuboriladi:
#   db/agroyordam-<sana>.sql.gz  — BACKUP_KEEP_DAYS kun saqlanadi
#   media/                       — rasmlar; faqat yangilari yuboriladi, hech narsa o'chirilmaydi
set -eu
set -o pipefail

B=/backups
KEEP_LOCAL="${BACKUP_KEEP_LOCAL_DAYS:-7}"
KEEP_REMOTE="${BACKUP_KEEP_DAYS:-30}"
HOUR="${BACKUP_HOUR_UTC:-22}"
MAX_AGE_H="${BACKUP_MAX_AGE_HOURS:-26}"
DB="${POSTGRES_DB:-agroyordam}"
DBUSER="${POSTGRES_USER:-agro}"
DBHOST="${POSTGRES_HOST:-db}"

log() { echo "[$(date -u '+%F %T') UTC] $*"; }
now_s() { date -u +%s; }
read_num() { [ -f "$1" ] && cat "$1" || echo 0; }

offsite_enabled() { [ -n "${OFFSITE_S3_BUCKET:-}" ] && [ -n "${OFFSITE_S3_ACCESS_KEY:-}" ]; }
if offsite_enabled; then
  # rclone sozlamasi faqat muhit o'zgaruvchilaridan — kalitlar diskka yozilmaydi
  export RCLONE_CONFIG_OFFSITE_TYPE=s3
  export RCLONE_CONFIG_OFFSITE_PROVIDER="${OFFSITE_S3_PROVIDER:-Other}"
  export RCLONE_CONFIG_OFFSITE_ENDPOINT="${OFFSITE_S3_ENDPOINT:?OFFSITE_S3_ENDPOINT kerak}"
  export RCLONE_CONFIG_OFFSITE_REGION="${OFFSITE_S3_REGION:-us-east-1}"
  export RCLONE_CONFIG_OFFSITE_ACCESS_KEY_ID="$OFFSITE_S3_ACCESS_KEY"
  export RCLONE_CONFIG_OFFSITE_SECRET_ACCESS_KEY="${OFFSITE_S3_SECRET_KEY:?OFFSITE_S3_SECRET_KEY kerak}"
  export RCLONE_CONFIG_OFFSITE_FORCE_PATH_STYLE=true
  export RCLONE_CONFIG_OFFSITE_NO_CHECK_BUCKET=true
  REMOTE="offsite:${OFFSITE_S3_BUCKET}/${OFFSITE_S3_PREFIX:-agroyordam}"
fi
RCLONE="rclone --retries 5 --low-level-retries 10 --stats-log-level NOTICE"

# --- Zaxira olish -------------------------------------------------------------------------------------------
backup_now() {
  mkdir -p "$B"
  # Bir vaqtda ikkita zaxira bo'lmasin
  if ! mkdir "$B/.lock" 2>/dev/null; then
    if [ $(( $(now_s) - $(stat -c %Y "$B/.lock") )) -lt 7200 ]; then log "Boshqa zaxira hali tugamagan"; return 1; fi
    rmdir "$B/.lock"; mkdir "$B/.lock"
  fi
  now_s > "$B/.last_try"
  stamp="$(date -u +%Y-%m-%d_%H%M)"
  file="$B/agroyordam-$stamp.sql.gz"
  # set -e '||' ichida o'chib qoladi — shuning uchun xatoni alohida ushlaymiz
  set +e
  (
    set -e
    log "Baza: $file"
    pg_dump -h "$DBHOST" -U "$DBUSER" "$DB" | gzip > "$file.tmp"
    gzip -t "$file.tmp" && mv "$file.tmp" "$file"
    log "Rasmlar: $B/media-$stamp.tar.gz"
    tar czf "$B/media-$stamp.tar.gz" -C /media .
    find "$B" -maxdepth 1 -name '*.gz' -mtime +"$KEEP_LOCAL" -delete
    if offsite_enabled; then
      log "Tashqi xotiraga: $REMOTE"
      $RCLONE copyto "$file" "$REMOTE/db/$(basename "$file")"
      $RCLONE copy /media "$REMOTE/media"
      $RCLONE delete --min-age "${KEEP_REMOTE}d" "$REMOTE/db"
    fi
  )
  rc=$?
  set -e
  rm -f "$file.tmp"
  rmdir "$B/.lock" 2>/dev/null || true

  size="$(du -h "$file" 2>/dev/null | cut -f1)"
  where="serverda"; offsite_enabled && where="serverda + tashqi xotirada ($REMOTE)"
  if [ "$rc" -eq 0 ]; then
    now_s > "$B/.last_ok"
    echo "ok $stamp — baza $size, $where" > "$B/status"
    log "✅ Zaxira tayyor: $stamp ($where)"
  else
    echo "xato $stamp — zaxira olinmadi (kod $rc); loglar: docker compose logs backup" > "$B/status"
    log "❌ Zaxira xatosi (kod $rc)"
  fi
  return "$rc"
}

# --- Holat ---------------------------------------------------------------------------------------------------
check() {
  [ -f "$B/status" ] || { echo "Hali zaxira olinmagan"; return 1; }
  age=$(( ($(now_s) - $(read_num "$B/.last_ok")) / 3600 ))
  echo "Oxirgi natija: $(cat "$B/status")"
  echo "Oxirgi muvaffaqiyatli zaxira: $age soat oldin"
  offsite_enabled && echo "Tashqi xotira: yoqilgan" || echo "Tashqi xotira: YOQILMAGAN (deploy/enable-offsite-backup.sh)"
  grep -q '^ok' "$B/status" && [ "$age" -lt "$MAX_AGE_H" ]
}

list() {
  echo "Serverda (/backups):"
  ls -1 "$B" 2>/dev/null | sed -n 's/^agroyordam-\(.*\)\.sql\.gz$/  \1/p' | sort
  if offsite_enabled; then
    echo "Tashqi xotirada ($REMOTE/db):"
    $RCLONE lsf "$REMOTE/db" | sed -n 's/^agroyordam-\(.*\)\.sql\.gz$/  \1/p' | sort
  fi
}

# --- Tiklash -------------------------------------------------------------------------------------------------
restore() {
  want="${1:?nusxa nomi kerak: latest yoki 2026-10-06_2200}"
  [ -d /media-rw ] || { echo "/media-rw ulanmagan — deploy/restore.sh orqali ishga tushiring"; return 2; }
  if [ "$want" = latest ]; then
    want="$(list | sed -n 's/^  //p' | sort | tail -1)"
    [ -n "$want" ] || { echo "Hech qanday nusxa topilmadi"; return 1; }
  fi
  case "$want" in *[!0-9_-]*) echo "Noto'g'ri nusxa nomi: $want"; return 2 ;; esac
  file="$B/agroyordam-$want.sql.gz"
  if [ ! -f "$file" ]; then
    offsite_enabled || { echo "$file topilmadi"; return 1; }
    log "Tashqi xotiradan yuklanmoqda: db/agroyordam-$want.sql.gz"
    $RCLONE copyto "$REMOTE/db/agroyordam-$want.sql.gz" "$file"
  fi
  gzip -t "$file"

  log "Baza tiklanmoqda: $want"
  psql -q -v ON_ERROR_STOP=1 -h "$DBHOST" -U "$DBUSER" "$DB" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
  gunzip -c "$file" | psql -q -v ON_ERROR_STOP=1 -h "$DBHOST" -U "$DBUSER" "$DB" > /dev/null

  log "Rasmlar tiklanmoqda"
  if offsite_enabled; then
    $RCLONE copy "$REMOTE/media" /media-rw
  elif [ -f "$B/media-$want.tar.gz" ]; then
    tar xzf "$B/media-$want.tar.gz" -C /media-rw
  else
    log "⚠️ Rasmlar nusxasi topilmadi — faqat baza tiklandi"
  fi
  log "✅ Tiklandi: $want"
}

# --- Servis rejimi -------------------------------------------------------------------------------------------
loop() {
  log "Zaxira servisi: har kuni ${HOUR}:00 UTC; tashqi xotira: $(offsite_enabled && echo "$REMOTE" || echo yo\'q)"
  while true; do
    now="$(now_s)"
    since_ok=$(( now - $(read_num "$B/.last_ok") ))
    since_try=$(( now - $(read_num "$B/.last_try") ))
    # Belgilangan soatda (kuniga bir marta) yoki nusxa 26 soatdan eskirgan bo'lsa; xatodan keyin 1 soatda qayta urinish
    if [ "$since_try" -ge 3600 ] && { [ "$since_ok" -ge $((MAX_AGE_H * 3600)) ] || \
         { [ "$(date -u +%H)" -eq "$HOUR" ] && [ "$since_ok" -ge 72000 ]; }; }; then
      backup.sh now || true   # alohida jarayon: ichida set -e to'liq ishlaydi
    fi
    sleep 300
  done
}

cmd="${1:-loop}"; [ $# -gt 0 ] && shift
case "$cmd" in
  loop) loop ;;
  now) backup_now ;;
  check) check ;;
  list) list ;;
  restore) restore "$@" ;;
  *) echo "Foydalanish: backup.sh loop|now|check|list|restore <nusxa>"; exit 2 ;;
esac
