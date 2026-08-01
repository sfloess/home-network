# server-ap (192.168.1.4)

sleep 10

ifconfig br0 192.168.1.4 netmask 255.255.255.0 up
ifconfig wlan0 192.168.1.4 netmask 255.255.255.0 up
ip route del default
ip route add default via 192.168.1.1 dev wlan0

iw reg set US
