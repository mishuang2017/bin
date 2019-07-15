#!/bin/bash

set -x

ip link del host1 &> /dev/null
ip link del host2 &> /dev/null
ip link del host3 &> /dev/null
ip link del host1_rep &> /dev/null
ip link del host2_rep  &> /dev/null
ip link del host3_rep  &> /dev/null
ip netns del host1_ns &> /dev/null
ip netns del host2_ns &> /dev/null
ip netns del host3_ns &> /dev/null

ip netns add host1_ns
ip netns add host2_ns
ip netns add host3_ns

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

ip link add host3 type veth peer name host3_rep
ip link set host3 netns host3_ns
ip netns exec host3_ns ifconfig host3 up
ifconfig host3_rep 0 up

ovs-vsctl add-br OVSbr1
ovs-vsctl add-port OVSbr1 host1_rep -- set Interface host1_rep ofport_request=2
ovs-vsctl add-port OVSbr1 host2_rep -- set Interface host2_rep ofport_request=3

MAC1=`ip netns exec host1_ns cat /sys/class/net/host1/address`
MAC2=`ip netns exec host2_ns cat /sys/class/net/host2/address`

# MAC1=24:8a:07:ad:77:01
# MAC2=24:8a:07:ad:77:02

ovs-ofctl add-flow OVSbr1 "table=0, in_port=2, dl_type=0x0806, nw_dst=192.168.0.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:24:8a:07:ad:77:99, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0xc0a80001->NXM_OF_ARP_SPA[], in_port"
ovs-ofctl add-flow OVSbr1 "table=0, in_port=2, dl_dst=24:8a:07:ad:77:99, ip, nw_src=192.168.0.2, nw_dst=8.9.10.11, icmp, actions=mod_dl_src=24:8a:07:ad:77:99, mod_dl_dst=${MAC2}, mod_nw_src=8.9.10.1, output:3"

ovs-ofctl add-flow OVSbr1 "table=0, in_port=3, dl_type=0x0806, nw_dst=8.9.10.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:24:8a:07:ad:77:99, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0x08090a01->NXM_OF_ARP_SPA[], in_port"
ovs-ofctl add-flow OVSbr1 "table=0, in_port=3, dl_dst=24:8a:07:ad:77:99, dl_type=0x0800, nw_dst=8.9.10.1, actions=mod_dl_src=01:23:45:67:89:ab, mod_dl_dst=${MAC1}, mod_nw_dst=192.168.0.2, output:2"

ovs-vsctl add-port OVSbr1 host3_rep    \
    -- --id=@p get port host3_rep   \
    -- --id=@m create mirror name=m0 select-all=true output-port=@p \
    -- set bridge OVSbr1 mirrors=@m

set +x
