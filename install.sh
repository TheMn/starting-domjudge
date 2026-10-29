#!/bin/bash
# Installs Docker and downloads the DOMjudge and MariaDB images.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

command -v docker > /dev/null || { sudo apt update && sudo apt install -y docker.io; }
sudo systemctl enable --now docker

sudo docker pull "mariadb:$MARIADB_VERSION"
sudo docker pull "domjudge/domserver:$DOMJUDGE_VERSION"
sudo docker pull "domjudge/judgehost:$DOMJUDGE_VERSION"
