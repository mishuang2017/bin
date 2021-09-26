#!/bin/bash

set -x

offload=""
[[ "$1" == "hw" ]] && offload="skip_sw"
[[ "$1" == "sw" ]] && offload="skip_hw"

TC=tc
ns=n11
link=enp4s0f0
link2=enp4s0f1
rep2=enp4s0f0_1
vf2=enp4s0f0v1
link_ip=192.168.1.13
link_remote_ip=192.168.1.14
local_vm_mac=$(ip netns exec $ns cat /sys/class/net/$vf2/address)
link2_mac=$(cat /sys/class/net/$link2/address)

vx=vxlan1
vni=4
vxlan_port=4789
vxlan_mac=24:25:d0:e1:00:00
vxlan_ip=1.1.1.200

ifconfig $link 0
ifconfig $link2 0
ifconfig $link $link_ip/16 up
ifconfig $link2 $link_remote_ip/16 up
arp -i $link -s $link_remote_ip $link2_mac
ip netns exe $ns arp -i enp4s0f0v1 -s 1.1.1.200 $vxlan_mac

ip link del $vx > /dev/null 2>&1
ip link add name $vx type vxlan id $vni dev $link remote $link_remote_ip dstport $vxlan_port
ip link set $vx up

$TC qdisc del dev $link ingress > /dev/null 2>&1
$TC qdisc del dev $rep2 ingress > /dev/null 2>&1
$TC qdisc del dev $vx ingress > /dev/null 2>&1

ethtool -K $link hw-tc-offload on
ethtool -K $rep2 hw-tc-offload on

$TC qdisc add dev $link ingress
$TC qdisc add dev $rep2 ingress
$TC qdisc add dev $vx ingress

ip link set $link promisc on
ip link set $rep2 promisc on
ip link set $vx promisc on

$TC filter add dev $rep2 protocol ip  parent ffff: prio 1 flower $offload \
	src_mac $local_vm_mac           \
	dst_mac $vxlan_mac          \
	action tunnel_key set           \
	src_ip $link_ip                 \
	dst_ip $link_remote_ip          \
	dst_port $vxlan_port            \
	id $vni                         \
	action mirred egress redirect dev $vx
$TC filter add dev $rep2 protocol arp parent ffff: prio 2 flower skip_hw    \
	src_mac $local_vm_mac           \
	action tunnel_key set           \
	src_ip $link_ip                 \
	dst_ip $link_remote_ip          \
	dst_port $vxlan_port            \
	id $vni                         \
	action mirred egress redirect dev $vx

$TC filter add dev $vx protocol ip  parent ffff: prio 1 flower $offload \
	src_mac $vxlan_mac          \
	dst_mac $local_vm_mac           \
	enc_src_ip $link_remote_ip      \
	enc_dst_ip $link_ip             \
	enc_dst_port $vxlan_port        \
	enc_key_id $vni                 \
	action tunnel_key unset         \
	action mirred egress redirect dev $rep2
$TC filter add dev $vx protocol arp parent ffff: prio 2 flower skip_hw  \
	src_mac $vxlan_mac          \
	enc_src_ip $link_remote_ip      \
	enc_dst_ip $link_ip             \
	enc_dst_port $vxlan_port        \
	enc_key_id $vni                 \
	action tunnel_key unset         \
	action mirred egress redirect dev $rep2

set +x
