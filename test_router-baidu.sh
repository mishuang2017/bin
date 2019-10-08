#!/bin/bash

set -x

PF=enp4s0f0
REMOTE_PF=enp4s0f0
VF=enp4s0f3
VF2=enp4s0f4
REP=enp4s0f0_1
REP2=enp4s0f0_2

PATCH_EX=patch-ex
PATCH_INT=patch-int
BR_INT=br-int
BR_EX=br-ex

VF_MAC=$(ip netns exec n11 cat /sys/class/net/$VF/address)
VF2_MAC=$(ip netns exec n12 cat /sys/class/net/$VF2/address)
VM_IP=192.168.0.2
VM_ROUTE_IP=192.168.0.1
VM_ROUTE_IP_HEX=0xc0a80001

if [[ $(hostname -s) == "dev-r630-03" ]]; then
	MAC_REMOTE_PF=24:8a:07:88:27:ca
	REMOTE_HOST=10.112.205.14
elif [[ $(hostname -s) == "dev-r630-04" ]]; then
	MAC_REMOTE_PF=24:8a:07:88:27:9a
	REMOTE_HOST=10.112.205.13
fi
REMOTE_PF_IP=8.9.10.11
ifconfig $PF 0
ssh $REMOTE_HOST ifconfig $REMOTE_PF $REMOTE_PF_IP/24 up

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

BR_EX_IP=8.9.10.1

function create-br
{
set -x
	del-br
	ovs-vsctl add-br $BR_INT
	ovs-vsctl add-br $BR_EX

	ovs-vsctl add-port $BR_INT vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=$REMOTE_PF_IP options:key=100 options:dst_port=4789
	ovs-vsctl add-port $BR_INT $REP
	ovs-vsctl add-port $BR_INT $REP2
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

ip netns exec n12 ifconfig $VF2 8.9.10.100/24 up

ip netns exec n11 ifconfig $VF $VM_IP/24 up
ip netns exec n11 ip route delete default
ip netns exec n11 ip route add default via $VM_ROUTE_IP dev $VF

# arp responder
ovs-ofctl add-flow $BR_INT "table=0, in_port=$REP, dl_type=0x0806, nw_dst=$VM_ROUTE_IP, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src=${ROUTE_MAC}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:$ROUTE_MAC_HEX->NXM_NX_ARP_SHA[], load:$VM_ROUTE_IP_HEX->NXM_OF_ARP_SPA[], in_port"
ovs-ofctl add-flow $BR_INT "table=0, in_port=$PATCH_INT, dl_type=0x0806, nw_dst=$ROUTE_IP, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:${ROUTE_MAC}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:$ROUTE_MAC_HEX->NXM_NX_ARP_SHA[], load:$ROUTE_IP_HEX->NXM_OF_ARP_SPA[], in_port"

# ping virtual route
ovs-ofctl add-flow $BR_INT table=0,in_port=$REP,icmp,nw_dst=$VM_ROUTE_IP,icmp_type=8,icmp_code=0,actions=push:"NXM_OF_ETH_SRC[]",push:"NXM_OF_ETH_DST[]",pop:"NXM_OF_ETH_SRC[]",pop:"NXM_OF_ETH_DST[]",push:"NXM_OF_IP_SRC[]",push:"NXM_OF_IP_DST[]",pop:"NXM_OF_IP_SRC[]",pop:"NXM_OF_IP_DST[]",load:"0xff->NXM_NX_IP_TTL[]",load:"0->NXM_OF_ICMP_TYPE[]",in_port
ovs-ofctl add-flow $BR_INT table=0,in_port=$PATCH_INT,icmp,nw_dst=$ROUTE_IP,icmp_type=8,icmp_code=0,actions=push:"NXM_OF_ETH_SRC[]",push:"NXM_OF_ETH_DST[]",pop:"NXM_OF_ETH_SRC[]",pop:"NXM_OF_ETH_DST[]",push:"NXM_OF_IP_SRC[]",push:"NXM_OF_IP_DST[]",pop:"NXM_OF_IP_SRC[]",pop:"NXM_OF_IP_DST[]",load:"0xff->NXM_NX_IP_TTL[]",load:"0->NXM_OF_ICMP_TYPE[]",in_port

# SNAT request
ovs-ofctl add-flow $BR_INT "table=0,priority=101,in_port=$REP,arp actions=NORMAL"
ovs-ofctl add-flow $BR_INT "table=0,priority=100,in_port=$REP actions=load:0x6757->NXM_NX_REG6[],load:0x7->OXM_OF_METADATA[],load:0->OXM_OF_IN_PORT[],resubmit(,5)"
ovs-ofctl add-flow $BR_INT "table=5,priority=200,ip,reg6=0x6757,dl_src=$VF_MAC,nw_src=$VM_IP actions=resubmit(,10)"
ovs-ofctl add-flow $BR_INT "table=10,priority=100,ip,reg6=0x6757 actions=ct(table=15,zone=OXM_OF_METADATA[0..15])"
ovs-ofctl add-flow $BR_INT "table=15,priority=22,ct_state=+new-est-rel-rpl-inv+trk,ip actions=ct(commit,table=17,zone=NXM_NX_CT_ZONE[])"
ovs-ofctl add-flow $BR_INT "table=15,priority=65534,ct_state=-new+est-rel+rpl-inv+trk actions=resubmit(,17)"
ovs-ofctl add-flow $BR_INT "table=15,priority=22,ct_state=-new+est-rel-rpl-inv+trk,ip actions=resubmit(,17)"
ovs-ofctl add-flow $BR_INT "table=17,priority=1 actions=resubmit(,20)"
ovs-ofctl add-flow $BR_INT "table=20,priority=1 actions=resubmit(,55)"
ovs-ofctl add-flow $BR_INT "table=55,priority=200,metadata=0x7,dl_dst=$ROUTE_MAC actions=load:0x1b->NXM_NX_REG5[],resubmit(,60)"
ovs-ofctl add-flow $BR_INT "table=60,priority=50,ip actions=resubmit(,61)"
ovs-ofctl add-flow $BR_INT "table=61,priority=50,ip,reg5=0x1b actions=resubmit(,70)"
ovs-ofctl add-flow $BR_INT "table=70,priority=50,ip actions=move:NXM_OF_IP_SRC[]->NXM_NX_REG5[],move:NXM_NX_REG6[]->NXM_OF_IP_SRC[],load:0x1->NXM_OF_IP_SRC[31],ct(commit,table=71,zone=65534,nat(src=$ROUTE_IP),exec(move:NXM_NX_REG6[]->NXM_NX_CT_MARK[],move:NXM_NX_REG5[]->NXM_NX_CT_LABEL[0..31]))"
ovs-ofctl add-flow $BR_INT "table=71,priority=50,ip actions=mod_dl_src:$ROUTE_MAC,mod_dl_dst:$MAC_BR_EX,output:$PATCH_INT"

# vxlan
ovs-ofctl add-flow $BR_INT "table=0,priority=101,ct_state=-trk,in_port=$REP,ip,nw_dst=192.168.0.200 actions=ct(table=1)"
ovs-ofctl add-flow $BR_INT "table=1,priority=10,ct_state=+trk+new,ip actions=ct(commit),normal"
ovs-ofctl add-flow $BR_INT "table=1,priority=10,ct_state=+trk+est,ip actions=normal"
ovs-ofctl add-flow $BR_INT "table=1,priority=1, actions=normal"

# SNAT reply
ovs-ofctl add-flow $BR_INT "table=0,priority=20,in_port=$PATCH_INT actions=load:0->OXM_OF_IN_PORT[],resubmit(,50)"
ovs-ofctl add-flow $BR_INT "table=50,priority=50,ip actions=ct(table=51,zone=65534,nat)"
ovs-ofctl add-flow $BR_INT "table=51,priority=50,ct_mark=0x6757,ip actions=mod_dl_src:$ROUTE_MAC,mod_dl_dst:$VF_MAC,load:0x6757->NXM_NX_REG7[],move:NXM_NX_CT_LABEL[0..31]->NXM_OF_IP_DST[],load:0x7->OXM_OF_METADATA[],resubmit(,100)"
ovs-ofctl add-flow $BR_INT "table=100,priority=200,metadata=0x7,dl_dst=$VF_MAC actions=load:0x6757->NXM_NX_REG7[],resubmit(,105)"
ovs-ofctl add-flow $BR_INT "table=105,priority=100,ip,reg7=0x6757 actions=ct(table=110,zone=OXM_OF_METADATA[0..15])"
ovs-ofctl add-flow $BR_INT "table=110,priority=22,ct_state=+new-est-rel-rpl-inv+trk,ip actions=ct(commit,table=115,zone=NXM_NX_CT_ZONE[])"
ovs-ofctl add-flow $BR_INT "table=110,priority=22,ct_state=-new+est-rel+rpl-inv+trk,ip actions=resubmit(,115)"
ovs-ofctl add-flow $BR_INT "table=110,priority=22,ct_state=-new+est-rel-rpl-inv+trk,ip actions=resubmit(,115)"
ovs-ofctl add-flow $BR_INT "table=115,priority=100,reg7=0x6757 actions=output:$REP"

# vxlan
ovs-ofctl add-flow $BR_INT "table=0,priority=30,in_port=vxlan0,ip actions=ct(table=1)"
ovs-ofctl add-flow $BR_INT "table=1,priority=10,ct_state=+trk+new,ip actions=ct(commit),normal"
ovs-ofctl add-flow $BR_INT "table=1,priority=10,ct_state=+trk+est,ip actions=normal"
ovs-ofctl add-flow $BR_INT "table=1,priority=1, actions=normal"

ovs-ofctl add-flow $BR_EX "table=0,priority=50,in_port=$PATCH_EX,ip,nw_dst=$REMOTE_PF_IP,dl_dst=$MAC_BR_EX actions=mod_dl_dst:$MAC_REMOTE_PF,output:NORMAL"

# none vxlan for vm2
ovs-ofctl add-flow $BR_INT "table=0,priority=200,in_port=$REP2 actions=output:$PATCH_INT"
ovs-ofctl add-flow $BR_EX "table=0,in_port=$PF,dl_dst=$VF2_MAC actions=output:$PATCH_EX"
ovs-ofctl add-flow $BR_INT "table=0,priority=100,dl_dst=$VF2_MAC actions=output:$REP2"

set +x
