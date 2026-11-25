# home-network

Reference configurations for my home network: DD-WRT routers running Debian
chroots off USB SSDs, a two-server DNS design with automatic zone sync, and a
cron-driven fleet maintenance loop — all on hardware ranging from a 2014 MIPS
box to modern ARM routers.

The reusable framework these configs deploy through is
[FlossWare/ddwrt-bootstrap](https://github.com/FlossWare/ddwrt-bootstrap).

## Topology

| Host | IP | Hardware | Role | Debian chroot |
|------|-----|----------|------|---------------|
| gateway-ap | 192.168.1.1 | Netgear RAX-75 (stock firmware) | Internet gateway, main 5 GHz AP (`FlossWare-5.0-ghz`) | N/A |
| admin-ap | 192.168.1.2 | Netgear WNDR3700 v4 (MIPS) | Primary DNS/DHCP (dnsmasq), mail relay (postfix), NTP | N/A — Entware only (MIPS) |
| util-ap | 192.168.1.3 | Linksys EA6300 v1 (ARMv7) | Secondary DNS, fleet cron hub, 5 GHz wet bridge to gateway-ap | Yes |
| server-ap | 192.168.1.4 | Netgear R9000 (ARMv7) | NFS media server, MariaDB, PostgreSQL | Yes |
| desktop-ap | 192.168.1.5 | Netgear R9000 (ARMv7) | Desktop-area wireless relay to gateway-ap | Yes |

Fleet hosts (aio-01 backup/rsync hub, nas-01, pi-01/02) are maintained by the
fleet cron that runs on util-ap — see `fleet/fleet-crontab`.

## The patterns worth stealing

### 1. Boot chain that survives firmware flashes

DD-WRT's jffs is disabled. Instead, a tiny script in nvram (`rc_usb`, runs when
USB automounts at boot) mounts the USB SSD by partition label and hands off to
`dd-wrt/etc/init.d/dd-wrt.sh`:

```
nvram rc_usb  →  mount USB SSD  →  /tmp/mnt/sda1/dd-wrt/etc/init.d/dd-wrt.sh start
```

Because the chain lives in nvram + on the USB disk, **in-place firmware
flashes never break it** — every router comes back up fully configured on its
own, including the chroots. See `<host>/nvram-rc_usb.sh` for the per-router
variants (label-based on the R9000s, blkid-based on util-ap).

### 2. Debian chroot services from a list

Each chroot router has a `chroot-services.list` — one Debian init script name
per line. `dd-wrt.sh` binds `dev/pts/proc/sys` into the chroot and starts each
service in order. To add a service to a router: add a line, reboot (or run the
init script by hand).

### 3. Two-server DNS with automatic zone sync

Primary DNS is admin-ap's dnsmasq (it owns DHCP, so it's the zone authority).
Secondary DNS runs as dnsmasq inside util-ap's Debian chroot — DNS-only, no
DHCP. `util-ap/sync-dns-zone.sh` regenerates the secondary's entire config
from the primary's live generated config over SSH and restarts dnsmasq only
when the zone actually changed. It runs weekly via cron; run it manually after
editing the primary zone. DHCP advertises both servers (`dhcp-option=6`).

Why it matters: dnsmasq has no HA protocol, so the secondary is pure DNS. When
the primary dies, existing leases keep working, static IPs are unaffected, and
name resolution fails over — only *new* DHCP leases wait for the primary.

### 4. Fleet maintenance cron

One crontab on util-ap (`fleet/fleet-crontab`) drives the whole fleet:
Monday-rolling `apt upgrade` per host, nightly `rsync` backups of `/etc
/opt /root /home` to a central rsync server, results mailed via
msmtp → postfix relay.

### 5. Entware where a chroot isn't possible

admin-ap's MIPS kernel can't run the Debian chroot, so it uses Entware
(opkg packages on the USB SSD) for postfix, syslog-ng, cron, ntpd. Same
`rc_usb` boot chain, `startDebian` commented out of its `dd-wrt.sh`.

## Repo layout

```
<host>/chroot-services.list   Debian init scripts to start in the chroot
<host>/nvram-rc_usb.sh        Boot hook: mount USB, start dd-wrt.sh
<host>/nvram-rc_startup.sh    Extra rc_startup content (host-specific)
<host>/dd-wrt.conf            dd-wrt.sh variables
admin-ap/dnsmasq_options.conf The DNS zone (source of truth)
util-ap/sync-dns-zone.sh      Secondary DNS zone sync
fleet/fleet-crontab           Fleet upgrades + backups schedule
gateway-ap/                   Stock-firmware notes (nothing deployable)
docs/known-issues.md          Field notes: real DD-WRT failure modes
deploy.sh                     Push configs to the routers
```

## Deploying

```sh
./deploy.sh                  # all routers
./deploy.sh util-ap          # one router
```

Deploy writes the files to each router's USB SSD and sets the nvram values,
then commits. Routers pick changes up on next boot (or restart services by
hand).

## Not in this repo

- Secrets: WiFi PSKs, nvram snapshots, SSH keys. The nvram dumps in
  particular contain key material and stay off git entirely.
- The bootstrap framework itself ([ddwrt-bootstrap](https://github.com/FlossWare/ddwrt-bootstrap)):
  `dd-wrt.sh`, `debian.sh`, `entware.sh` live there.

SSH conventions: port 22 = Debian chroot, port 2222 = DD-WRT dropbear —
except admin-ap, where 22 is the router (Entware) side since it has no chroot.
