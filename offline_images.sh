#!/bin/bash
# Prepares everything for installing on a machine without internet, via USB drive.
#   ./offline_images.sh save [distro] [codename]
#       Run on a machine with internet (e.g. your laptop). Writes the offline/ folder:
#       the Docker images plus Docker's .deb packages (and their dependencies)
#       for the target system. Examples:
#         ./offline_images.sh save                   # Ubuntu 22.04 (default)
#         ./offline_images.sh save ubuntu noble      # Ubuntu 24.04
#         ./offline_images.sh save debian bookworm   # Debian 12
#         ./offline_images.sh save debian trixie     # Debian 13
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
        distro=${2:-ubuntu}
        codename=${3:-jammy}
        rm -rf offline/docker-debs
        mkdir -p offline/docker-debs
        curl -fsSL -o offline/docker.asc "https://download.docker.com/linux/$distro/gpg"
        # Let apt in a clean container of the target system download Docker and
        # every dependency that a minimal install lacks.
        sudo docker run --rm --network host -e "http_proxy=${http_proxy:-}" -e "https_proxy=${https_proxy:-}" \
            -v "$PWD/offline:/offline" "$distro:$codename" bash -euc "
                rm -f /etc/apt/apt.conf.d/docker-clean
                apt-get update -qq
                apt-get install -y -qq --no-install-recommends ca-certificates > /dev/null
                rm -f /var/cache/apt/archives/*.deb
                echo 'deb [signed-by=/offline/docker.asc] https://download.docker.com/linux/$distro $codename stable' \
                    > /etc/apt/sources.list.d/docker.list
                apt-get update -qq
                apt-get install -y -qq --no-install-recommends --download-only docker-ce docker-ce-cli containerd.io iptables sudo
                cp /var/cache/apt/archives/*.deb /offline/docker-debs/"
        for image in "${images[@]}"; do
            # Docker Hub may refuse pulls (rate limits); a local copy is fine too.
            sudo docker pull "$image" || sudo docker image inspect "$image" > /dev/null
        done
        sudo docker save -o offline/domjudge-images.tar "${images[@]}"
        sudo chown -R "$(id -u):$(id -g)" offline
        echo "$distro $codename" > offline/target.txt
        echo "Saved offline/ for $distro $codename ($(du -sh offline | cut -f1))."
        echo "Copy the whole repository folder to the USB drive."
        ;;
    load)
        if ! command -v docker > /dev/null; then
            echo "Installing Docker from offline/docker-debs (prepared for $(cat offline/target.txt))"
            # Only install packages the system doesn't have yet; never downgrade.
            debs=()
            for deb in offline/docker-debs/*.deb; do
                package=$(dpkg-deb -f "$deb" Package)
                if ! dpkg-query -W -f='${Status}' "$package" 2> /dev/null | grep -q "ok installed"; then
                    debs+=("$deb")
                fi
            done
            sudo dpkg -i "${debs[@]}"
            sudo systemctl enable --now docker
        fi
        sudo docker load -i offline/domjudge-images.tar
        echo "Done. Next: ./start_server.sh"
        ;;
    *)
        echo "Usage: $0 save [distro] [codename] | load" >&2
        exit 1
        ;;
esac
