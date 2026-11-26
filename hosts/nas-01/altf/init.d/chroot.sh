#!/bin/sh
# chroot.sh — COMMON Debian chroot bootstrap (debian.sh equivalent, firmware-neutral)
# Used by altf.sh on Alt-F; the DD-WRT family equivalent lives in ddwrt-bootstrap.

CHROOT_DIR=$1
[ -z "$CHROOT_DIR" ] && CHROOT_DIR=/mnt/md0/debian
CHROOT_SERVICES_LIST=/mnt/md0/altf/etc/chroot-services.list

start() {
    [ -f /etc/resolv.conf ] && cp /etc/resolv.conf $CHROOT_DIR/etc/resolv.conf
    echo "Starting Debian services..."
    for dir in dev dev/pts proc sys; do
        /bin/mount -o bind /$dir $CHROOT_DIR/$dir
    done
    for item in $(cat $CHROOT_SERVICES_LIST); do
        chroot $CHROOT_DIR /etc/init.d/$item start
    done
}

stop() {
    for item in $(cat $CHROOT_SERVICES_LIST); do
        chroot $CHROOT_DIR /etc/init.d/$item stop
    done
    for dir in dev/pts dev proc sys; do
        /bin/umount -l $CHROOT_DIR/$dir 2>/dev/null
    done
}

case "$1" in start) start ;; stop) stop ;; esac
