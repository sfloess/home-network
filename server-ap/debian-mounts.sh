# server-ap: mount sdb1 into chroot for NFS exports

start_extra_mounts() {
    mkdir -p ${CHROOT_DIR}/exports/media-01
    mount -o bind /tmp/mnt/sdb1 ${CHROOT_DIR}/exports/media-01
}

stop_extra_mounts() {
    umount ${CHROOT_DIR}/exports/media-01
}
