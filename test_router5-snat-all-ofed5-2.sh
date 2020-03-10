#!/bin/bash

set -x

n=3
if [[ $# != 2 ]]; then
	echo "Usage: $0 enp4s0f0 3"
	exit
fi

pf=$1
n=$2

br=br

systemctl start openvswitch.service
ovs-vsctl list-br | xargs -r -l ovs-vsctl del-br
ovs-vsctl add-br $br
ovs-vsctl add-port $br $pf 


[[ $(hostname -s) == "dev-r630-03" ]] && REMOTE_PF_MAC=24:8a:07:88:27:ca
[[ $(hostname -s) == "dev-r630-03" ]] && REMOTE_PF_MAC=b8:59:9f:bb:31:82
[[ $(hostname -s) == "dev-r630-04" ]] && REMOTE_PF_MAC=24:8a:07:88:27:9a
[[ $(hostname -s) == "clx-ibmc-01" ]] && REMOTE_PF_MAC=98:03:9b:13:f4:48
[[ $(hostname -s) == "clx-ibmc-03" ]] && REMOTE_PF_MAC=98:03:9b:13:f4:48

#define ARPOP_REQUEST   1               /* ARP request                  */
#define ARPOP_REPLY     2               /* ARP reply                    */

MAC_ROUTE="24:8a:07:ad:77:99"

# SPA: source protocol address
# SHA: source hardware address

# TPA: target protocol address
# THA: target hardware address

for (( i = 1; i <= $n; i ++ )); do
	rep=${pf}_${i}

# 	vf=${pf}v$i

	reg6=$i
	ovs-vsctl add-port $br $rep
	ns=n1$i
	vf=$(ip netns exec $ns ls /sys/class/net | grep en)
	VF_MAC=$(ip netns exec $ns cat /sys/class/net/$vf/address)
	echo $VF_MAC
	ip netns exec $ns ifconfig $vf 192.168.0.$reg6/24 up
	ip netns exec $ns ip route add 8.9.10.0/24 via 192.168.0.254 dev $vf

	ovs-ofctl add-flow $br "table=0, in_port=$rep, dl_type=0x0806, nw_dst=192.168.0.254, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src=${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0xc0a800fe->NXM_OF_ARP_SPA[], in_port"
	ovs-ofctl add-flow $br "table=0, in_port=$pf, dl_type=0x0806, nw_dst=8.9.10.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0x08090a01->NXM_OF_ARP_SPA[], in_port"

	ovs-ofctl add-flow $br "table=0,in_port=$rep,priority=10,ip,ct_state=-trk,action=load:$reg6->NXM_NX_REG6[],ct(nat,table=10)"
	ovs-ofctl add-flow $br "table=10,in_port=$rep,ip,reg6=$reg6,ct_state=+trk+new,action=ct(commit,nat(src=8.9.10.1:5000-50000),exec(move:NXM_NX_REG6[]->NXM_NX_CT_MARK[])),mod_dl_src:${MAC_ROUTE},mod_dl_dst:${REMOTE_PF_MAC},$pf"
	ovs-ofctl add-flow $br "table=10,in_port=$rep,ct_state=+trk+est-rpl,ip,action=mod_dl_src:${MAC_ROUTE},mod_dl_dst:${REMOTE_PF_MAC},$pf"

	ovs-ofctl add-flow $br "table=0,in_port=$pf,priority=10,ip,ct_state=-trk,action=ct(nat,table=20)"
	ovs-ofctl add-flow $br "table=20,in_port=$pf,ct_mark=$reg6,ct_state=+trk+est+rpl,ip,action=mod_dl_src:${MAC_ROUTE},mod_dl_dst:${VF_MAC},$rep"
done

set +x
