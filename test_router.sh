
set -x

ip link del host1 &> /dev/null
ip link del host2 &> /dev/null
ip link del host1_rep &> /dev/null
ip link del host2_rep  &> /dev/null
ip netns del host2_ns &> /dev/null
ip netns del host1_ns &> /dev/null

ip netns add host2_ns
ip netns add host1_ns

ovs-vsctl list-br | xargs -r -l ovs-vsctl del-br
service openvswitch restart
ovs-vsctl list-br | xargs -r -l ovs-vsctl del-br
sleep 2

ip link add host1 type veth peer name host1_rep
ip link set host1 netns host1_ns
ip netns exec host1_ns ifconfig host1 192.168.0.2/24 up
ip netns exec host1_ns ip route add 8.9.10.0/24 via 192.168.0.1 dev host1
ifconfig host1_rep 0 up

ip link add host2 type veth peer name host2_rep
ip link set host2 netns host2_ns
ip netns exec host2_ns ifconfig host2 8.9.10.11/24 up
ifconfig host2_rep 0 up

ovs-vsctl add-br OVSbr1
ovs-vsctl add-port OVSbr1 host1_rep -- set Interface host1_rep ofport_request=2
ovs-vsctl add-port OVSbr1 host2_rep -- set Interface host2_rep ofport_request=3

MAC1=`ip netns exec host1_ns cat /sys/class/net/host1/address`
MAC2=`ip netns exec host2_ns cat /sys/class/net/host2/address`

# MAC1=24:8a:07:ad:77:01
# MAC2=24:8a:07:ad:77:02

#define ARPOP_REQUEST   1               /* ARP request                  */
#define ARPOP_REPLY     2               /* ARP reply                    */

MAC_ROUTE="24:8a:07:ad:77:99"

# SPA: source protocol address
# SHA: source hardware address

# TPA: target protocol address
# THA: target hardware address

ovs-ofctl add-flow OVSbr1 "table=0, in_port=2, dl_type=0x0806, nw_dst=192.168.0.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src=${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0xc0a80001->NXM_OF_ARP_SPA[], in_port"
ovs-ofctl add-flow OVSbr1 "table=0, in_port=2, dl_dst=${MAC_ROUTE}, ip, nw_src=192.168.0.2, nw_dst=8.9.10.11, actions=mod_dl_src=${MAC_ROUTE}, mod_dl_dst=${MAC2}, mod_nw_src=8.9.10.1, output:3"

ovs-ofctl add-flow OVSbr1 "table=0, in_port=3, dl_type=0x0806, nw_dst=8.9.10.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0x08090a01->NXM_OF_ARP_SPA[], in_port"
ovs-ofctl add-flow OVSbr1 "table=0, in_port=3, dl_dst=${MAC_ROUTE}, dl_type=0x0800, nw_dst=8.9.10.1, actions=mod_dl_src=${MAC_ROUTE}, mod_dl_dst=${MAC1}, mod_nw_dst=192.168.0.2, output:2"

set +x
exit

#sudo ovs-ofctl add-flow OVSbr1 'ip,in_port=2 actions=ct(commit,zone=1,nat(src=8.8.8.1)),output:3



sleep 1

ovs-ofctl add-flow OVSbr1 "in_port=2,arp,actions=ct(commit,zone=1,nat(src=8.8.8.1))"
ovs-ofctl add-flow OVSbr1 "in_port=2,ip,actions=ct(commit,zone=1,nat(src=8.8.8.1))"
ovs-ofctl add-flow OVSbr1 "in_port=3,ct_state=-tracked,actions=nat(reverse)"
ovs-ofctl add-flow OVSbr1 "in_port=3,ct_state=+established,actions=nat(reverse)"
ovs-ofctl add-flow OVSbr1 "in_port=3,tcp,ct_state=+new,actions=drop"

exit 
ovs-ofctl add-flow OVSbr1 'ip,in_port=2 actions=ct(commit,zone=1,nat(src=8.8.8.1)),output:3'
ovs-ofctl add-flow OVSbr1 'ip,in_port=3 actions=ct(commit,zone=1,nat(dst=192.168.0.1)),output:2'

exit

## Set Bridge to use OpenFlow 1.3
sh ovs-vsctl set Bridge s1 "protocols=OpenFlow13"

## Create Groups
sh ovs-ofctl add-group -OOpenFlow13 s1 group_id=1,type=all,bucket=output:1
sh ovs-ofctl add-group -OOpenFlow13 s1 group_id=2,type=all,bucket=output:2,4
sh ovs-ofctl add-group -OOpenFlow13 s1 group_id=3,type=all,bucket=output:3

## Table 0 - Classifier
# Send ARP to ARP Responder
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=0, priority=1000, dl_type=0x0806, actions=goto_table=105"
# Send L3 traffic to L3 Rewrite Table
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=0, priority=100, dl_dst=00:00:5E:00:02:01, action=goto_table=5"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=0, priority=100, dl_dst=00:00:5E:00:02:02, action=goto_table=5"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=0, priority=100, dl_dst=00:00:5E:00:02:03, action=goto_table=5"
# Send L3 to L2 Rewrite Table
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=0, priority=0, action=goto_table=20"

## Table 5 - L3 Rewrites
# Exclude connected subnets
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=5, priority=65535, dl_type=0x0800, nw_dst=10.10.10.0/24 actions=goto_table=10"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=5, priority=65535, dl_type=0x0800, nw_dst=10.10.20.0/24 actions=goto_table=10"
# DNAT
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=5, priority=100, dl_type=0x0800,  nw_dst=172.16.1.10 actions=mod_nw_dst=10.10.10.2, goto_table=10"
# SNAT
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=5, priority=100, dl_type=0x0800,  nw_src=10.10.10.2, actions=mod_nw_src=172.16.1.10,  goto_table=10"
# If no rewrite needed, continue to table 10
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=5, priority=0, actions=goto_table=10"

## Table 10 - IPv4 Routing
sh  ovs-ofctl add-flow -OOpenFlow13 s1 "table=10, dl_type=0x0800, nw_dst=10.10.10.0/24, actions=mod_dl_src=00:00:5E:00:02:01, dec_ttl, goto_table=15"
sh  ovs-ofctl add-flow -OOpenFlow13 s1 "table=10, dl_type=0x0800, nw_dst=10.10.20.0/24, actions=mod_dl_src=00:00:5E:00:02:02, dec_ttl, goto_table=15"
sh  ovs-ofctl add-flow -OOpenFlow13 s1 "table=10, dl_type=0x0800, nw_dst=172.16.1.0/24, actions=mod_dl_src=00:00:5E:00:02:03, dec_ttl, goto_table=15"
# Explicit drop if cannot route
sh  ovs-ofctl add-flow -OOpenFlow13 s1 "table=10, priority=0, actions=output:0"

## Table 15 - L3 Forwarding
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=15, dl_type=0x0800, nw_dst=10.10.10.2, actions=mod_dl_dst:00:00:00:00:00:01, goto_table=20"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=15, dl_type=0x0800, nw_dst=10.10.20.2, actions=mod_dl_dst:00:00:00:00:00:02, goto_table=20"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=15, dl_type=0x0800, nw_dst=10.10.20.4, actions=mod_dl_dst:00:00:00:00:00:04, goto_table=20"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=15, dl_type=0x0800, nw_dst=172.16.1.2, actions=mod_dl_dst:00:00:00:00:00:03, goto_table=20"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=15, priority=0, actions=goto_table=20"

## Table 20 - L2 Rewrite
# Go to next table
sh  ovs-ofctl add-flow -OOpenFlow13 s1 "table=20, priority=0, actions=goto_table=25"

## Table 25 - L2 Forwarding
# Use groups for BUM traffic
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=25, in_port=1, dl_dst=01:00:00:00:00:00/01:00:00:00:00:00, actions=group=1"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=25, in_port=2, dl_dst=01:00:00:00:00:00/01:00:00:00:00:00, actions=group=2"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=25, in_port=3, dl_dst=01:00:00:00:00:00/01:00:00:00:00:00, actions=group=3"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=25, in_port=4, dl_dst=01:00:00:00:00:00/01:00:00:00:00:00, actions=group=2"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=25, dl_dst=00:00:00:00:00:01,actions=output=1"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=25, dl_dst=00:00:00:00:00:02,actions=output=2"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=25, dl_dst=00:00:00:00:00:03,actions=output=3"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=25, dl_dst=00:00:00:00:00:04,actions=output=4"

## Table 105 - ARP Responder
# Respond to ARP for Router Addresses
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=105, dl_type=0x0806, nw_dst=10.10.10.1, actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:00:00:5E:00:02:01, load:0x2->NXM_OF_ARP_OP[], move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x00005e000201->NXM_NX_ARP_SHA[], load:0x0a0a0a01->NXM_OF_ARP_SPA[], in_port"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=105,  dl_type=0x0806, nw_dst=10.10.20.1, actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],  mod_dl_src:00:00:5E:00:02:02, load:0x2->NXM_OF_ARP_OP[], move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x00005e000202->NXM_NX_ARP_SHA[], load:0xa0a1401->NXM_OF_ARP_SPA[], in_port"
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=105,  dl_type=0x0806, nw_dst=172.16.1.1, actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],  mod_dl_src:00:00:5E:00:02:03, load:0x2->NXM_OF_ARP_OP[], move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x00005e000203->NXM_NX_ARP_SHA[], load:0xac100101->NXM_OF_ARP_SPA[], in_port"
# Proxy ARP for all floating IPs go below
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=105, dl_type=0x0806, nw_dst=172.16.1.10, actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:00:00:5E:00:02:03, load:0x2->NXM_OF_ARP_OP[], move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x00005e000203->NXM_NX_ARP_SHA[], load:0xac10010a->NXM_OF_ARP_SPA[], in_port"
# if we made it here, the arp packet is to be handled as any other regular L2 packet
sh ovs-ofctl add-flow -OOpenFlow13 s1 "table=105, priority=0, action=resubmit(,20)"





