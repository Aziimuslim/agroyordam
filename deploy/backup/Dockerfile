# Zaxira nusxa servisi: pg_dump/psql (PostgreSQL 16) + rclone (S3 xotiraga yuborish)
FROM postgres:16-alpine
# rclone sozlamasi muhit o'zgaruvchilaridan olinadi; bo'sh fayl "config file not found" ogohlantirishini o'chiradi
RUN apk add --no-cache rclone ca-certificates \
 && mkdir -p /root/.config/rclone && touch /root/.config/rclone/rclone.conf
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh
ENTRYPOINT ["backup.sh"]
CMD ["loop"]
