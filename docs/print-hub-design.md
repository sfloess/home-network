# Print hub design (staged with the admin-ap OpenWrt migration, #36)

## Concept

admin-ap runs CUPS as the **central print hub**: no printer attached to it.
It owns every print queue in the house and routes jobs to wherever the
printers actually live. Clients configure one thing, ever — print to
`print.flossware.com` — and printer/driver changes happen on one box.

```
clients (laptops, phones)
        │  ipp://print.flossware.com:631/printers/<name>
        ▼
   admin-ap CUPS  ── queue management + routing, spool on SSD
        │
        ├──► network printer         (socket:// / ipp:// / lpd:// — direct)
        └──► printer on host X       (ipp://X:631/... — X shares it via its own CUPS)
```

## Why it fits this box

- No USB needed — the SSD keeps the (single) USB port; nothing here uses it.
- CPU is irrelevant — client-side rendering everywhere; admin-ap spools
  and forwards only.
- Spool directory lives on the SSD (never NAND).
- Always on — and jobs for printers on sleeping/absent hosts queue on
  admin-ap and flow when the target reappears (CUPS retries).

## Packages

`cups`, `cups-filters`, `avahi-daemon` (DNS-SD announcement on the LAN).

## Configuration notes

- `print.flossware.com` CNAME in the dnsmasq zone (admin-ap is the zone
  authority — one zone line).
- Avahi/mDNS announcement gives zero-config discovery **on the home LAN
  only**; from the cabin / WireGuard, clients use the explicit
  `ipp://print.flossware.com` address (discovery is convenience,
  addressing is the contract).
- Hosts with attached USB printers run their own CUPS with sharing
  enabled; admin-ap forwards to `ipp://<host>:631/printers/<name>`.
  One-time setup per host, host must be awake for its printer.
- Queue definitions are config files staged in this repo.

## Placement decision

admin-ap over aio-01 is chosen for the always-on-ness + DNS/identity
colocation (the hub is part of the "fleet infrastructure" role). If
server-side rendering is ever needed (it shouldn't be), that job moves
to aio-01, not admin-ap.

## RAM ledger (128 MB total)

| Service | ~RSS |
|---|---|
| dnsmasq + sysntpd + dropbear + msmtpd | ~10 MB |
| slapd (LDAP) | 10–30 MB |
| cupsd + avahi | 30–40 MB |
| **Total steady-state** | **~50–80 MB** |

Fits, with zram + SSD swap as headroom. This is why the next candidate
service must justify itself against this ledger before being added —
see the RAM policy note in the migration runbook.
