#!/bin/bash

set -x

pf=enp59s0f0
rep=enp59s0f0_1
br=br
vf=enp59s0f3

systemctl start openvswitch.service
ovs-vsctl list-br | xargs -r -l ovs-vsctl del-br
ovs-vsctl add-br $br
ovs-vsctl add-port $br $pf  -- set Interface $pf  ofport_request=5
ovs-vsctl add-port $br $rep -- set Interface $rep ofport_request=2

ip netns exec n11 ifconfig $vf 192.168.0.2/24 up
ip netns exec n11 ip route add 8.9.10.0/24 via 192.168.0.1 dev $vf

VF_MAC=$(ip netns exec n11 cat /sys/class/net/$vf/address)
# [[ $(hostname -s) == "dev-r630-03" ]] && REMOTE_PF_MAC=24:8a:07:88:27:ca
# [[ $(hostname -s) == "dev-r630-04" ]] && REMOTE_PF_MAC=24:8a:07:88:27:9a
REMOTE_PF_MAC=ec:0d:9a:38:e4:0a

#define ARPOP_REQUEST   1               /* ARP request                  */
#define ARPOP_REPLY     2               /* ARP reply                    */

MAC_ROUTE="24:8a:07:ad:77:99"

# SPA: source protocol address
# SHA: source hardware address

# TPA: target protocol address
# THA: target hardware address

        ovs-ofctl add-flow $br "table=0, in_port=$rep, dl_type=0x0806, nw_dst=192.168.0.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src=${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0xc0a80001->NXM_OF_ARP_SPA[], in_port"
        ovs-ofctl add-flow $br "table=0, in_port=$pf, dl_type=0x0806, nw_dst=8.9.10.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0x08090a01->NXM_OF_ARP_SPA[], in_port"
# fi
 
ovs-ofctl add-flow $br "table=0,priority=10,ip,ct_state=-trk,action=ct(nat,table=1,zone=1)"
ovs-ofctl add-flow $br "table=1,in_port=$rep,ip,ct_state=+trk+new,action=ct(commit,nat(src=8.9.10.1:5000-50000),zone=1),mod_dl_src:${MAC_ROUTE},mod_dl_dst:${REMOTE_PF_MAC},$pf"
ovs-ofctl add-flow $br "table=1,in_port=$rep,ct_state=+trk+est-rpl,ip,action=mod_dl_src:${MAC_ROUTE},mod_dl_dst:${REMOTE_PF_MAC},$pf"
ovs-ofctl add-flow $br "table=1,in_port=$pf,ct_state=+trk+est+rpl,ip,action=mod_dl_src:${MAC_ROUTE},mod_dl_dst:${VF_MAC},$rep"

set +x
