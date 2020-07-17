brctl addbr br0
brctl addif br0 eno1
ifconfig eno1 0
ifconfig br0 10.75.205.14/24 up
ip route add default via 10.75.205.1
