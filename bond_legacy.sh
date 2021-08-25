set -x

modprobe bonding
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0 up
echo '2' > /sys/class/net/enp8s0f0/device/sriov_numvfs
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0 vf 0 state enable
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0 vf 1 state enable
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0 vf 0 mac 00:00:00:00:00:01
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0 vf 1 mac 00:00:00:00:00:02
echo '0000:08:00.2' > /sys/bus/pci/drivers/mlx5_core/unbind
echo '0000:08:00.3' > /sys/bus/pci/drivers/mlx5_core/unbind
/opt/mellanox/iproute2/sbin/devlink dev eswitch set pci/0000:08:00.0 mode switchdev
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0 up

echo '2' > /sys/class/net/enp8s0f1/device/sriov_numvfs
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f1 vf 0 state enable
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f1 vf 1 state enable
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f1 vf 0 mac 00:00:00:00:00:01
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f1 vf 1 mac 00:00:00:00:00:02
echo '0000:08:00.6' > /sys/bus/pci/drivers/mlx5_core/unbind
echo '0000:08:00.7' > /sys/bus/pci/drivers/mlx5_core/unbind
/opt/mellanox/iproute2/sbin/devlink dev eswitch set pci/0000:08:00.1 mode switchdev

echo '+enp8s0f0bond0' > /sys/class/net/bonding_masters
echo 'balance-xor' > /sys/class/net/enp8s0f0bond0/bonding/mode
echo 'layer2' > /sys/class/net/enp8s0f0bond0/bonding/xmit_hash_policy
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0 down
echo '+enp8s0f0' > /sys/class/net/enp8s0f0bond0/bonding/slaves
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f1 down
echo '+enp8s0f1' > /sys/class/net/enp8s0f0bond0/bonding/slaves
echo '1' > /sys/class/net/enp8s0f0bond0/bonding/all_slaves_active

/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0 up
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f1 up
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0bond0 up

set +x
