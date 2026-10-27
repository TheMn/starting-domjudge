#!/bin/bash
# Installs Docker (Ubuntu/Debian) and downloads the images needed by DOMjudge.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

if ! command -v docker > /dev/null; then
    sudo apt update
    sudo apt install -y docker.io curl
fi

# Make sure the Docker daemon is running and starts on boot.
if command -v systemctl > /dev/null && [ "$(ps -p 1 -o comm=)" = "systemd" ]; then
    sudo systemctl enable --now docker
else
    # e.g. WSL without systemd enabled
    sudo service docker start
fi

sudo docker pull "mariadb:$MARIADB_VERSION"
sudo docker pull "domjudge/domserver:$DOMJUDGE_VERSION"
sudo docker pull "domjudge/judgehost:$DOMJUDGE_VERSION"
