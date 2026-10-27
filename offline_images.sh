#!/bin/bash
# Moves the Docker images to machines without (good) internet access.
#   ./offline_images.sh save   -> writes domjudge-images.tar (on a machine with internet)
#   ./offline_images.sh load   -> loads domjudge-images.tar (on the lab machine)
# Copy the whole repository folder, including the .tar file, with a USB drive.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

images=("mariadb:$MARIADB_VERSION" "domjudge/domserver:$DOMJUDGE_VERSION" "domjudge/judgehost:$DOMJUDGE_VERSION")
case "${1:-}" in
    save)
        for image in "${images[@]}"; do sudo docker pull "$image"; done
        sudo docker save -o domjudge-images.tar "${images[@]}"
        sudo chown "$(id -u):$(id -g)" domjudge-images.tar
        echo "Saved domjudge-images.tar ($(du -h domjudge-images.tar | cut -f1))"
        ;;
    load)
        sudo docker load -i domjudge-images.tar
        ;;
    *)
        echo "Usage: $0 save|load" >&2
        exit 1
        ;;
esac
