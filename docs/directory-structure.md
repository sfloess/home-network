# Embedded fleet directory structure

Where everything lives on the routers and nas-01. The common principle: the
firmware (nvram/flash) stays minimal and stock; everything persistent lives
on disk, and a tiny boot hook chains from firmware into that disk.

## The standard: firmware-parameterized, Debian-common

```
<disk>/
├── <firmware-tree>/         # dd-wrt/ on DD-WRT routers, altf/ on nas-01
│   ├── etc/chroot-services.list   # COMMON: service manifest
│   └── init.d/
│       ├── <fw>.sh                # firmware glue (entry, binds, mounts)
│       ├── chroot.sh              # COMMON: Debian chroot bootstrap
│       └── entware.sh             # DD-WRT family only
├── entware/                  # chroot-less boxes only (admin-ap)
└── debian/                   # COMMON: the chroot, everywhere
```

Common across both families: the manifest, `chroot.sh`, `debian/` semantics.
Firmware-specific: only the entry glue — nvram `rc_usb` → `dd-wrt.sh` on
DD-WRT boxes; Alt-F user-started-apps → `altf.sh` on nas-01. Note nas-01's
tree is `altf/` (no dash): the firmware's own config dirs at `/mnt/md0`
are already `Alt-F/` and `alt-f`.

**Entware policy (Flossy, 2026-11-26):** Entware is the userland layer for
boxes that cannot run a Debian chroot — admin-ap only, everywhere else it
is excluded (Debian supersedes it). util-ap's dormant tree removed; the
R9000s and nas-01 never run it. The empty `entware/` dir may remain where
the bind-mount layout expects it.

- Routers: nvram `rc_usb` → `/tmp/mnt/sda1/dd-wrt/etc/init.d/dd-wrt.sh`
- nas-01: Alt-F user-started-app → `/mnt/md0/altf/init.d/altf.sh` (planned)

## Router USB SSD — `/tmp/mnt/sda1`

Identical shape on util-ap, server-ap, desktop-ap:

```
/tmp/mnt/sda1/
├── dd-wrt/                        # config + boot tree (the flash-survivor)
│   ├── etc/
│   │   ├── chroot-services.list   # Debian init scripts to start, one per line
│   │   └── motd                   # bind-mounted over /etc/motd everywhere
│   ├── init.d/
│   │   ├── dd-wrt.sh              # master: modprobe, binds, swap, entware, debian
│   │   ├── debian.sh              # chroot bootstrap: binds + service starts
│   │   └── entware.sh             # → /opt/etc/init.d/rc.unslung
│   ├── root/                      # THE shared root home
│   │   └── .ssh/                  # fleet keys (id_rsa + authorized_keys)
│   └── var/swapfile               # swap, activated by dd-wrt.sh
├── debian/                        # Debian 13 chroot root (full userland)
│   └── exports/                   # the rsync `exports` module target
├── entware/                       # Entware tree (router-side bind → /opt)
└── dd-wrt.tar, trixie_armhf.tar   # bootstrap remnants (config/rootfs tarballs)
```

**`dd-wrt/root` is the linchpin**: `dd-wrt.sh` bind-mounts it to the router's
`/tmp/root` (dropbear's authorized_keys), the chroot's `/root`, and Entware's
`/root` — one `.ssh` shared by all three layers of the box.

Per-device notes:
- **admin-ap** (MIPS, no chroot): no `debian/`; Entware-only. It carried a
  dead 256 MB root-level `swapfile` from before the boot script's path was
  `dd-wrt/var/swapfile` (the original silent swap failure) — cleared
  2026-11-26.
- **server-ap** `debian/` has bootstrap artifacts at its top level:
  `chroot-install.sh`, `db.tar`, `grafana.tar`.
- **util-ap** has `ftp/chroot` — a standalone `chroot` binary kept from the
  original bootstrap (the old `mipsel.tar` and a stray `start-ntpd.sh` were
  cleared 2026-11-26).

## The chroot's view (binds created at boot)

`debian.sh` binds `dev`, `dev/pts`, `proc`, `sys` from the router, copies
`/etc/hosts` and `/etc/resolv.conf` in, then starts each entry of
`chroot-services.list`. The chroot's `/opt` is its own directory — the
Entware `/opt` bind exists only in the router's namespace.

## nas-01 — `/mnt/md0` (Alt-F view, reachable via dropbear :2222)

```
/mnt/md0/
├── debian/                    # live Debian 12 chroot (Alt-F starts it at boot)
├── 2024-03-26_20-54_debian/   # dated snapshot of a previous Debian tree
├── bak.debian/                # older snapshot
├── Alt-F/  alt-f              # firmware config (two names, both live)
├── alt-f.log, -previous       # firmware log
├── exports/                   # bind → /exports (NFS + rsync)
├── root/
└── drive-perf.sh
```

`/Alt-F` at the firmware root is the aufs overlay layer (`etc/`, `usr/`,
`var/`) — probe it with bounded commands only; recursive greps hang on it.

## `/exports` — the fleet-wide convention

Every machine exposes `/exports` via the rsync `exports` module (fleet
policy, 2026-11-25). Notable trees:

- **aio-01** (the hub): `/exports/backups/host/<host>/{etc,opt,root,home}`
  from the nightly fleet cron, plus `archive/` (kept items removed from
  sources — outside the `--delete` mirror), plus `log/` — the syslog
  collector's per-host output.
- **nas-01**: `desktop, gpg, host (legacy backup tree), log (collector
  history), media, provision, user, amy, admin-ap_etc` + loose files.
- **server-ap** chroot: `exports/media` (the NFS media share).
