# gateway-ap — Netgear RAX-75 (stock firmware)

192.168.1.1. The internet gateway and the radio everything else depends on:
it broadcasts `FlossWare-5.0-ghz` (5 GHz), which every `-ap` bridge in the
fleet associates to — util-ap in wet (client bridge) mode, server-ap and
desktop-ap via relayd.

Runs **stock Netgear firmware** (latest), not DD-WRT — deliberately. There is
nothing deployable here: SSH is closed, management is web-UI only. This
directory exists so the topology is complete and the hardware record is
authoritative (it was previously mis-recorded as a WRT3200ACM).

Same model as the cabin gateway.
