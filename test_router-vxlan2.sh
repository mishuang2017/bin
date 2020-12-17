#!/bin/bash

set -x

PF=enp4s0f0
REMOTE_PF=enp4s0f0
VF=enp4s0f0v1
REP=enp4s0f0_1

PATCH_EX=patch-ex
PATCH_INT=patch-int
BR_INT=br-int
BR_EX=br-ex

if [[ $(hostname -s) == "dev-r630-03" ]]; then
	MAC_REMOTE_PF=b8:59:9f:bb:31:82
	host_num=13
	remote_host_num=14
elif [[ $(hostname -s) == "dev-r630-04" ]]; then
	MAC_REMOTE_PF=b8:59:9f:bb:31:66
	host_num=14
	remote_host_num=13
fi
ifconfig $PF 0

VM_IP=192.168.0.$host_num
VF_MAC=$(ip netns exec n11 cat /sys/class/net/$VF/address)
VM_ROUTE_IP=192.168.0.1
VM_ROUTE_IP_HEX=0xc0a80001

ROUTE_IP=8.9.10.10
ROUTE_IP_HEX=0x08090a0a

ROUTE_MAC="24:8a:07:ad:77:99"
ROUTE_MAC_HEX=$(echo $ROUTE_MAC | sed 's/://g' | sed 's/^/0x/')

set +x

function del-br
{
	ovs-vsctl list-br | xargs -r -l ovs-vsctl del-br
	sleep 1
}

BR_EX_IP=192.168.1.$host_num
REMOTE_PF_IP=192.168.1.$remote_host_num

function create-br
{
set -x
	del-br
	ovs-vsctl add-br $BR_INT
	ovs-vsctl add-br $BR_EX

	ovs-vsctl add-port $BR_INT vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=$REMOTE_PF_IP options:key=100 options:dst_port=4789
	ovs-vsctl add-port $BR_INT $REP
	ovs-vsctl add-port $BR_EX  $PF

	ifconfig $BR_EX $BR_EX_IP/24 up

	ovs-vsctl                           \
		-- add-port $BR_INT $PATCH_INT       \
		-- set interface patch-int type=patch options:peer=$PATCH_EX  \
		-- add-port $BR_EX $PATCH_EX       \
		-- set interface patch-ex type=patch options:peer=$PATCH_INT
set +x
}

create-br

set -x

MAC_BR_EX=$(cat /sys/class/net/$BR_EX/address)

ip netns exec n11 ifconfig $VF $VM_IP/24 up
ip netns exec n11 ip route delete default
ip netns exec n11 ip route add default via $VM_ROUTE_IP dev $VF

# arp responder
ovs-ofctl add-flow $BR_INT "table=0, in_port=$REP, dl_type=0x0806, nw_dst=$VM_ROUTE_IP, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src=${ROUTE_MAC}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:$ROUTE_MAC_HEX->NXM_NX_ARP_SHA[], load:$VM_ROUTE_IP_HEX->NXM_OF_ARP_SPA[], in_port"
ovs-ofctl add-flow $BR_INT "table=0, in_port=$PATCH_INT, dl_type=0x0806, nw_dst=$ROUTE_IP, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:${ROUTE_MAC}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:$ROUTE_MAC_HEX->NXM_NX_ARP_SHA[], load:$ROUTE_IP_HEX->NXM_OF_ARP_SPA[], in_port"

# ping virtual route
ovs-ofctl add-flow $BR_INT table=0,in_port=$REP,icmp,nw_dst=$VM_ROUTE_IP,icmp_type=8,icmp_code=0,actions=push:"NXM_OF_ETH_SRC[]",push:"NXM_OF_ETH_DST[]",pop:"NXM_OF_ETH_SRC[]",pop:"NXM_OF_ETH_DST[]",push:"NXM_OF_IP_SRC[]",push:"NXM_OF_IP_DST[]",pop:"NXM_OF_IP_SRC[]",pop:"NXM_OF_IP_DST[]",load:"0xff->NXM_NX_IP_TTL[]",load:"0->NXM_OF_ICMP_TYPE[]",in_port
ovs-ofctl add-flow $BR_INT table=0,in_port=$PATCH_INT,icmp,nw_dst=$ROUTE_IP,icmp_type=8,icmp_code=0,actions=push:"NXM_OF_ETH_SRC[]",push:"NXM_OF_ETH_DST[]",pop:"NXM_OF_ETH_SRC[]",pop:"NXM_OF_ETH_DST[]",push:"NXM_OF_IP_SRC[]",push:"NXM_OF_IP_DST[]",pop:"NXM_OF_IP_SRC[]",pop:"NXM_OF_IP_DST[]",load:"0xff->NXM_NX_IP_TTL[]",load:"0->NXM_OF_ICMP_TYPE[]",in_port

# request
ovs-ofctl add-flow $BR_INT "table=0,priority=100,in_port=$REP,arp actions=NORMAL"

# vxlan
ovs-ofctl add-flow $BR_INT "table=0,priority=101,ct_state=-trk,in_port=$REP,ip,nw_dst=192.168.0.0/16 actions=ct(table=1)"
ovs-ofctl add-flow $BR_INT "table=1,priority=10,ct_state=+trk+new,ip actions=ct(commit),normal"
ovs-ofctl add-flow $BR_INT "table=1,priority=10,ct_state=+trk+est,ip actions=normal"
ovs-ofctl add-flow $BR_INT "table=1,priority=1, actions=normal"


# vxlan
ovs-ofctl add-flow $BR_INT "table=0,priority=30,in_port=vxlan0,ip actions=ct(table=1)"
ovs-ofctl add-flow $BR_INT "table=1,priority=10,ct_state=+trk+new,ip actions=ct(commit),normal"
ovs-ofctl add-flow $BR_INT "table=1,priority=10,ct_state=+trk+est,ip actions=normal"
ovs-ofctl add-flow $BR_INT "table=1,priority=1, actions=normal"

ovs-ofctl add-flow $BR_EX "table=0,priority=50,in_port=$PATCH_EX,ip,nw_dst=$REMOTE_PF_IP,dl_dst=$MAC_BR_EX actions=mod_dl_dst:$MAC_REMOTE_PF,output:NORMAL"

# We need to differentiate the NAT packet and the management packet
# ovs-ofctl add-flow $BR_EX "table=0,in_port=$PF,ip,dl_src=$MAC_REMOTE_PF,dl_dst=$ROUTE_MAC actions=ct(table=1,zone=65534,nat)"
# ovs-ofctl add-flow $BR_EX "table=1,ct_mark=0 actions=output:$BR_EX"
# ovs-ofctl add-flow $BR_EX "table=1,ct_mark=0x6757 actions=output:$PATCH_EX"

set +x
