#!/bin/bash
# Starts one judgehost (worker). Usage: ./start_worker.sh <ID>
# Each judgehost on a machine needs its own ID and is pinned to CPU core <ID>,
# so IDs must be between 0 and (number of CPU cores - 1).
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

WORKER_ID=${1:-}
cores=$(nproc)
if ! [[ "$WORKER_ID" =~ ^[0-9]+$ ]] || [ "$WORKER_ID" -ge "$cores" ]; then
    echo "Usage: $0 <ID>   (ID must be between 0 and $((cores - 1)) on this machine)" >&2
    exit 1
fi

name="judgehost-$WORKER_ID"
if sudo docker container inspect "$name" > /dev/null 2>&1; then
    sudo docker start "$name"
    echo "Restarted existing $name. Follow its log with: sudo docker logs -f $name"
    exit 0
fi

if [ -z "$DOMSERVER_URL" ]; then
    # Same machine as the domserver: use the internal Docker network.
    if ! sudo docker container inspect "$DOMSERVER_CONTAINER" > /dev/null 2>&1; then
        echo "No local '$DOMSERVER_CONTAINER' container found." >&2
        echo "On a separate judge machine, set DOMSERVER_URL in config.sh." >&2
        exit 1
    fi
    network_args=(--net "$DOCKER_NETWORK")
    server_url="http://$DOMSERVER_CONTAINER/"
    secret=/opt/domjudge/domserver/etc/restapi.secret
    if [ -z "$JUDGEDAEMON_PASSWORD" ] \
        && ! sudo docker exec "$DOMSERVER_CONTAINER" grep -q "NOTE(password-mismatch)" "$secret"; then
        JUDGEDAEMON_PASSWORD=$(sudo docker exec "$DOMSERVER_CONTAINER" awk '!/^#/ {print $4; exit}' "$secret")
    fi
else
    network_args=()
    server_url="$DOMSERVER_URL"
fi

if [ -z "$JUDGEDAEMON_PASSWORD" ]; then
    echo "Set JUDGEDAEMON_PASSWORD in config.sh (printed by start_server.sh on the server)." >&2
    exit 1
fi

sudo docker run -d --name "$name" --hostname "judgedaemon-$(hostname)-$WORKER_ID" \
    "${network_args[@]}" \
    --restart unless-stopped \
    --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup \
    -e DAEMON_ID="$WORKER_ID" \
    -e DOMSERVER_BASEURL="$server_url" \
    -e JUDGEDAEMON_PASSWORD="$JUDGEDAEMON_PASSWORD" \
    -e CONTAINER_TIMEZONE="$TIMEZONE" \
    "domjudge/judgehost:$DOMJUDGE_VERSION"

echo "Started $name. Follow its log with: sudo docker logs -f $name"
echo "It should appear under Jury > Judgehosts in the web interface within a minute."
