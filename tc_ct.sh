#! /bin/bash
set -x

[[ $# == 1 ]] && n=$1

offload=""
[[ "$1" == "sw" ]] && offload="skip_hw"
[[ "$1" == "hw" ]] && offload="skip_sw"

if [[ $(hostname -s) == "dev-r630-03" ]]; then
	remote_mac="b8:59:9f:bb:31:82"
	host_num=13
	host_outdev=enp4s0f0
	remote_ip=192.168.1.14
fi

if [[ $(hostname -s) == "dev-r630-04" ]]; then
	remote_mac="b8:59:9f:bb:31:66"
	host_num=14
	host_outdev=enp4s0f0np0
	remote_ip=192.168.1.13
fi

function is_need_create_ingress_qdisc()
{
	if_name="$1"
	tc qdisc show dev $if_name | grep -q "ingress"
	return $?
}

function add_ingress_qdisc()
{
	if_name="$1"
	tc qdisc add dev $if_name ingress
}

function delete_ingress_qdisc()
{
	if_name="$1"
	tc qdisc delete dev $if_name ingress
}


function add_container_ingress_rules()
{
	if_name="$1"
	delete_ingress_qdisc "$if_name"
	add_ingress_qdisc "$if_name"

	tc filter add dev $if_name ingress prio 1 chain 0 proto ip flower $offload ip_flags nofrag \
		action ct pipe action goto chain 2 ;
	tc filter add dev $if_name ingress prio 1 chain 2 proto ip flower $offload ip_flags nofrag ct_state +trk+new \
		action ct commit pipe action goto chain 99;
	tc filter add dev $if_name ingress prio 1 chain 2 proto ip flower $offload ip_flags nofrag ct_state +trk+est \
		action goto chain 99;

	tc filter add dev $if_name ingress prio 1 chain 99 proto ip flower $offload ip_flags nofrag \
		action mirred egress redirect dev $host_outdev
}

function add_container_egress_common_rules()
{
	tc filter add dev $host_outdev ingress prio 1 chain 0 proto ip flower $offload ip_flags nofrag \
		action ct pipe action goto chain 3 ;
	tc filter add dev $host_outdev ingress prio 1 chain 3 proto ip flower $offload ip_flags nofrag ct_state +trk+est \
		action ct nat  pipe goto chain 4;
}

function add_container_egress_rules()
{
	if_name="$1"
	if_addr="$2"
	if_mac="$3"
	tc filter add dev $host_outdev ingress prio 1 chain 4 proto ip flower $offload ip_flags nofrag dst_ip $if_addr \
		action mirred egress redirect dev $if_name
}

function main()
{
	n=1

	delete_ingress_qdisc "$host_outdev"
	for((i=1;i<$((n+1));++i)); do
		delete_ingress_qdisc "${host_outdev}_${i}"
	done
	add_ingress_qdisc "$host_outdev"
	add_container_egress_common_rules

	for((i=1;i<$((n+1));++i)); do
		byte=`printf "%02x" $((i+1))`
		rep=enp4s0f0npf0vf$i
		add_container_ingress_rules $rep
		add_container_egress_rules $rep "192.168.1.1$i" "02:25:d0:$host_num:01:$byte"

		ns=n1${i}
		vf=$(ip netns exec $ns ls /sys/class/net | grep en)
		VF_MAC=$(ip netns exec $ns cat /sys/class/net/$vf/address)
		echo $VF_MAC
		ip netns exec $ns ifconfig $vf 192.168.1.1${i}/24 up
		ip netns exec $ns arp -s $remote_ip $remote_mac
	done;
}

main
set +x
