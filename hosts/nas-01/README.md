# nas-01 — D-Link DNS-320 (Alt-F + Debian 12)

192.168.1.10. A 2010-era 2-bay NAS kept useful: **Alt-F firmware** (kernel
4.4.86, aufs overlay, BusyBox init) boots the box and starts a **Debian 12
chroot** on the md0 array — the same firmware-plus-chroot pattern as the
routers, different firmware.

- **Syslog collector** for the fleet: rsyslog on UDP/TCP 514, per-host logs
  under `/exports/log/`. Forwarders send to the hostname `rsyslog`, which
  the DNS zone points here. See `rsyslog-collector.conf`.
- Serves `/exports` via NFS (LAN, rw) and rsync (`rsyncd.conf`): media,
  host backups, provision trees.
- Mail via msmtpd; disk temps via hddtemp.
- **Caveat:** the 2x 2TB disks are a *linear* (spanned) md0 — no
  redundancy. Either disk failing loses the array. 87% full.
- systemd is not PID 1 here; `systemctl` shows unit-file states only.
  Services actually start via Alt-F's user-applications mechanism.

Access: `ssh root@nas-01` port 22 (Debian sshd, fleet key). Alt-F's own
dropbear is on 2222 (different credentials) and its web UI on 8080.
