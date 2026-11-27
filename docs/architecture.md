# FlossWare home network — layered architecture

The canonical layer model. Every decision in the fleet should be answerable
with "which layer owns this?" The layers stack one way; components within a
layer are chosen per box.

```
┌─────────────────────────────────────────────────────────────────────┐
│ 6. OPERATIONS    fleet cron · syslog→aio-01 · backups→aio-01 ·     │
│                  monitoring · CI (GitHub Actions + self-runner)    │
├─────────────────────────────────────────────────────────────────────┤
│ 5. SERVICES      per-box daemons: dnsmasq/rsyslog/msmtpd/rsyncd/   │
│                  nfsd/postfix/ntpd — managed by chroot-services.list│
├─────────────────────────────────────────────────────────────────────┤
│ 4. DEBIAN        the chroot (armel/armhf/arm64) — an ADD-ON, never │
│                  baked into any base. Build via debootstrap in the │
│                  VM (fleet-builder), stage-2 on device             │
├─────────────────────────────────────────────────────────────────────┤
│ 3. BOOTSTRAP     embedded-bootstrap: the firmware-parameterized     │
│   CONTRACT       contract (manifest + chroot.sh + shared root/.ssh)│
│                  — identical on every box regardless of base       │
├─────────────────────────────────────────────────────────────────────┤
│ 2. MIDDLEWARE    Entware (opkg feed) — the common package layer;   │
│                  admin-ap ONLY (policy: chroot-less boxes only)   │
├─────────────────────────────────────────────────────────────────────┤
│ 1. BASE          firmware — PEERS, NOT STACKABLE. Chosen per box:  │
│                  · FlossWare base (alt-f fork) → unsupported boxes │
│                  · OpenWrt                → boxes it supports      │
│                  · DD-WRT                 → blob-locked boxes      │
├─────────────────────────────────────────────────────────────────────┤
│ 0. HARDWARE      the box itself + U-Boot (stock, never touched)    │
└─────────────────────────────────────────────────────────────────────┘
```

## The rules

1. **Bases are peers** (layer 1). You cannot layer one firmware over
   another — OpenWrt is a base, not a topping. The choice per box is
   "who maintains the board support," nothing more.

2. **The contract is layer 3, not any base.** `embedded-bootstrap`
   (firmware-tree + `chroot-services.list` + chroot semantics) works over
   all three bases identically. Portability of the *contract* is what makes
   base choice a non-decision.

3. **Debian is an add-on** (layer 4), never included in a base. Bases stay
   small (busybox + libc, self-contained); Debian exists only as a chroot on
   disk, installed/deployed by the bootstrap layer. Same for its build
   tooling: debootstrap runs in the VM, never on fleet hosts.

4. **Entware is chroot-less only** (layer 2). Where a Debian chroot exists,
   Debian supersedes it. admin-ap is the only Entware box (by physics on
   current firmware; by choice after OpenWrt migration).

5. **Operations are fleet-wide** (layer 6) and never live in a base: fleet
   cron (candidate for relocation off util-ap, issue #35), syslog to the
   aio-01 collector, backups to aio-01, CI via GitHub Actions with the
   self-hosted runner in the fleet-builder VM.

6. **Build environments are cattle** ("cow"). Any build environment (the
   bullseye chroot, the fleet-builder VM itself) is recreated from a script
   on demand and deleted after; nothing about it is maintained, patched, or
   kept current. Only its recipe (checked into the repo) is durable.

## Per-box mapping

| Box | 0 HW | 1 Base | 2 Entware | 4 Debian | Notes |
|---|---|---|---|---|---|
| gateway-ap | RAX-75 | stock Netgear | — | — | permanent exception |
| admin-ap | WNDR3700v4 | DD-WRT d6 → OpenWrt (#36) | ✓ (until migration) | after migration (PIE) | DNS/DHCP — migrate carefully |
| util-ap | EA6300 | DD-WRT st80 | ✗ (policy) | ✓ 13 armel | wedge-prone; no armhf (no VFP) |
| server-ap | R9000 | DD-WRT #137 | ✗ | ✓ 13 armhf | NFS+DBs; squashfs watch (#20) |
| desktop-ap | R9000 | DD-WRT #137 | ✗ | ✓ 13 armhf | |
| nas-01 | DNS-320 | Alt-F 4.4.86 → FlossWare base | ✗ | ✓ 13 armel (trixie) | NFSv4 blocked on kernel → fork |
| laptop-01 | T590 | Debian 13 | — | — | VM host (fleet-builder) |
| laptop-02 | P1 Gen 8 | Fedora 44 | — | — | operator console; exempt |
| aio-01 | | Debian 13 | — | — | backup hub, syslog collector, CI runner |

## Repos

| Repo | Layer | Owns |
|---|---|---|
| `FlossWare/embedded-bootstrap` | 3 | the contract: init scripts, service manifests, build recipes |
| `FlossWare/alt-f` | 1 | FlossWare base (fork of Alt-F for unsupported boxes) |
| `sfloess/home-network` | all | per-box configs, fleet docs, the issue tracker |

## What this model answers

- **"Can we put X on Y?"** — only within the same layer-column; firmware
  over firmware = no; our layers (2–6) over any base = yes.
- **"Who maintains this?"** — the layer determines the maintainer: kernel
  (base community/fork), packages (Entware/Debian), the contract (us),
  operations (us).
- **"Is it a base decision?"** — if the answer doesn't change the contract
  above it, it's a per-box convenience, not an architecture change.
