# Fleet hosts

Non-router machines on the network. The maintenance loop for all of them is
`fleet/fleet-crontab` (runs on util-ap): Monday apt upgrades in a rolling
window, nightly rsync backups to aio-01.

| Host | IP | Role |
|------|-----|------|
| aio-01 | 192.168.1.15 | Backup/rsync hub (`rsync://aio-01/exports`), planned syslog collector |
| nas-01 | 192.168.1.10 | NAS + syslog collector (Alt-F + Debian chroot) |
| pi-01 | 192.168.1.11 | Agent DVR, firewall experiments |
| pi-02 | 192.168.1.12 | Jellyfin |

Per-host configs land here as they become interesting. aio-01's rsyncd
config is in `aio-01/rsyncd.conf`.
