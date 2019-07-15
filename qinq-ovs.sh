#!/bin/bash

NS1=n11
NS2=n12

BR1=br1
BR2=br2

VF1=enp4s0f2
VF2=enp4s0f3

REP1=enp4s0f0_0
REP2=enp4s0f0_1

VETH1=veth1
VETH2=veth2

CVID=5
SVID=1000

function create-ns-vlan
{
	local link=$1 vid=$2 ip=$3 vlan=vlan$2 ns=$4

	ip netns exec $ns ip link set $link up
	ip netns exec $ns ip link add link $link name $vlan type vlan id $2
	ip netns exec $ns ip link set dev $vlan up
	ip netns exec $ns ip addr add $ip/24 dev $vlan
}

modprobe 8021q

ip netns del $NS1 &> /dev/null
ip netns del $NS2 &> /dev/null
sleep 1

ip netns add $NS1
ip netns add $NS2

ip link set $VF1 netns $NS1
ip link set $VF2 netns $NS2
sleep 1

ovs-vsctl list-br | xargs -r -l ovs-vsctl del-br
sleep 1
# by default vlan-limit is 1, pop action will not be offloaded
ovs-vsctl set Open_vSwitch . other_config:vlan-limit=2
service openvswitch restart

ip link del $VETH1 &> /dev/null
ip link del $VETH2 &> /dev/null
ip link add $VETH1 type veth peer name $VETH2
ifconfig $VETH1 0 up
ifconfig $VETH2 0 up

create-ns-vlan $VF1 $CVID 1.1.1.1 $NS1
create-ns-vlan $VF2 $CVID 1.1.1.2 $NS2

# by default, it is access port, packet will be dropped
tag="tag=$SVID vlan-mode=dot1q-tunnel"

ovs-vsctl add-br $BR1
ovs-vsctl add-br $BR2
ovs-vsctl add-port $BR1 $VETH1
ovs-vsctl add-port $BR1 $REP1 $tag

ovs-vsctl add-port $BR2 $VETH2
ovs-vsctl add-port $BR2 $REP2 $tag

ip netns exec $NS1 ping 1.1.1.2 -c 5 

ip netns del $NS1 &> /dev/null
ip netns del $NS2 &> /dev/null
ip link del $VETH1 &> /dev/null
ip link del $VETH2 &> /dev/null

ovs-vsctl list-br | xargs -r -l ovs-vsctl del-br
