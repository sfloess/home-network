#!/bin/sh

# Deploy DD-WRT configs to routers
#
# Usage:
#   ./deploy.sh                  # Deploy to all routers
#   ./deploy.sh server-ap        # Deploy to one router
#   ./deploy.sh server-ap util-ap # Deploy to specific routers

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_DDWRT="ssh -o ConnectTimeout=10 -p 2222"
SSH_CHROOT="ssh -o ConnectTimeout=10"
SCP_CHROOT="scp -o ConnectTimeout=10"

ALL_HOSTS="admin-ap server-ap desktop-ap util-ap"

deploy_host() {
    host="$1"
    dir="${SCRIPT_DIR}/${host}"

    if [ ! -d "$dir" ]; then
        echo "ERROR: No config directory for ${host}"
        return 1
    fi

    echo "=== Deploying to ${host} ==="

    storage="/tmp/mnt/sda1"

    # Copy dd-wrt.conf
    if [ -f "${dir}/dd-wrt.conf" ]; then
        echo "  dd-wrt.conf..."
        $SSH_DDWRT root@${host} "cat > ${storage}/dd-wrt/etc/dd-wrt.conf" < "${dir}/dd-wrt.conf"
    fi

    # Copy chroot-services.list
    if [ -f "${dir}/chroot-services.list" ]; then
        echo "  chroot-services.list..."
        $SSH_DDWRT root@${host} "cat > ${storage}/dd-wrt/etc/chroot-services.list" < "${dir}/chroot-services.list"
    fi

    # Copy debian-mounts.sh (host-specific extra mounts)
    if [ -f "${dir}/debian-mounts.sh" ]; then
        echo "  debian-mounts.sh..."
        $SSH_DDWRT root@${host} "cat > ${storage}/dd-wrt/etc/debian-mounts.sh" < "${dir}/debian-mounts.sh"
    fi

    # Copy sync-dns-zone.sh into the chroot (secondary DNS host)
    if [ -f "${dir}/sync-dns-zone.sh" ]; then
        echo "  sync-dns-zone.sh (chroot /root/bin/)..."
        $SSH_CHROOT root@${host} "mkdir -p /root/bin"
        cat "${dir}/sync-dns-zone.sh" | $SSH_CHROOT root@${host} "cat > /root/bin/sync-dns-zone.sh && chmod +x /root/bin/sync-dns-zone.sh"
    fi

    # Set nvram rc_usb
    if [ -f "${dir}/nvram-rc_usb.sh" ]; then
        echo "  nvram rc_usb..."
        $SSH_DDWRT root@${host} "nvram set rc_usb='$(cat "${dir}/nvram-rc_usb.sh")' && nvram commit"
    fi

    # Set nvram rc_startup
    if [ -f "${dir}/nvram-rc_startup.sh" ]; then
        echo "  nvram rc_startup..."
        $SSH_DDWRT root@${host} "nvram set rc_startup='$(cat "${dir}/nvram-rc_startup.sh")' && nvram commit"
    fi

    echo "  Done."
    echo ""
}

# Determine which hosts to deploy
if [ $# -gt 0 ]; then
    hosts="$@"
else
    hosts="${ALL_HOSTS}"
fi

for host in $hosts; do
    deploy_host "$host"
done
