#!/bin/bash

set -x

pf=enp4s0f0
rep=enp4s0f0_1
br=br
vf=enp4s0f0v1
vxlan=vxlan0

# arp responder
use_ar=0

# on ipv6, arping 8.9.10.1 doesn't reply, so don't use AR

if [[ $(hostname -s) == "dev-r630-03" ]]; then
	remote_ip=1::14
	local_ip=1::13
fi
if [[ $(hostname -s) == "dev-r630-04" ]]; then
	remote_ip=1::13
	local_ip=1::14
fi
REMOTE_PF_MAC=24:25:d0:e2:00:00

systemctl start openvswitch.service
ovs-vsctl list-br | xargs -r -l ovs-vsctl del-br
ovs-vsctl add-br $br
ovs-vsctl add-port $br $rep -- set Interface $rep ofport_request=2
ovs-vsctl add-port $br $vxlan -- set interface $vxlan type=vxlan options:remote_ip=$remote_ip options:key=100 options:dst_port=4789

ip addr flush $pf
ip addr add $local_ip/64 dev $pf

vf_ip=192.168.0.2
n=n11
ip netns del $n 2>/dev/null
sleep 1
ip netns add $n
ip link set dev $vf netns $n
ip netns exec $n ip link set mtu 1450 dev $vf
ip netns exec $n ip link set dev $vf up
ip netns exec $n ip addr add dev $vf $vf_ip/24
ip netns exec $n ip route add 8.9.10.0/24 via 192.168.0.1 dev $vf


VF_MAC=$(ip netns exec n11 cat /sys/class/net/$vf/address)
#define ARPOP_REQUEST   1               /* ARP request                  */
#define ARPOP_REPLY     2               /* ARP reply                    */

MAC_ROUTE="24:8a:07:ad:77:99"

# SPA: source protocol address
# SHA: source hardware address

# TPA: target protocol address
# THA: target hardware address

if (( use_ar == 0 )); then
	ifconfig $br 192.168.0.1/24 up
	ifconfig $br:1 8.9.10.1/24 up
else
	ovs-ofctl add-flow $br "table=0, in_port=$rep, dl_type=0x0806, nw_dst=192.168.0.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src=${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0xc0a80001->NXM_OF_ARP_SPA[], in_port"
	ovs-ofctl add-flow $br "table=0, in_port=$vxlan, dl_type=0x0806, nw_dst=8.9.10.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0x08090a01->NXM_OF_ARP_SPA[], in_port"
fi

ovs-ofctl add-flow $br "table=0,priority=10,ip,ct_state=-trk,action=ct(nat,table=1)"
ovs-ofctl add-flow $br "table=1,in_port=$rep,ip,ct_state=+trk+new,action=ct(commit,nat(src=8.9.10.1:5000-50000)),mod_dl_src:${MAC_ROUTE},mod_dl_dst:${REMOTE_PF_MAC},$vxlan"
ovs-ofctl add-flow $br "table=1,in_port=$rep,ct_state=+trk+est-rpl,ip,action=mod_dl_src:${MAC_ROUTE},mod_dl_dst:${REMOTE_PF_MAC},$vxlan"
ovs-ofctl add-flow $br "table=1,in_port=$vxlan,ct_state=+trk+est+rpl,ip,action=mod_dl_src:${MAC_ROUTE},mod_dl_dst:${VF_MAC},$rep"

set +x
