# Zaxira nusxa servisi: pg_dump/psql (PostgreSQL 16) + rclone (S3 xotiraga yuborish)
FROM postgres:16-alpine
RUN apk add --no-cache rclone ca-certificates
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh
ENTRYPOINT ["backup.sh"]
CMD ["loop"]
