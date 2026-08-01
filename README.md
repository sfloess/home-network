# ddwrt-config

Host-specific configurations for my DD-WRT routers. Uses [FlossWare/ddwrt-bootstrap](https://github.com/FlossWare/ddwrt-bootstrap) as the framework.

## Routers

| Host | IP | Role | Debian Chroot | Notes |
|------|-----|------|---------------|-------|
| admin-ap | 192.168.1.2 | DNS/DHCP/NTP server | sda2 (Entware on sda1) | Entware-only bootstrap, postfix, syslog-ng |
| util-ap | 192.168.1.3 | Utility | sda1 | openntpd (kernel 4.4, ntpsec incompatible) |
| server-ap | 192.168.1.4 | NFS server | sda1 | NFS exports via sdb1, rsync |
| desktop-ap | 192.168.1.5 | General purpose | sda1 | rsync |

## Per-host files

Each directory contains:

- `chroot-services.list` — Debian services to start at boot
- `debian.sh` — Debian chroot launcher (host-specific mounts and partition paths)
- `nvram-rc_startup.sh` — Static IP and boot-time config
- `nvram-rc_usb.sh` — USB mount and bootstrap trigger

## Deployment

Copy the host-specific files to the router's USB storage:

```sh
# Copy chroot services list
scp server-ap/chroot-services.list root@server-ap:/tmp/mnt/sda1/dd-wrt/etc/

# Copy debian.sh
scp server-ap/debian.sh root@server-ap:/tmp/mnt/sda1/dd-wrt/etc/init.d/

# Set nvram scripts
ssh -p 2222 root@server-ap "nvram set rc_usb='$(cat server-ap/nvram-rc_usb.sh)' && nvram commit"
ssh -p 2222 root@server-ap "nvram set rc_startup='$(cat server-ap/nvram-rc_startup.sh)' && nvram commit"
```

## Key differences

- **admin-ap**: Debian on `sda2` (not `sda1`), uses `syslog-ng` + `postfix`, `startDebian` commented out in `dd-wrt.sh`
- **server-ap**: Mounts `sdb1` into chroot as `/exports/media-01` for NFS
- **util-ap**: Uses `openntpd` instead of `ntpsec` (kernel 4.4 lacks `SO_TIMESTAMPNS`)
- **desktop-ap**: Standard setup, no special mounts
