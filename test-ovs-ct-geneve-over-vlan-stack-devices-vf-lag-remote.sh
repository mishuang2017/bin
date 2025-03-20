REMOTE_NIC=enp8s0f0
IP=1.1.1.7
REMOTE=1.1.1.8

LOCAL_TUN=7.7.7.7
REMOTE_IP=7.7.7.8
GENEVE_ID=42
vlan=20
vlandev=${REMOTE_NIC}.$vlan

ip link add link bond0 name $vlandev type vlan id 20
ip link del geneve1 &>/dev/null
ip link add geneve1 type geneve id $GENEVE_ID remote $LOCAL_TUN dstport 6081
ip a flush dev $vlandev
ip a add $REMOTE_IP/24 dev $vlandev
ip a add $REMOTE/24 dev geneve1
ip l set dev geneve1 up
ip l set dev bond0 up
ip l set dev $vlandev up
