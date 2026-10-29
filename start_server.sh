#!/bin/bash
# Starts MariaDB and the DOMjudge server (domserver).
# Safe to run again: existing containers are restarted, not recreated, so
# contest data and the generated passwords are kept.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

container_exists() {
    sudo docker container inspect "$1" > /dev/null 2>&1
}

sudo docker network inspect "$DOCKER_NETWORK" > /dev/null 2>&1 \
    || sudo docker network create "$DOCKER_NETWORK"

if container_exists "$MARIADB_CONTAINER"; then
    sudo docker start "$MARIADB_CONTAINER"
else
    # Data lives in a named volume, so it survives removing the container.
    # --innodb_snapshot_isolation=OFF is required by DOMjudge on MariaDB >= 11.6.
    sudo docker run -d --name "$MARIADB_CONTAINER" --net "$DOCKER_NETWORK" \
        --restart unless-stopped \
        -v "$MARIADB_VOLUME:/var/lib/mysql" \
        -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
        -e MYSQL_USER=domjudge -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
        -e MYSQL_DATABASE=domjudge \
        -e TZ="$TIMEZONE" \
        "mariadb:$MARIADB_VERSION" \
        --max-connections=1000 --max-allowed-packet=512M --innodb_snapshot_isolation=OFF
fi

echo -n "Waiting for MariaDB to be ready"
for _ in $(seq 60); do
    if sudo docker exec "$MARIADB_CONTAINER" healthcheck.sh --connect --innodb_initialized > /dev/null 2>&1; then
        break
    fi
    echo -n "."
    sleep 2
done
echo

if container_exists "$DOMSERVER_CONTAINER"; then
    sudo docker start "$DOMSERVER_CONTAINER"
else
    sudo docker run -d --name "$DOMSERVER_CONTAINER" --net "$DOCKER_NETWORK" \
        --restart unless-stopped \
        -e MYSQL_HOST="$MARIADB_CONTAINER" \
        -e MYSQL_USER=domjudge -e MYSQL_DATABASE=domjudge \
        -e MYSQL_PASSWORD="$MYSQL_PASSWORD" -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
        -e CONTAINER_TIMEZONE="$TIMEZONE" \
        -p "$DOMSERVER_PORT:80" \
        "domjudge/domserver:$DOMJUDGE_VERSION"
fi

echo -n "Waiting for the domserver to finish setting up"
for _ in $(seq 120); do
    if sudo docker exec "$DOMSERVER_CONTAINER" curl -sf -o /dev/null http://localhost/; then
        break
    fi
    echo -n "."
    sleep 2
done
echo
echo

etc=/opt/domjudge/domserver/etc
echo "DOMjudge is running at http://localhost:$DOMSERVER_PORT/"
echo "Admin login:        admin / $(sudo docker exec "$DOMSERVER_CONTAINER" cat "$etc/initial_admin_password.secret" 2> /dev/null || echo '[see docker logs domserver]')"
if sudo docker exec "$DOMSERVER_CONTAINER" grep -q "NOTE(password-mismatch)" "$etc/restapi.secret"; then
    # The domserver container was recreated on an existing database.
    echo "Judgehost password: [unknown]"
    echo "Set a new password for the 'judgehost' user under Jury > Users, then put it in"
    echo "JUDGEDAEMON_PASSWORD in config.sh (on this machine too)."
else
    echo "Judgehost password: $(sudo docker exec "$DOMSERVER_CONTAINER" awk '!/^#/ {print $4; exit}' "$etc/restapi.secret" 2> /dev/null || echo '[see docker logs domserver]')"
    echo "(Put the judgehost password in JUDGEDAEMON_PASSWORD in config.sh on separate judge machines.)"
fi
