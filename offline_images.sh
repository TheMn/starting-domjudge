#!/bin/bash
# Prepares everything for installing on a machine without internet, via USB drive.
#   ./offline_images.sh save [ubuntu-codename]
#       Run on a machine with internet (e.g. your laptop). Writes the offline/ folder:
#       the Docker images plus the Docker .deb packages for the target Ubuntu
#       version (default: jammy = Ubuntu 22.04; noble = 24.04).
#   ./offline_images.sh load
#       Run on the lab machine. Installs Docker from offline/ if it is missing,
#       then loads the images.
# Copy the whole repository folder, including offline/, with a USB drive.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

images=("mariadb:$MARIADB_VERSION" "domjudge/domserver:$DOMJUDGE_VERSION" "domjudge/judgehost:$DOMJUDGE_VERSION")
case "${1:-}" in
    save)
        codename=${2:-jammy}
        mkdir -p offline/docker-debs
        pool="https://download.docker.com/linux/ubuntu/dists/$codename/pool/stable/amd64/"
        listing=$(curl -fsSL "$pool")
        for package in containerd.io docker-ce-cli docker-ce; do
            deb=$(echo "$listing" | grep -oE "href=\"${package}_[^\"]+\.deb\"" \
                | sed 's/href="//; s/"$//' | sort -V | tail -1)
            echo "Downloading $deb"
            curl -fsSL -o "offline/docker-debs/$deb" "$pool$deb"
        done
        for image in "${images[@]}"; do
            # Docker Hub may refuse pulls (rate limits); a local copy is fine too.
            sudo docker pull "$image" || sudo docker image inspect "$image" > /dev/null
        done
        sudo docker save -o offline/domjudge-images.tar "${images[@]}"
        sudo chown -R "$(id -u):$(id -g)" offline
        echo "Saved offline/ ($(du -sh offline | cut -f1)). Copy the whole repository folder to the USB drive."
        ;;
    load)
        if ! command -v docker > /dev/null; then
            echo "Installing Docker from offline/docker-debs"
            sudo dpkg -i offline/docker-debs/containerd.io_*.deb \
                offline/docker-debs/docker-ce-cli_*.deb offline/docker-debs/docker-ce_*.deb
            sudo systemctl enable --now docker
        fi
        sudo docker load -i offline/domjudge-images.tar
        echo "Done. Next: ./start_server.sh"
        ;;
    *)
        echo "Usage: $0 save [ubuntu-codename] | load" >&2
        exit 1
        ;;
esac
