#!/bin/bash

set -x
VM1_PORTNAME=$1
VXLAN_PORTNAME=$2
VM1_PORT=$(ovs-vsctl list interface | grep $VM1_PORTNAME -A1 | grep ofport | sed 's/ofport *: \([0-9]*\)/\1/g')
VXLAN_PORT=$(ovs-vsctl list interface | grep $VXLAN_PORTNAME -A1 | grep ofport | sed 's/ofport *: \([0-9]*\)/\1/g')
ZONE=8

br=br

##in namespace, you need to start the ssh as server.
ovs-ofctl del-flows $br
ovs-ofctl add-flow $br -O openflow13 "priority=1000 table=0,arp, actions=NORMAL"
ovs-ofctl add-flow $br -O openflow13 "priority=100 table=0,ip,in_port=$VM1_PORT,action=set_field:$VM1_PORT->reg6,goto_table:5"
# ovs-ofctl add-flow $br -O openflow13 "priority=100 table=0,ip,in_port=$VM1_PORT, action=mod_nw_ttl=20,set_field:$VM1_PORT->reg6,goto_table:5"
ovs-ofctl add-flow $br -O openflow13 "priority=100 table=0,ip,in_port=$VXLAN_PORT, tun_id=0x64, action=set_field:$VXLAN_PORT->reg6,set_field:$VM1_PORT->reg7,goto_table:5"

ovs-ofctl add-flow $br -O openflow13 "table=5, priority=100, ip,actions=ct(table=10,zone=$ZONE)"

ovs-ofctl add-flow $br -O openflow13 "table=10, priority=100,ip,ct_state=-new+est-rel-inv+trk actions=goto_table:15"
ovs-ofctl add-flow $br -O openflow13 "table=10, priority=100,ip,ct_state=-new-est-rel+inv+trk actions=drop"
ovs-ofctl add-flow $br -O openflow13 "table=10, priority=100,ip,ct_state=-new-est-rel-inv-trk actions=drop"
ovs-ofctl add-flow $br -O openflow13 "table=10, priority=100,ip,ct_state=+new-rel-inv+trk actions= ct(commit,table=15,zone=$ZONE)"

ovs-ofctl add-flow $br -O openflow13 "table=15, priority=100,ip,ct_state=+trk actions=goto_table:25"
ovs-ofctl add-flow $br -O openflow13 "table=15, priority=100,ip,ct_state=+trk actions=drop"
ovs-ofctl add-flow $br -O openflow13 "table=15, priority=100,ip,ct_state=-trk actions=drop"
ovs-ofctl add-flow $br -O openflow13 "table=15, priority=100,ip,ct_state=+trk actions=ct(commit,table=25,zone=100)"

ovs-ofctl add-flow $br -O openflow13 "priority=100 table=25,ip, in_port=$VM1_PORT, action=set_field:0x64->tun_id,set_field:$VXLAN_PORT->reg7,goto_table:40"
ovs-ofctl add-flow $br -O openflow13 "priority=100 table=25,ip, in_port=$VXLAN_PORT, actions=goto_table:40"

ovs-ofctl add-flow $br -O openflow13 "table=40, priority=100, ip,action=output:NXM_NX_REG7[0..15]"
ovs-ofctl add-flow $br -O openflow13 "table=200, priority=100,action=drop"

set +x
