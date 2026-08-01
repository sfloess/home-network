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

Use the deploy script to push configs to routers via SSH (port 2222, dropbear):

```sh
./deploy.sh                    # Deploy to all 4 routers
./deploy.sh server-ap          # Deploy to one router
./deploy.sh server-ap util-ap  # Deploy to specific routers
```

The script copies `chroot-services.list` and `debian.sh` to USB storage, and sets `rc_usb` and `rc_startup` via nvram.

### Manual deployment

```sh
# Copy chroot services list
ssh -p 2222 root@server-ap "cat > /tmp/mnt/sda1/dd-wrt/etc/chroot-services.list" < server-ap/chroot-services.list

# Copy debian.sh
ssh -p 2222 root@server-ap "cat > /tmp/mnt/sda1/dd-wrt/etc/init.d/debian.sh && chmod +x /tmp/mnt/sda1/dd-wrt/etc/init.d/debian.sh" < server-ap/debian.sh

# Set nvram scripts
ssh -p 2222 root@server-ap "nvram set rc_usb='$(cat server-ap/nvram-rc_usb.sh)' && nvram commit"
ssh -p 2222 root@server-ap "nvram set rc_startup='$(cat server-ap/nvram-rc_startup.sh)' && nvram commit"
```

## Key differences

- **admin-ap**: Debian on `sda2` (not `sda1`), uses `syslog-ng` + `postfix`, `startDebian` commented out in `dd-wrt.sh`
- **server-ap**: Mounts `sdb1` into chroot as `/exports/media-01` for NFS
- **util-ap**: Uses `openntpd` instead of `ntpsec` (kernel 4.4 lacks `SO_TIMESTAMPNS`)
- **desktop-ap**: Standard setup, no special mounts
