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

    # Determine storage dir (admin-ap uses sda2 for debian configs)
    storage="/tmp/mnt/sda1"

    # Copy chroot-services.list via DD-WRT side
    if [ -f "${dir}/chroot-services.list" ]; then
        echo "  chroot-services.list..."
        $SSH_DDWRT root@${host} "cat > ${storage}/dd-wrt/etc/chroot-services.list" < "${dir}/chroot-services.list"
    fi

    # Copy debian.sh via DD-WRT side
    if [ -f "${dir}/debian.sh" ]; then
        echo "  debian.sh..."
        $SSH_DDWRT root@${host} "cat > ${storage}/dd-wrt/etc/init.d/debian.sh && chmod +x ${storage}/dd-wrt/etc/init.d/debian.sh" < "${dir}/debian.sh"
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
