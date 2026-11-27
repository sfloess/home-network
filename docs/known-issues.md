# Known issues — field notes

Real failure modes observed on this fleet, documented because they're
underdocumented elsewhere.

## Netgear R9000: squashfs read errors after firmware updates

**Symptom:** after an in-place DD-WRT flash, the internal-NAND squashfs
rootfs starts throwing read errors — web UI 404s, dropbear loses key *and*
password auth, flash attempts can't complete, and eventually daemons accept
TCP but can't fork. The USB SSD and chroot are never affected.

**Fix:** a plain reboot. Fresh reads succeed; everything comes back.

**Recovery when locked out:** SSH to port 22 (the Debian chroot — always
unaffected), then trigger a SysRq reboot since the chroot's own `reboot`
refuses to run in a chroot:

```sh
sync; echo b > /proc/sysrq-trigger
```

Both R9000s failed identically after the same build; clean post-reboot reads
rule out worn flash. Expect recurrence after future flashes until a fixed
build.

## "Wedged" router that isn't: bastion-path client timeouts

**Symptom:** a router stops answering SSH on all ports — TCP handshakes
complete but no SSH banner ever arrives. Looks like fork exhaustion or a
hung box.

**What it actually was (util-ap, 2026-11-24):** the build's firmware
`[watchdog]` timed out the *bastion host's* client entry
(`time is over for client 192.168.1.15, so free it` in syslog). Every
management SSH went through that one bastion (ProxyJump), so the router
*looked* dead while its cron kept forking, NTP kept syncing, and backups ran
on schedule throughout. It self-healed when the watchdog freed the entry.

**Lesson:** before power-cycling a "wedged" router, (1) try a second network
path to it (a direct SSH alias that bypasses the bastion), and (2) grep its
syslog for the watchdog line. "All daemons accept TCP but never respond" +
"cron still runs" = path problem, not box problem.

## Entware scaffolding fails silently when the tree is empty

On server-ap and desktop-ap the entware tree was empty, so the
`startBind` motd/root binds *into* it (`entware/etc/motd`, `entware/root`)
failed at every boot with no visible effect — only the `/opt` bind held,
pointing at nothing. Entware scaffolding was removed from both boxes
2026-11-27 (dd-wrt.sh `.bak-20261127` beside each); the framework's
`dd-wrt.sh` now gates all Entware binds behind `ENABLE_ENTWARE=1`
(default 0, admin-ap opts in). Lesson: binds onto nonexistent subdirs
don't stop the boot — grep the flossware.log for mount errors before
assuming a bind chain is intact.

## Entware init scripts killall by name — chroot shares the PID namespace

`/opt/etc/init.d/S77ntpd stop` on the router side runs `killall ntpd`, which
also kills the Debian chroot's `ntpd` — same process name, same PID
namespace. If you run Entware and chroot daemons with identical names,
stopping one stops both. Either rename one or restart the chroot daemon
afterward.

## Wet-bridge power save: first-packet latency

A 5 GHz wet (client) bridge in power-save mode shows ~400 ms first-packet
latency after idle, settling to 2–7 ms once the link is awake. Not a fault —
but it makes ping probes and health checks misleading. Keep the probe count
above one before judging the link.

## Small-RAM routers and concurrent SSH

A 128 MB router with ~30 MB available can run out of memory when several
SSH sessions land at once (each `sshd-session` costs ~15 MB). Symptom is
failed/frozen sessions while the box otherwise runs fine. Serialize
management connections to the small boxes.

## nas-01: NFS export is rw + no_root_squash to the whole LAN

`/exports 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)` — any LAN
host can write to the array as root. Pre-existing and deliberate for the
trusted home LAN, but note it before ever exposing that segment further.
Combined with the linear (non-redundant) md0, a compromised or misbehaving
host can destroy the array's contents with no snapshot safety net.

## Fleet rsyncd: unauthenticated, root, LAN-writable

All `exports` modules run `uid/gid = root`, `read only = no`, no auth users.
aio-01 and nas-01 now carry `hosts allow = 192.168.1.0/24` (the cabin reaches
them only through SSH tunnels, which originate on pi-01). The remaining fleet
rsyncds and the root login on pi-01's public port-forward are tracked in the
issue tracker.

## Bind mounts protect the mountpoint, not its contents

`rm -rf` on a directory tree containing bind mounts recurses *through* the
bind and deletes the real files at the source. On util-ap this deleted the
shared `root/.ssh` through the `entware/root` bind and locked out SSH on
both ports (2026-11-26). Correct order is always: **umount the binds, then
rm.** Recovery when SSH is dead: the DD-WRT web UI's `apply.cgi` accepts a
`cron_jobs` POST (Referer header required for anti-CSRF) — but crond must
be running, and see the rule below before rebooting to start it.

## Never remotely reboot util-ap without physical access

The st80 box has needed a power cycle after remote reboots repeatedly
(Nov 24 twice; Nov 26 once — offline awaiting physical power cycle as of
this writing). Before any remote reboot of util-ap: confirm someone can
reach the power button, or wire a watchdog/PDU first.

## admin-ap: Debian chroot is impossible on this firmware (PIE vs old kernel)

Empirically closed 2026-11-26: the WNDR3700v4's 3.18.140-d6 MIPS kernel cannot
load PIE (ET_DYN) executables. Debian ≥buster builds its entire mipsel userland
as PIE, so a Debian chroot cannot run — every binary dies with "Exec format
error". Proof: an Entware non-PIE (EXEC-type) binary runs perfectly from inside
the same Debian tree via `chroot`; only PIE binaries fail. This also explains
the abandoned 1 GB `mipsel.tar` bootstrap attempt. Entware works because its
`mipssf-k3.4` feed deliberately targets ancient kernels: non-PIE, soft-float,
o32, bundled glibc. admin-ap stays Entware-only — by physics, not policy.
