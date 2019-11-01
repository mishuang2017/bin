
set -x

link=enp4s0f0
rep=enp4s0f0_1
br=br

ovs-vsctl del-br $br
# ovs-ofctl del-flows $br

ovs-vsctl add-br $br
ovs-vsctl add-port $br $link
ovs-vsctl add-port $br $rep

ip netns exec n11 ifconfig enp4s0f3 192.168.0.2/24 up
ip netns exec n11 ip route add 8.9.10.0/24 via 192.168.0.1 dev enp4s0f3

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

# arp -s 192.168.0.1 24:8a:07:ad:77:99	# on vm

# ifconfig $link 8.9.10.11/24
# arp -s 8.9.10.1 24:8a:07:ad:77:99	# on remote host

ovs-ofctl add-flow $br "table=0, in_port=$rep, dl_type=0x0806, nw_dst=192.168.0.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src=${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0xc0a80001->NXM_OF_ARP_SPA[], in_port"
ovs-ofctl add-flow $br "table=0, in_port=$rep, dl_dst=${MAC_ROUTE}, ip, nw_src=192.168.0.2, nw_dst=8.9.10.11, actions=mod_dl_src=${MAC_ROUTE}, mod_dl_dst=${MAC2}, mod_nw_src=8.9.10.1, output:$link"

ovs-ofctl add-flow $br "table=0, in_port=$link, dl_type=0x0806, nw_dst=8.9.10.1, actions=load:0x2->NXM_OF_ARP_OP[], move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[], mod_dl_src:${MAC_ROUTE}, move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[], move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[], load:0x248a07ad7799->NXM_NX_ARP_SHA[], load:0x08090a01->NXM_OF_ARP_SPA[], in_port"
# src mac is multicast address, doesn't work
# ovs-ofctl add-flow $br "table=0, in_port=$link, dl_dst=${MAC_ROUTE}, dl_type=0x0800, nw_dst=8.9.10.1, actions=mod_dl_src=01:23:45:67:89:ab, mod_dl_dst=${MAC1}, mod_nw_dst=192.168.0.2, output:$rep"
ovs-ofctl add-flow $br "table=0, in_port=$link, dl_dst=${MAC_ROUTE}, dl_type=0x0800, nw_dst=8.9.10.1, actions=mod_dl_src=${MAC_ROUTE}, mod_dl_dst=${MAC1}, mod_nw_dst=192.168.0.2, output:$rep"

set +x
