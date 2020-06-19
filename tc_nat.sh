#! /bin/bash
set -x

if [[ $(hostname -s) == "dev-r630-03" ]]; then
	gateway_mac="b8:59:9f:bb:31:82"
	host_num=13
fi

if [[ $(hostname -s) == "dev-r630-04" ]]; then
	gateway_mac="b8:59:9f:bb:31:66"
	host_num=14
fi

host_outdev=enp4s0f0np0
enable_skip_hw=0

if [ $enable_skip_hw -eq 1 ] 
then
	SKIP_HW='skip_hw'
else
	SKIP_HW=''
fi;

echo "$SKIP_HW"

function get_local_port_range()
{
	sysctl -a 2>/dev/null | grep "net.ipv4.ip_local_port_range" | cut -d'=' -f 2 | awk '{printf("%d-%d",$1,$2);}'
}
port_range=`get_local_port_range`;
#port_range="1024-7900"

function get_host_ip()
{
	ip addr show dev enp4s0f0np0 | grep "inet " | awk '{print $2}' | cut -d'/' -f 1
}
host_ip=`get_host_ip`;

function get_host_mac()
{
	ip addr show dev enp4s0f0np0 | grep "link/ether" | awk '{print $2}'
}
host_mac=`get_host_mac`


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

	for proto in icmp tcp; do
		tc filter add dev $if_name ingress prio 1 chain 0 proto ip flower $SKIP_HW ip_flags nofrag ip_proto $proto action ct pipe action goto chain 2 ;
		tc filter add dev $if_name ingress prio 1 chain 2 proto ip flower $SKIP_HW ip_flags nofrag ip_proto $proto ct_state +trk+new action ct commit nat src addr $host_ip port $port_range pipe action goto chain 99;
		tc filter add dev $if_name ingress prio 1 chain 2 proto ip flower $SKIP_HW ip_flags nofrag ip_proto $proto ct_state +trk+est action ct nat pipe action goto chain 99;
		tc filter add dev $if_name ingress prio 1 chain 99 proto ip flower $SKIP_HW ip_flags nofrag action pedit ex munge eth dst set $gateway_mac munge eth src set $host_mac pipe action mirred egress redirect dev $host_outdev
	done
}

function add_container_egress_common_rules()
{
	for proto in icmp tcp; do
		tc filter add dev $host_outdev ingress prio 1 chain 0 proto ip flower $SKIP_HW ip_flags nofrag ip_proto $proto action ct pipe action goto chain 3 ;
		tc filter add dev $host_outdev ingress prio 1 chain 3 proto ip flower $SKIP_HW ip_flags nofrag ip_proto $proto ct_state +trk+est action ct nat  pipe goto chain 4;
	done
}
function add_container_egress_rules()
{
	if_name="$1"
	if_addr="$2"
	if_mac="$3"
	tc filter add dev $host_outdev ingress prio 1 chain 4 proto ip flower $SKIP_HW ip_flags nofrag dst_ip $if_addr action pedit ex munge eth dst set $if_mac pipe action mirred egress redirect dev $if_name
}

function main()
{
	delete_ingress_qdisc "$host_outdev"
	add_ingress_qdisc "$host_outdev"
	add_container_egress_common_rules

	for((i=1;i<2;++i));
	do
		byte=`printf "%02x" $((i+1))`
		add_container_ingress_rules enp4s0f0np0_$i
		add_container_egress_rules "enp4s0f0np0_$i" "192.168.1.1$i" "02:25:d0:$host_num:01:$byte"
	done;
}


ns=n11
vf=$(ip netns exec $ns ls /sys/class/net | grep en)
VF_MAC=$(ip netns exec $ns cat /sys/class/net/$vf/address)
echo $VF_MAC
ip netns exec $ns ifconfig $vf 192.168.1.11/24 up
ip netns exec $ns ip route add 8.9.10.0/24 via 192.168.1.254 dev $vf
ip netns exec $ns arp -s 192.168.1.254 $gateway_mac

ifconfig $host_outdev 8.9.10.1/24 up
sleep 1

main
set +x
