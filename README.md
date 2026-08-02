# ddwrt-config

Host-specific configurations for my DD-WRT routers. Uses [FlossWare/ddwrt-bootstrap](https://github.com/FlossWare/ddwrt-bootstrap) as the framework.

## Prerequisites

- [FlossWare/ddwrt-bootstrap](https://github.com/FlossWare/ddwrt-bootstrap) framework deployed on your routers
- An ed25519 SSH key for dropbear access (DD-WRT v2025.89+ only supports ed25519)
- SSH config with ProxyJump if managing routers through a bastion host

## Routers

| Host | IP | Role | Debian Chroot | Notes |
|------|-----|------|---------------|-------|
| admin-ap | 192.168.1.2 | DNS/DHCP/NTP server | N/A (MIPS, Entware on sda1) | Entware-only (no Debian chroot on MIPS), postfix, syslog-ng |
| util-ap | 192.168.1.3 | Utility | sda1 | openntpd (kernel 4.4, ntpsec incompatible) |
| server-ap | 192.168.1.4 | NFS server | sda1 | NFS exports via sdb1, rsync |
| desktop-ap | 192.168.1.5 | General purpose | sda1 | rsync |

## Per-host files

Each directory contains:

- `dd-wrt.conf` -- Storage path and log file config (sourced by framework scripts)
- `chroot-services.list` -- Debian services to start at boot (one service name per line)
- `nvram-rc_startup.sh` -- Static IP configuration and boot-time settings that run before USB detection
- `nvram-rc_usb.sh` -- USB mount handler and bootstrap trigger that runs when USB storage is detected
- `debian-mounts.sh` -- (optional) Extra bind mounts for the Debian chroot, defining `start_extra_mounts()` and `stop_extra_mounts()` functions
- `dnsmasq_options.conf` -- (admin-ap only) Full dnsmasq configuration for DNS, DHCP, and static leases

## Deployment

Use the deploy script to push configs to routers via SSH (port 2222, dropbear). Requires ed25519 SSH key authentication and network connectivity to target routers.

```sh
./deploy.sh                    # Deploy to all 4 routers
./deploy.sh server-ap          # Deploy to one router
./deploy.sh server-ap util-ap  # Deploy to specific routers
```

The script copies `dd-wrt.conf`, `chroot-services.list`, and `debian-mounts.sh` to USB storage, and sets `rc_usb` and `rc_startup` via nvram.

### Automated sync

A cron job on aio-01 pulls `dnsmasq_options` from admin-ap every 6 hours and commits changes to this repo automatically.

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

- **admin-ap**: MIPS 74Kc (no Debian chroot support), Entware-only on `sda1`, uses `syslog-ng` + `postfix`
- **server-ap**: Mounts second USB disk (`sdb1`) into chroot as `/exports/media-01` for NFS file sharing (configured via `debian-mounts.sh`)
- **util-ap**: Uses `openntpd` instead of `ntpsec` because the kernel (4.4) lacks `SO_TIMESTAMPNS` support required by ntpsec
- **desktop-ap**: Standard setup, no special mounts or custom services
