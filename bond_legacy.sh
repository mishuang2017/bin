set -x

rmmod bonding
modprobe bonding

echo '+bond0' > /sys/class/net/bonding_masters

echo 'active-backup' > /sys/class/net/bond0/bonding/mode
echo 'balance-rr' > /sys/class/net/bond0/bonding/mode

# echo 'balance-xor' > /sys/class/net/bond0/bonding/mode
# echo 'layer2' > /sys/class/net/bond0/bonding/xmit_hash_policy

ip link set dev enp8s0f0 down
echo '+enp8s0f0' > /sys/class/net/bond0/bonding/slaves
ip link set dev enp8s0f1 down
echo '+enp8s0f1' > /sys/class/net/bond0/bonding/slaves
echo '1' > /sys/class/net/bond0/bonding/all_slaves_active

ip link set dev enp8s0f0 up
ip link set dev enp8s0f1 up
ip link set dev bond0 up

set +x
