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

MAC_ROUTE="24:8a:07:ad:77:99"
VM_IP=192.168.0.2
PF=enp4s0f0
REP=enp4s0f0_1

# arp responder

ovs-ofctl add-flow $br "table=0, in_port=$REP, dl_type=0x0806, nw_dst=192.168.0.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src=${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0xc0a80001->NXM_OF_ARP_SPA[], in_port"
ovs-ofctl add-flow $br "table=0, in_port=$PF, dl_type=0x0806, nw_dst=8.9.10.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0x08090a01->NXM_OF_ARP_SPA[], in_port"

# reply

ovs-ofctl add-flow $br "table=0,priority=20,in_port=$PF actions=load:0->OXM_OF_IN_PORT[],resubmit(,50)"
ovs-ofctl add-flow $br "table=50,priority=50,ip actions=ct(table=51,zone=65534,nat)"
ovs-ofctl add-flow $br "table=51,priority=50,ct_mark=0x6757,ip actions=mod_dl_src:$MAC_ROUTE,mod_dl_dst:$MAC1,load:0x6757->NXM_NX_REG7[],move:NXM_NX_CT_LABEL[0..31]->NXM_OF_IP_DST[],load:0x7->OXM_OF_METADATA[],resubmit(,100)"
ovs-ofctl add-flow $br "table=100,priority=200,metadata=0x7,dl_dst=$MAC1 actions=load:0x6757->NXM_NX_REG7[],resubmit(,105)"
ovs-ofctl add-flow $br "table=105,priority=100,ip,reg7=0x6757 actions=ct(table=110,zone=OXM_OF_METADATA[0..15])"

ovs-ofctl add-flow $br "table=110,priority=22,ct_state=+new-est-rel-rpl-inv+trk,ip actions=ct(commit,table=115,zone=NXM_NX_CT_ZONE[])"
ovs-ofctl add-flow $br "table=110,priority=22,ct_state=-new+est-rel+rpl-inv+trk,ip actions=resubmit(,115)"
ovs-ofctl add-flow $br "table=110,priority=22,ct_state=-new+est-rel-rpl-inv+trk,ip actions=resubmit(,115)"

ovs-ofctl add-flow $br "table=115,priority=100,reg7=0x6757 actions=output:$REP"
 
# request

# recirc_id(0),in_port(enp4s0f0_1),eth(src=02:25:d0:13:01:02),eth_type(0x0800),ipv4(src=192.168.0.2,frag=no), packets:1, bytes:84, used:0.670s, actions:ct(zone=7),recirc(0x1)
ovs-ofctl add-flow $br "table=0,priority=100,in_port=$REP actions=load:0x6757->NXM_NX_REG6[],load:0x7->OXM_OF_METADATA[],load:0->OXM_OF_IN_PORT[],resubmit(,5)"
ovs-ofctl add-flow $br "table=5,priority=200,ip,reg6=0x6757,dl_src=$MAC1,nw_src=192.168.0.2 actions=resubmit(,10)"
ovs-ofctl add-flow $br "table=10,priority=100,ip,reg6=0x6757 actions=ct(table=15,zone=OXM_OF_METADATA[0..15])"


# recirc_id(0x1),in_port(enp4s0f0_1),ct_state(+new-est-rel-rpl-inv+trk),eth_type(0x0800),ipv4(frag=no), packets:0, bytes:0, used:1.670s, actions:ct(commit,zone=7),recirc(0x2)
ovs-ofctl add-flow $br "table=15,priority=22,ct_state=+new-est-rel-rpl-inv+trk,ip actions=ct(commit,table=17,zone=NXM_NX_CT_ZONE[])"

# recirc_id(0x1),in_port(enp4s0f0_1),ct_state(-new+est-rel-rpl-inv+trk),eth(dst=24:8a:07:ad:77:99),eth_type(0x0800),ipv4(src=192.168.0.2,proto=1,frag=no), packets:0, bytes:0, used:0.670s, actions:set(ipv4(src=128.0.103.87)),ct(commit,zone=65534,mark=0x6757/0xffffffff,label=0xc0a80002/0xffffffff,nat(src=8.9.10.1)),recirc(0x3)
ovs-ofctl add-flow $br "table=15,priority=65534,ct_state=-new+est-rel+rpl-inv+trk actions=resubmit(,17)"
ovs-ofctl add-flow $br "table=15,priority=22,ct_state=-new+est-rel-rpl-inv+trk,ip actions=resubmit(,17)"
ovs-ofctl add-flow $br "table=17,priority=1 actions=resubmit(,20)"
ovs-ofctl add-flow $br "table=20,priority=1 actions=resubmit(,55)"
ovs-ofctl add-flow $br "table=55,priority=200,metadata=0x7,dl_dst=$MAC_ROUTE actions=load:0x1b->NXM_NX_REG5[],resubmit(,60)"
ovs-ofctl add-flow $br "table=60,priority=50,ip actions=resubmit(,61)"
ovs-ofctl add-flow $br "table=61,priority=50,ip,reg5=0x1b actions=resubmit(,70)"


# recirc_id(0x2),in_port(enp4s0f0_1),eth(dst=24:8a:07:ad:77:99),eth_type(0x0800),ipv4(src=192.168.0.2,proto=1,frag=no), packets:0, bytes:0, used:1.670s, actions:set(ipv4(src=128.0.103.87)),ct(commit,zone=65534,mark=0x6757/0xffffffff,label=0xc0a80002/0xffffffff,nat(src=8.9.10.1)),recirc(0x3)
ovs-ofctl add-flow $br "table=70,priority=50,ip actions=move:NXM_OF_IP_SRC[]->NXM_NX_REG5[],move:NXM_NX_REG6[]->NXM_OF_IP_SRC[],load:0x1->NXM_OF_IP_SRC[31],ct(commit,table=71,zone=65534,nat(src=8.9.10.1),exec(move:NXM_NX_REG6[]->NXM_NX_CT_MARK[],move:NXM_NX_REG5[]->NXM_NX_CT_LABEL[0..31]))"


# recirc_id(0x3),in_port(enp4s0f0_1),eth(src=02:25:d0:13:01:02,dst=24:8a:07:ad:77:99),eth_type(0x0800),ipv4(frag=no), packets:0, bytes:0, used:1.670s, actions:set(eth(src=24:8a:07:ad:77:99,dst=24:8a:07:88:27:ca)),enp4s0f0
ovs-ofctl add-flow $br "table=71,priority=50,ip actions=mod_dl_src:$MAC_ROUTE,mod_dl_dst:$MAC2,output:$PF"

# ovs-appctl ofproto/trace br in_port=2,dl_dst=24:8a:07:ad:77:99,dl_src=02:25:d0:13:01:02,ip,nw_src=192.168.0.2,nw_dst=8.9.10.11
# ovs-appctl ofproto/trace br in_port=2,dl_dst=24:8a:07:ad:77:99,dl_src=02:25:d0:13:01:02,ip,nw_src=192.168.0.2,nw_dst=8.9.10.11 --ct-next  trk,est

set +x
