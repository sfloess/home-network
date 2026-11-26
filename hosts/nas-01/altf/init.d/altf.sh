#!/bin/sh
# altf.sh — firmware glue for nas-01 (Alt-F + Debian chroot)
# Entry: Alt-F user-started-applications runs "<this> start" at boot.
# Standard tree: /mnt/md0/altf/ (see home-network docs/directory-structure.md)

CHROOT=/mnt/md0/debian
LIST=/mnt/md0/altf/etc/chroot-services.list

start() {
    echo "altf bootstrap: starting Debian chroot services..." >> /var/log/altf.log
    for d in dev dev/pts proc sys; do
        mount -o bind /$d $CHROOT/$d 2>/dev/null
    done
    [ -f /etc/hosts ] && cp /etc/hosts $CHROOT/etc/hosts
    for svc in $(cat $LIST); do
        chroot $CHROOT /etc/init.d/$svc start >> /var/log/altf.log 2>&1
    done
}

stop() {
    for svc in $(tac $LIST 2>/dev/null || cat $LIST); do
        chroot $CHROOT /etc/init.d/$svc stop >> /var/log/altf.log 2>&1
    done
    for d in dev/pts dev proc sys; do
        umount -l $CHROOT/$d 2>/dev/null
    done
}

case "$1" in
    start) start ;;
    stop)  stop ;;
esac
