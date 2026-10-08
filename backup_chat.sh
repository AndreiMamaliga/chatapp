#!/bin/bash
cd /home/admin/chatapp
docker compose exec -T mysql sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --no-tablespaces chatdb' 2>/dev/null | gzip > /home/admin/backups/chat-$(date +%F).sql.gz
find /home/admin/backups -name 'chat-*.sql.gz' -mtime +14 -delete
