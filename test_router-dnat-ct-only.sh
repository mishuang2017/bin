#!/bin/bash

set -x

PATCH_EX=patch-ex
PATCH_INT=patch-int
BR_INT=br-int
BR_EX=br-ex

VM_IP=192.168.0.2
VM_ROUTE_IP=192.168.0.1
VM_ROUTE_IP_HEX=0xc0a80001

if [[ $(hostname -s) == "dev-r630-03" ]]; then

	PF=enp4s0f0
	REMOTE_PF=enp4s0f0
	VF=enp4s0f0v1
	VF2=enp4s0f0v2
	REP=enp4s0f0_1
	REP2=enp4s0f0_2

	MAC_REMOTE_PF=b8:59:9f:bb:31:82
	REMOTE_HOST=10.75.205.14
elif [[ $(hostname -s) == "dev-r630-04" ]]; then

	PF=enp4s0f0
	REMOTE_PF=enp4s0f0
	VF=enp4s0f0v1
	VF2=enp4s0f0v2
	REP=enp4s0f0_1
	REP2=enp4s0f0_2

	MAC_REMOTE_PF=b8:59:9f:bb:31:66
	REMOTE_HOST=10.75.205.13
elif [[ $(hostname -s) == "c-237-155-20-023" ]]; then

	PF=enp8s0f0
	REMOTE_PF=enp8s0f0
	VF=enp8s0f3
	VF2=enp8s0f4
	REP=enp8s0f0_1
	REP2=enp8s0f0_2

	MAC_REMOTE_PF=b8:ce:f6:82:d5:5c
	REMOTE_HOST=10.237.155.24
fi
VF_MAC=$(ip netns exec n11 cat /sys/class/net/$VF/address)
VF2_MAC=$(ip netns exec n12 cat /sys/class/net/$VF2/address)
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
ip netns exec n11 ip route add 8.9.10.0/24 via $VM_ROUTE_IP dev $VF

# arp responder
ovs-ofctl add-flow $BR_INT "table=0, in_port=$REP, dl_type=0x0806, nw_dst=$VM_ROUTE_IP, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src=${ROUTE_MAC}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:$ROUTE_MAC_HEX->NXM_NX_ARP_SHA[], load:$VM_ROUTE_IP_HEX->NXM_OF_ARP_SPA[], in_port"
ovs-ofctl add-flow $BR_INT "table=0, in_port=$PATCH_INT, dl_type=0x0806, nw_dst=$ROUTE_IP, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:${ROUTE_MAC}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:$ROUTE_MAC_HEX->NXM_NX_ARP_SHA[], load:$ROUTE_IP_HEX->NXM_OF_ARP_SPA[], in_port"

# DNAT
# within vm, iperf -s, default port 5001
# iperf -c 8.9.10.10 -p 9999

IPERF_PORT=5001
IPERF_PORT=4000
NEW_PORT=9999
# ovs-ofctl add-flow $BR_EX "table=0,priority=100,in_port=$PF,tcp,tp_dst=$NEW_PORT,nw_dst=$ROUTE_IP actions=mod_nw_dst:$VM_IP,mod_tp_dst:$IPERF_PORT,mod_dl_dst=$VF_MAC,$PATCH_EX"
# ovs-ofctl add-flow $BR_INT "table=0,priority=110,tcp,tp_dst=$IPERF_PORT,nw_dst=$VM_IP actions=ct(table=2)"
# ovs-ofctl add-flow $BR_INT "table=2,priority=10,ct_state=+trk+new,ip actions=ct(commit),$REP"
# ovs-ofctl add-flow $BR_INT "table=2,priority=10,ct_state=+trk+est,ip actions=$REP"
# 
# ovs-ofctl add-flow $BR_INT "table=0,priority=110,in_port=$REP,tcp,nw_src=$VM_IP,tp_src=$IPERF_PORT actions=ct(table=3)"
# ovs-ofctl add-flow $BR_INT "table=3,priority=10,ct_state=+trk+new,ip actions=ct(commit),mod_nw_src:$ROUTE_IP,mod_tp_src:$NEW_PORT,mod_dl_dst=$MAC_REMOTE_PF,$PATCH_INT"
# ovs-ofctl add-flow $BR_INT "table=3,priority=10,ct_state=+trk+est,ip actions=mod_nw_src:$ROUTE_IP,mod_tp_src:$NEW_PORT,mod_dl_dst=$MAC_REMOTE_PF,$PATCH_INT"
# ovs-ofctl add-flow $BR_EX "table=0,priority=110,tcp,nw_src=$ROUTE_IP,tp_src=$NEW_PORT actions=output:$PF"


# doesn't work
# ovs-ofctl add-flow $BR_EX  "table=0,priority=100,in_port=$PF,tcp,tp_dst=$NEW_PORT,nw_dst=$ROUTE_IP actions=mod_nw_dst:$VM_IP,dec_ttl,ct(commit),mod_tp_dst:$IPERF_PORT,mod_dl_dst=$VF_MAC,dec_ttl,$PATCH_EX"

# doesn't work
ovs-ofctl add-flow $BR_EX  "table=0,priority=100,in_port=$PF,tcp,tp_dst=$NEW_PORT,nw_dst=$ROUTE_IP actions=dec_ttl,mod_nw_dst:$VM_IP,ct(commit),mod_tp_dst:$IPERF_PORT,mod_dl_dst=$VF_MAC,dec_ttl,$PATCH_EX"

# 2021-12-16T03:03:13.528Z|00001|netdev_offload_tc(handler42)|ERR|netdev_tc_flow_put: 0: OVS_ACTION_ATTR_SET_MASKED
# 2021-12-16T03:03:13.528Z|00002|netdev_offload_tc(handler42)|ERR|parse_put_flow_set_masked_action: type: 4, size: 12
# 2021-12-16T03:03:13.528Z|00003|netdev_offload_tc(handler42)|ERR|netdev_tc_flow_put: 1: OVS_ACTION_ATTR_CT
# 2021-12-16T03:03:13.528Z|00004|netdev_offload_tc(handler42)|ERR|netdev_tc_flow_put: 2: OVS_ACTION_ATTR_SET_MASKED
# 2021-12-16T03:03:13.528Z|00005|netdev_offload_tc(handler42)|ERR|parse_put_flow_set_masked_action: type: 7, size: 12
# 2021-12-16T03:03:13.528Z|00006|netdev_offload_tc(handler42)|ERR|netdev_tc_flow_put: 2: OVS_ACTION_ATTR_SET_MASKED
# 2021-12-16T03:03:13.528Z|00007|netdev_offload_tc(handler42)|ERR|parse_put_flow_set_masked_action: type: 9, size: 4
# 2021-12-16T03:03:13.528Z|00008|netdev_offload_tc(handler42)|ERR|netdev_tc_flow_put: 2: OVS_ACTION_ATTR_OUTPUT
# works
# ovs-ofctl add-flow $BR_EX  "table=0,priority=100,in_port=$PF,tcp,tp_dst=$NEW_PORT,nw_dst=$ROUTE_IP actions=mod_dl_dst=$VF_MAC,ct(commit),mod_tp_dst:$IPERF_PORT,mod_nw_dst:$VM_IP,dec_ttl,$PATCH_EX"

# 2021-12-16T03:04:14.034Z|00001|netdev_offload_tc(handler80)|ERR|netdev_tc_flow_put: 0: OVS_ACTION_ATTR_SET_MASKED
# 2021-12-16T03:04:14.034Z|00002|netdev_offload_tc(handler80)|ERR|parse_put_flow_set_masked_action: type: 7, size: 12
# 2021-12-16T03:04:14.034Z|00003|netdev_offload_tc(handler80)|ERR|netdev_tc_flow_put: 1: OVS_ACTION_ATTR_CT
# 2021-12-16T03:04:14.034Z|00004|netdev_offload_tc(handler80)|ERR|netdev_tc_flow_put: 2: OVS_ACTION_ATTR_SET_MASKED
# 2021-12-16T03:04:14.034Z|00005|netdev_offload_tc(handler80)|ERR|parse_put_flow_set_masked_action: type: 4, size: 12
# 2021-12-16T03:04:14.034Z|00006|netdev_offload_tc(handler80)|ERR|netdev_tc_flow_put: 2: OVS_ACTION_ATTR_SET_MASKED
# 2021-12-16T03:04:14.034Z|00007|netdev_offload_tc(handler80)|ERR|parse_put_flow_set_masked_action: type: 7, size: 12
# 2021-12-16T03:04:14.034Z|00008|netdev_offload_tc(handler80)|ERR|netdev_tc_flow_put: 2: OVS_ACTION_ATTR_SET_MASKED
# 2021-12-16T03:04:14.034Z|00009|netdev_offload_tc(handler80)|ERR|parse_put_flow_set_masked_action: type: 9, size: 4
# 2021-12-16T03:04:14.034Z|00010|netdev_offload_tc(handler80)|ERR|netdev_tc_flow_put: 2: OVS_ACTION_ATTR_OUTPUT
# works, but dec_ttl is not executed
# ovs-ofctl add-flow $BR_EX  "table=0,priority=100,in_port=$PF,tcp,tp_dst=$NEW_PORT,nw_dst=$ROUTE_IP actions=dec_ttl,ct(commit),mod_nw_dst:$VM_IP,mod_tp_dst:$IPERF_PORT,mod_dl_dst=$VF_MAC,$PATCH_EX"

# works
# ovs-ofctl add-flow $BR_EX  "table=0,priority=100,in_port=$PF,tcp,tp_dst=$NEW_PORT,nw_dst=$ROUTE_IP actions=mod_nw_dst:$VM_IP,ct(commit),mod_tp_dst:$IPERF_PORT,mod_dl_dst=$VF_MAC,$PATCH_EX"

ovs-ofctl add-flow $BR_INT  "table=0,priority=10,ip actions=output:$REP"

ovs-ofctl add-flow $BR_INT "table=0,priority=110,in_port=$REP,tcp,nw_src=$VM_IP,tp_src=$IPERF_PORT actions=ct(table=3)"
ovs-ofctl add-flow $BR_INT "table=3,priority=10,ip actions=mod_nw_src:$ROUTE_IP,mod_tp_src:$NEW_PORT,mod_dl_dst=$MAC_REMOTE_PF,$PATCH_INT"
ovs-ofctl add-flow $BR_EX "table=0,priority=110,tcp,nw_src=$ROUTE_IP,tp_src=$NEW_PORT actions=output:$PF"

set +x
