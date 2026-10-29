#!/bin/bash
# Saves the database to backups/domjudge-<date>.sql.gz
# Restore: gunzip -c backups/<file> | sudo docker exec -i dj-mariadb mariadb -uroot -p<root password> domjudge
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

mkdir -p backups
file="backups/domjudge-$(date +%Y%m%d-%H%M%S).sql.gz"
sudo docker exec dj-mariadb mariadb-dump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction domjudge | gzip > "$file"
echo "Saved $file"
