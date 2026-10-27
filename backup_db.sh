#!/bin/bash
# Dumps the DOMjudge database to backups/domjudge-<date>.sql.gz
# Run it regularly during the contest and copy the files off the server.
# Restore with:
#   gunzip -c backups/<file>.sql.gz | sudo docker exec -i dj-mariadb mariadb -uroot -p<root password> domjudge
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

mkdir -p backups
file="backups/domjudge-$(date +%Y%m%d-%H%M%S).sql.gz"
sudo docker exec "$MARIADB_CONTAINER" \
    mariadb-dump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction domjudge | gzip > "$file"
echo "Saved $file ($(du -h "$file" | cut -f1))"
