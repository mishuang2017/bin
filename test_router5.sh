#!/bin/bash

set -x

br=br

ovs-ofctl del-flows br

ip netns exec n11 ifconfig enp4s0f3 192.168.0.2/24 up
ip netns exec n11 ip route add 8.9.10.0/24 via 192.168.0.1 dev enp4s0f3

# MAC2=`ip netns exec host2_ns cat /sys/class/net/host2/address`
# MAC1=02:25:d0:13:01:02

MAC1=$(ip netns exec n11 cat /sys/class/net/enp4s0f3/address)
[[ $(hostname -s) == "dev-r630-03" ]] && MAC2=24:8a:07:88:27:ca
[[ $(hostname -s) == "dev-r630-04" ]] && MAC2=24:8a:07:88:27:9a

#define ARPOP_REQUEST   1               /* ARP request                  */
#define ARPOP_REPLY     2               /* ARP reply                    */

MAC_ROUTE="24:8a:07:ad:77:99"

# SPA: source protocol address
# SHA: source hardware address

# TPA: target protocol address
# THA: target hardware address

ovs-ofctl add-flow $br "table=0, in_port=2, dl_type=0x0806, nw_dst=192.168.0.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src=${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0xc0a80001->NXM_OF_ARP_SPA[], in_port"
ovs-ofctl add-flow $br "table=0, in_port=5, dl_type=0x0806, nw_dst=8.9.10.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0x08090a01->NXM_OF_ARP_SPA[], in_port"

ovs-ofctl add-flow $br "table=0,priority=10,ip,ct_state=-trk,action=ct(nat,table=1)"
ovs-ofctl add-flow $br "table=1,in_port=2,ip,ct_state=+trk+new,action=ct(commit,nat(src=8.9.10.1:5000-50000)),mod_dl_src:${MAC_ROUTE},mod_dl_dst:${MAC2},5"

ovs-ofctl add-flow $br "table=1,in_port=2,ct_state=+trk+est-rpl,ip,action=mod_dl_src:${MAC_ROUTE},mod_dl_dst:${MAC2},5"
ovs-ofctl add-flow $br "table=1,in_port=5,ct_state=+trk+est+rpl,ip,action=mod_dl_src:${MAC_ROUTE},mod_dl_dst:${MAC1},2"

set +x
