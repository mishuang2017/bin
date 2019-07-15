#!/bin/bash
VM1_PORTNAME=$1
VM2_PORTNAME=$2
VM1_PORT=$(ovs-vsctl list interface | grep $VM1_PORTNAME -A1 | grep ofport | sed 's/ofport *: \([0-9]*\)/\1/g')
VM2_PORT=$(ovs-vsctl list interface | grep $VM2_PORTNAME -A1 | grep ofport | sed 's/ofport *: \([0-9]*\)/\1/g')

br=br

##in namespace, you need to start the ssh as server.
ovs-ofctl del-flows $br
ovs-ofctl add-flow $br -O openflow13 "priority=1000 table=0,arp, actions=NORMAL"
ovs-ofctl add-flow $br -O openflow13 "priority=100 table=0,ip,in_port=$VM1_PORT,action=set_field:$VM1_PORT->reg6,goto_table:5"
ovs-ofctl add-flow $br -O openflow13 "priority=100 table=0,ip,in_port=$VM2_PORT,action=set_field:$VM2_PORT->reg6,goto_table:5"

ovs-ofctl add-flow $br -O openflow13 "table=5, priority=100, ip,actions=ct(table=10,zone=NXM_NX_REG6[0..15])"

ovs-ofctl add-flow $br -O openflow13 "table=10, priority=100,ip,ct_state=-new+est-rel-inv+trk actions= goto_table:15"

ovs-ofctl add-flow $br -O openflow13 "table=10, priority=100,ip,ct_state=+new-rel-inv+trk actions= ct(commit,table=15,zone=NXM_NX_REG6[0..15])"

ovs-ofctl add-flow $br -O openflow13 "priority=100 table=15,ip, in_port=$VM1_PORT, action=set_field:$VM2_PORT->reg7,goto_table:20"
ovs-ofctl add-flow $br -O openflow13 "priority=100 table=15,ip, in_port=$VM2_PORT, action=mod_nw_ttl=20, set_field:$VM1_PORT->reg7,goto_table:20"
# ovs-ofctl add-flow $br -O openflow13 "priority=100 table=15,ip, in_port=$VM2_PORT, actions=mod_nw_src=3.0.0.0, set_field:$VM1_PORT->reg7,goto_table:20"

ovs-ofctl add-flow $br -O openflow13 "priority=100 table=20,ip, action=ct(table=25, zone=NXM_NX_REG7[0..15])"

ovs-ofctl add-flow $br -O openflow13 "priority=100 table=25,ip, ct_state=+new-est-rel-inv+trk actions= ct(commit,table=30, zone=NXM_NX_REG7[0..15])"
ovs-ofctl add-flow $br -O openflow13 "priority=100 table=25,ip, ct_state=-new+est-rel-inv+trk actions= goto_table:30"

ovs-ofctl add-flow $br -O openflow13 "table=30, priority=100, ip,action=output:NXM_NX_REG7[0..15]"
ovs-ofctl add-flow $br -O openflow13 "table=200, priority=100,action=drop"
