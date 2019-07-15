#!/bin/bash
VM1_PORTNAME=$1
VM2_PORTNAME=$2
VM1_PORT=$(ovs-vsctl list interface | grep $VM1_PORTNAME -A1 | grep ofport | sed 's/ofport *: \([0-9]*\)/\1/g')
VM2_PORT=$(ovs-vsctl list interface | grep $VM2_PORTNAME -A1 | grep ofport | sed 's/ofport *: \([0-9]*\)/\1/g')

br=br

##in namespace, you need to start the ssh as server.
# ovs-ofctl del-flows $br
ovs-ofctl add-flow $br -O openflow13 "ip, in_port=$VM2_PORT, action=mod_nw_ttl=20,output:$VM1_PORT"
ovs-ofctl add-flow $br -O openflow13 "ip, in_port=$VM1_PORT, action=mod_nw_ttl=40,output:$VM2_PORT"
