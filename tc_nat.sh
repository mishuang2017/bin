#! /bin/bash
set -x

n=1
[[ $# == 1 ]] && n=$1

if [[ $(hostname -s) == "dev-r630-03" ]]; then
	gateway_mac="b8:59:9f:bb:31:82"
	host_num=13
	host_outdev=enp4s0f0
fi

if [[ $(hostname -s) == "dev-r630-04" ]]; then
	gateway_mac="b8:59:9f:bb:31:66"
	host_num=14
	host_outdev=enp4s0f0
fi

# don't forget change host_num
# configure remote pf ip 8.9.10.11/24
if [[ $(hostname -s) == "c-237-115-160-163" ]]; then
	gateway_mac=e8:eb:d3:98:24:ac	# remote pf mac
	host_num=63			# local host_num
	host_outdev=enp8s0f0		# local pf
fi

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

host_mac=$(cat /sys/class/net/$host_outdev/address)


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
	rate=1
	delete_ingress_qdisc "$if_name"
	add_ingress_qdisc "$if_name"

	tc filter add dev $if_name ingress prio 1 chain 0 proto ip flower $SKIP_HW ip_flags nofrag ct_state -trk \
		action sample rate $rate group 5 trunc 60 \
		action ct nat pipe action goto chain 2 ;
	tc filter add dev $if_name ingress prio 1 chain 2 proto ip flower $SKIP_HW ip_flags nofrag ct_state +trk+new \
		action ct commit nat src addr $host_ip port $port_range pipe action goto chain 99;
	tc filter add dev $if_name ingress prio 1 chain 2 proto ip flower $SKIP_HW ip_flags nofrag ct_state +trk+est \
		action ct nat pipe action goto chain 99;

	tc filter add dev $if_name ingress prio 1 chain 99 proto ip flower $SKIP_HW ip_flags nofrag \
		action pedit ex munge eth dst set $gateway_mac munge eth src set $host_mac pipe action mirred egress redirect dev $host_outdev
}

function add_container_egress_common_rules()
{
	rate=1
	tc filter add dev $host_outdev ingress prio 1 chain 0 proto ip flower $SKIP_HW ip_flags nofrag ct_state -trk \
                action sample rate $rate group 6 trunc 60 \
		action ct nat pipe action goto chain 3 ;
	tc filter add dev $host_outdev ingress prio 1 chain 3 proto ip flower $SKIP_HW ip_flags nofrag ct_state +trk+est \
		action ct nat  pipe goto chain 4;
}
function add_container_egress_rules()
{
	if_name="$1"
	if_addr="$2"
	if_mac="$3"
	tc filter add dev $host_outdev ingress prio 1 chain 4 proto ip flower $SKIP_HW ip_flags nofrag dst_ip $if_addr \
		action pedit ex munge eth dst set $if_mac pipe action mirred egress redirect dev $if_name
}

function main()
{
	delete_ingress_qdisc "$host_outdev"
	for((i=1;i<$((n+1));++i)); do
		delete_ingress_qdisc "${host_outdev}_${i}"
	done
	add_ingress_qdisc "$host_outdev"
	add_container_egress_common_rules

	for((i=1;i<$((n+1));++i)); do
		byte=`printf "%02x" $((i+1))`
		rep=${host_outdev}_$i
		add_container_ingress_rules $rep
		add_container_egress_rules $rep "192.168.1.1$i" "02:25:d0:$host_num:01:$byte"

		ns=n1${i}
		grep "Red Hat" /etc/redhat-release
		if (( $? == 0 )); then
			vf=$(ip netns exec $ns ls /sys/class/net | grep en)
		else
			vf=$(ip netns exec $ns ls /sys/class/net | grep eth)
		fi
		VF_MAC=$(ip netns exec $ns cat /sys/class/net/$vf/address)
		echo $VF_MAC
		ip netns exec $ns ifconfig $vf 192.168.1.1${i}/24 up
		ip netns exec $ns ip route add 8.9.10.0/24 via 192.168.1.254 dev $vf
		ip netns exec $ns arp -s 192.168.1.254 $gateway_mac
	done;
}

host_ip=8.9.10.1
ifconfig $host_outdev $host_ip/24 up

main
set +x
