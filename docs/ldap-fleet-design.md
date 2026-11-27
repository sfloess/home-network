# LDAP fleet design (staged with the admin-ap OpenWrt migration, #36)

## Server

- **slapd on admin-ap** (OpenWrt, `openldap-server` package), MDB files on the
  USB SSD (mounted via `/etc/config/fstab` — no boot-chain scripting).
- SSD also hosts swap (256 MB) and the LDAP database; NAND keeps the OS.
- **Backup:** nightly `slapcat` to LDIF (a few KB), rsynced to aio-01 —
  never copy live MDB files (memory-mapped, unsafe while slapd runs).
  The LDIF is small enough to also sit in git as reviewable config.
- **Later hardening:** syncrepl replica on aio-01 so identity survives
  admin-ap/powerline outages (DNS already fails over to util-ap; identity
  currently has no failover story).

## What LDAP controls

| Concern | Mechanism | Where it works |
|---|---|---|
| POSIX identity (uid/gid/shell/groups) | nsswitch → `nss-ldapd` | all glibc hosts: Debian chroots, x86 boxes, pis |
| Login passwords | PAM → `pam_ldapd` | same glibc hosts |
| SSH public keys | `openssh-lpk` schema | glibc hosts; OpenWrt base hosts via `AuthorizedKeysCommand` + ldapsearch |
| sudo rules (optional) | sudoers LDAP schema | glibc hosts |
| Host access classes (optional) | ldapns host filters | glibc hosts |
| App auth (later) | Gitea/Jenkins-style backends | anywhere that speaks LDAP |

Key win for this fleet: **key distribution**. Today authorized_keys is
hand-synced per box (the util-ap incident was exactly this failure mode).
Central keys in LDAP make a new fleet key a one-line directory change.

## Layer mapping (why LDAP is a Debian-layer concern)

- **musl does not do NSS/PAM.** OpenWrt base hosts (admin-ap) cannot be
  full LDAP clients for password login without glibc. Pragmatic pattern
  there: keep local root auth, use `AuthorizedKeysCommand` running
  `ldapsearch` to pull keys from the directory — keys centralized,
  passwords local.
- **DD-WRT bases:** unchanged — dropbear keys stay in nvram; revisit if a
  box migrates.
- **Debian layer (chroots + real hosts):** full `nslcd` (nss-ldapd +
  pam-ldapd) — this is where LDAP actually lives, and it's everywhere
  we already run Debian.

## Home directories

**No shared/NFS homes.** Each host materializes a home on first login
(`pam_mkhomedir`); per-box homes live on that box's own storage
(chroot USB, local disk).

Rationale:

1. NFS homes make login depend on the NFS server being up — a worse
   dependency chain than LDAP itself (identity fails *and* the login
   environment fails together).
2. This fleet is admin-oriented, not multi-user workstations: real user
   data lives on laptops (already backed up to aio-01 nightly) and on
   nas-01 media. A shared `/home` would mostly hold dotfiles.
3. Dotfile drift is better solved by the existing repos (Bin/Config are
   already in git) than by a network mount.

If a shared scratch area is ever wanted, that is an automount/NFS export
decision (nas-01/aio-01), independent of LDAP — do not couple it to
identity.
