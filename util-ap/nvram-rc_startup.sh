# util-ap (192.168.1.3)

#ifconfig br0 192.168.1.3 netmask 255.255.255.0 up
#ifconfig wlan0 192.168.1.3 netmask 255.255.255.0 up
#ip route del default
#ip route add default via 192.168.1.1 dev wlan0
