# Cabin-roaming syslog: the tunnel design

laptop-01 and laptop-02 travel between home (192.168.1.x) and the cabin
(192.168.2.x). Direct syslog forwarding to the aio-01 collector only works at
home, so both laptops forward through a self-healing SSH tunnel instead:

```
rsyslog (tcp, disk-queued) -> 127.0.0.1:6514
    -> ssh -L 6514:aio-01:514 syslog-tunnel
        home:  192.168.1.11 (pi-01, LAN)
        cabin: services.flossware.org:2222 (gateway-ap public forward -> pi-01)
    -> pi-01 opens tcp to aio-01:514
```

- **Location switching** is an ssh-config `Match exec` that checks the default
  route for `192.168.1.` and picks pi-01 directly, else the public forward.
- **Disk queue** (`queue.saveOnShutdown`, infinite retry): logs generated while
  the tunnel is down spool locally and flush on reconnect.
- **Port 6514, not an arbitrary one**: on SELinux-enforcing hosts (Fedora),
  `rsyslogd_t` may only connect to ports labeled `syslogd_port_t` (514, 6514).
  An unlabeled port like 5514 gives "Permission denied" that looks like a
  firewall issue. 6514 is also >1024, so an unprivileged user unit can bind it.
- **laptop-01**: system-level unit (root has the pi-01 key).
  **laptop-02**: user-level unit + `loginctl enable-linger` (operator console;
  runs as the user, uses the user's fleet key).

## Caveat: the home-LAN detection is subnet-based

`grep -qF 192.168.1.` matches any network whose gateway is 192.168.1.x — the
most common consumer-router subnet. On some *other* roaming network that
happens to use it, the tunnel would target pi-01's LAN address and fail
silently (logs spool locally until back somewhere sane). The cabin is
192.168.2.x, so the known roaming case is unaffected. A MAC- or SSID-based
test would be strictly safer if this ever bites.
