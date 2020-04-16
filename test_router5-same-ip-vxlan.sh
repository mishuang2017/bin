#!/bin/bash

set -x

br=br
pf=enp4s0f0
vf=enp4s0f0v1
rep=enp4s0f0_1
vf_ip=1.1.1.1
vxlan=vxlan0

systemctl start openvswitch.service
ovs-vsctl list-br | xargs -r -l ovs-vsctl del-br
ovs-vsctl add-br $br
ovs-vsctl add-port $br $rep
ovs-vsctl add-port $br $vxlan -- set interface $vxlan type=vxlan options:remote_ip=192.168.1.14  options:key=100 options:dst_port=4789

n=n11
ip netns del $n 2>/dev/null
sleep 1
ip netns add $n
ip link set dev $vf netns $n
ip netns exec $n ip link set mtu 1450 dev $vf
ip netns exec $n ip link set dev $vf up
ip netns exec $n ip addr add $vf_ip/16 brd + dev $vf

VF_MAC=$(ip netns exec $n cat /sys/class/net/$vf/address)
[[ $(hostname -s) == "dev-r630-03" ]] && REMOTE_PF_MAC=24:25:d0:e2:00:00

ovs-ofctl add-flow $br "table=0,priority=10,ip,ct_state=-trk,action=ct(nat,table=1)"
ovs-ofctl add-flow $br "table=1,in_port=$rep,ip,ct_state=+trk+new,action=ct(commit,nat(src=$vf_ip)),mod_dl_src:${VF_MAC},mod_dl_dst:${REMOTE_PF_MAC},$vxlan"
ovs-ofctl add-flow $br "table=1,in_port=$rep,ct_state=+trk+est-rpl,ip,action=mod_dl_src:${VF_MAC},mod_dl_dst:${REMOTE_PF_MAC},$vxlan"
ovs-ofctl add-flow $br "table=1,in_port=$vxlan,ct_state=+trk+est+rpl,ip,action=mod_dl_src:${VF_MAC},mod_dl_dst:${VF_MAC},$rep"

set +x
