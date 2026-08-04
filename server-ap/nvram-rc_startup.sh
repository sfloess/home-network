# server-ap (192.168.1.4)

sleep 10

ifconfig br0 192.168.1.4 netmask 255.255.255.0 up

# Use /32 on wlan0 to avoid duplicate 192.168.1.0/24 subnet route
# which causes intermittent routing failures to br0 devices (pi-01, pi-02)
ip addr flush dev wlan0 2>/dev/null
ip addr add 192.168.1.4/32 dev wlan0
ip route add 192.168.1.1/32 dev wlan0
ip route del default 2>/dev/null
ip route add default via 192.168.1.1 dev wlan0

iw reg set US
