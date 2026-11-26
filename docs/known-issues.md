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
