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

- `dd-wrt.conf` — Storage path and log file config (sourced by framework scripts)
- `chroot-services.list` — Debian services to start at boot
- `nvram-rc_startup.sh` — Static IP and boot-time config
- `nvram-rc_usb.sh` — USB mount and bootstrap trigger
- `debian-mounts.sh` — (optional) Extra bind mounts for the Debian chroot

## Deployment

Use the deploy script to push configs to routers via SSH (port 2222, dropbear):

```sh
./deploy.sh                    # Deploy to all 4 routers
./deploy.sh server-ap          # Deploy to one router
./deploy.sh server-ap util-ap  # Deploy to specific routers
```

The script copies `dd-wrt.conf`, `chroot-services.list`, and `debian-mounts.sh` to USB storage, and sets `rc_usb` and `rc_startup` via nvram.

### Manual deployment

```sh
# Copy config
ssh -p 2222 root@server-ap "cat > /tmp/mnt/sda1/dd-wrt/etc/dd-wrt.conf" < server-ap/dd-wrt.conf

# Copy chroot services list
ssh -p 2222 root@server-ap "cat > /tmp/mnt/sda1/dd-wrt/etc/chroot-services.list" < server-ap/chroot-services.list

# Copy extra mounts (if present)
ssh -p 2222 root@server-ap "cat > /tmp/mnt/sda1/dd-wrt/etc/debian-mounts.sh" < server-ap/debian-mounts.sh

# Set nvram scripts
ssh -p 2222 root@server-ap "nvram set rc_usb='$(cat server-ap/nvram-rc_usb.sh)' && nvram commit"
ssh -p 2222 root@server-ap "nvram set rc_startup='$(cat server-ap/nvram-rc_startup.sh)' && nvram commit"
```

## Key differences

- **admin-ap**: Debian on `sda2` (not `sda1`), uses `syslog-ng` + `postfix`, `startDebian` commented out in `dd-wrt.sh`
- **server-ap**: Mounts `sdb1` into chroot as `/exports/media-01` for NFS (via `debian-mounts.sh`)
- **util-ap**: Uses `openntpd` instead of `ntpsec` (kernel 4.4 lacks `SO_TIMESTAMPNS`)
- **desktop-ap**: Standard setup, no special mounts
