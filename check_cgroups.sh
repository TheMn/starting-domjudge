#!/bin/bash
# Checks whether this machine can run a DOMjudge judgehost (cgroup support)
# and, if needed, configures the kernel boot options. Only needed on machines
# that will run judgehosts; the domserver alone does not need it.
#
# DOMjudge >= 9.0 supports cgroup v2 (the default on Ubuntu 22.04+) but needs
# kernel >= 5.19 for it. Older kernels must fall back to cgroup v1.
set -euo pipefail

cgroup_fs=$(stat -fc %T /sys/fs/cgroup)
kernel=$(uname -r)
major=$(echo "$kernel" | cut -d. -f1)
minor=$(echo "$kernel" | cut -d. -f2)
is_wsl=0
grep -qi microsoft /proc/version && is_wsl=1

echo "Kernel:       $kernel"
echo "cgroup fs:    $cgroup_fs"
echo "Kernel args:  $(cat /proc/cmdline)"
echo

if [ "$cgroup_fs" = "cgroup2fs" ]; then
    if [ "$major" -gt 5 ] || { [ "$major" -eq 5 ] && [ "$minor" -ge 19 ]; }; then
        echo "OK: cgroup v2 with kernel >= 5.19. Nothing to change, you can start judgehosts."
        exit 0
    fi
    echo "PROBLEM: cgroup v2 needs kernel >= 5.19, but this machine runs $kernel."
    if [ "$is_wsl" -eq 1 ]; then
        echo "Fix: in Windows PowerShell run 'wsl --update', then 'wsl --shutdown' and reopen Ubuntu."
        exit 1
    fi
    echo
    if grep -q "^ID=ubuntu" /etc/os-release; then
        echo "Option 1 (needs internet): install the newer HWE kernel and reboot:"
        echo "    sudo apt install -y linux-generic-hwe-22.04 && sudo reboot"
        echo "Option 2 (works offline): switch this machine to cgroup v1 (needs a reboot)."
    else
        echo "Fix (works offline): switch this machine to cgroup v1 (needs a reboot)."
    fi
    echo
    read -r -p "Switch this machine to cgroup v1 via GRUB now? [y/N] " answer
    [ "$answer" = "y" ] || [ "$answer" = "Y" ] || exit 1
elif [ -f /sys/fs/cgroup/memory/memory.memsw.limit_in_bytes ]; then
    echo "OK: cgroup v1 with memory accounting enabled. You can start judgehosts."
    exit 0
elif [ "$is_wsl" -eq 1 ]; then
    echo "PROBLEM: WSL is not using cgroup v2. Run 'wsl --update' in Windows PowerShell,"
    echo "and make sure /etc/wsl.conf contains '[boot]' and 'systemd=true'."
    exit 1
fi

# Fall back to cgroup v1. Written as a separate file so it is easy to undo
# (delete the file and run update-grub) and safe to run more than once.
grub_file=/etc/default/grub.d/99-domjudge.cfg
echo "Writing $grub_file"
sudo mkdir -p /etc/default/grub.d
# shellcheck disable=SC2016  # $GRUB_CMDLINE_LINUX_DEFAULT must expand when GRUB reads the file
echo 'GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT cgroup_enable=memory swapaccount=1 systemd.unified_cgroup_hierarchy=0"' \
    | sudo tee "$grub_file"
sudo update-grub
echo
echo "Done. Reboot, then run this script again to verify."
