#!/bin/bash
# Starts MariaDB, the DOMjudge server and $JUDGEHOSTS judgehosts.
# Safe to run again: existing containers are restarted, never recreated.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

exists() { sudo docker container inspect "$1" > /dev/null 2>&1; }
wait_for() {  # wait_for <container> <command...>: retry for up to 10 minutes
    local container=$1; shift
    for _ in $(seq 200); do
        sudo docker exec "$container" "$@" > /dev/null 2>&1 && return
        sleep 3
    done
    echo "$container did not become ready. Check: sudo docker logs $container" >&2
    exit 1
}

if [ "$(stat -fc %T /sys/fs/cgroup)" != "cgroup2fs" ]; then
    echo "This machine is not using cgroup v2. See 'Coming from the old version' in README.md." >&2
    exit 1
fi
if [ "$JUDGEHOSTS" -ge "$(nproc)" ]; then
    echo "JUDGEHOSTS must be less than the number of CPU cores ($(nproc))." >&2
    exit 1
fi
if exists domserver && [ "$(sudo docker inspect -f '{{.Config.Image}}' domserver)" != "domjudge/domserver:$DOMJUDGE_VERSION" ]; then
    echo "An old domserver container exists. See 'Coming from the old version' in README.md." >&2
    exit 1
fi

sudo docker network inspect domjudge > /dev/null 2>&1 || sudo docker network create domjudge

if exists dj-mariadb; then
    sudo docker start dj-mariadb
else
    # --innodb_snapshot_isolation=OFF is required by DOMjudge on MariaDB >= 11.6.
    sudo docker run -d --name dj-mariadb --net domjudge --restart unless-stopped \
        -v dj-mariadb-data:/var/lib/mysql \
        -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
        -e MYSQL_USER=domjudge -e MYSQL_DATABASE=domjudge \
        "mariadb:$MARIADB_VERSION" \
        --max-connections=1000 --max-allowed-packet=512M --innodb_snapshot_isolation=OFF
fi
wait_for dj-mariadb healthcheck.sh --connect --innodb_initialized

if exists domserver; then
    sudo docker start domserver
else
    sudo docker run -d --name domserver --net domjudge --restart unless-stopped \
        -e MYSQL_HOST=dj-mariadb -e MYSQL_USER=domjudge -e MYSQL_DATABASE=domjudge \
        -e MYSQL_PASSWORD="$MYSQL_PASSWORD" -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
        -e CONTAINER_TIMEZONE="$TIMEZONE" -p "$PORT:80" \
        "domjudge/domserver:$DOMJUDGE_VERSION"
fi
echo "Waiting for the server (the first start takes a few minutes)..."
wait_for domserver curl -sf -o /dev/null http://localhost/

etc=/opt/domjudge/domserver/etc
judgehost_password=${JUDGEHOST_PASSWORD:-$(sudo docker exec domserver awk '!/^#/ {print $4; exit}' "$etc/restapi.secret")}
if [ -z "${JUDGEHOST_PASSWORD:-}" ] && sudo docker exec domserver grep -q "NOTE(password-mismatch)" "$etc/restapi.secret"; then
    # Happens when the domserver container was recreated on an existing database.
    echo "Judgehost password unknown. Set one for user 'judgehost' under Jury > Users, then run:" >&2
    echo "  sudo docker rm -f \$(sudo docker ps -aq --filter name=judgehost-); JUDGEHOST_PASSWORD=<password> ./start.sh" >&2
    judgehost_password=
fi

for id in $(seq 1 "$JUDGEHOSTS"); do
    if exists "judgehost-$id"; then
        sudo docker start "judgehost-$id" > /dev/null
    elif [ -n "$judgehost_password" ]; then
        sudo docker run -d --name "judgehost-$id" --hostname "judgehost-$id" --net domjudge \
            --restart unless-stopped --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup \
            -e DAEMON_ID="$id" -e DOMSERVER_BASEURL=http://domserver/ \
            -e JUDGEDAEMON_PASSWORD="$judgehost_password" -e CONTAINER_TIMEZONE="$TIMEZONE" \
            "domjudge/judgehost:$DOMJUDGE_VERSION" > /dev/null
    fi
done

echo
echo "DOMjudge: http://localhost:$PORT/   (judgehosts: $JUDGEHOSTS)"
echo "Admin password: $(sudo docker exec domserver cat "$etc/initial_admin_password.secret")"
