set -x

/opt/mellanox/iproute2/sbin/devlink dev eswitch set pci/0000:08:00.0 mode switchdev
echo 1 > /sys/class/net/enp8s0f0/device/sriov_numvfs
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0 vf 0 mac e4:11:22:33:62:51
echo 0000:08:00.4 > /sys/bus/pci/drivers/mlx5_core/unbind
/opt/mellanox/iproute2/sbin/devlink dev eswitch show pci/0000:08:00.0
/opt/mellanox/iproute2/sbin/devlink dev eswitch show pci/0000:08:00.1
/opt/mellanox/iproute2/sbin/devlink dev eswitch set pci/0000:08:00.1 mode switchdev
/opt/mellanox/iproute2/sbin/devlink dev eswitch show pci/0000:08:00.2
/opt/mellanox/iproute2/sbin/devlink dev eswitch set pci/0000:08:00.2 mode switchdev
/opt/mellanox/iproute2/sbin/devlink dev eswitch show pci/0000:08:00.3
/opt/mellanox/iproute2/sbin/devlink dev eswitch set pci/0000:08:00.3 mode switchdev
echo 0000:08:00.4 > /sys/bus/pci/drivers/mlx5_core/bind
echo 0000:08:00.4 > /sys/bus/pci/drivers/mlx5_core/unbind

sleep 1
modprobe bonding
echo +bond_0 > /sys/class/net/bonding_masters
echo balance-xor > /sys/class/net/bond_0/bonding/mode
echo layer3+4 > /sys/class/net/bond_0/bonding/xmit_hash_policy
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0 down
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f1 down
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f2 down
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f3 down
/opt/mellanox/iproute2/sbin/ip link set dev bond_0 up
echo +enp8s0f0 > /sys/class/net/bond_0/bonding/slaves
echo +enp8s0f1 > /sys/class/net/bond_0/bonding/slaves
echo +enp8s0f2 > /sys/class/net/bond_0/bonding/slaves
echo +enp8s0f3 > /sys/class/net/bond_0/bonding/slaves

sleep 1
echo 0000:08:00.4 > /sys/bus/pci/drivers/mlx5_core/bind
/opt/mellanox/iproute2/sbin/devlink port show -j
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0_0 up
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0 up
/opt/mellanox/iproute2/sbin/ip link set dev bond_0 up
/opt/mellanox/iproute2/sbin/ip addr add 11.1.1.1/16 dev enp8s0f0v0
/opt/mellanox/iproute2/sbin/ip -6 addr add 2001:0db8::1/96 dev enp8s0f0v0
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0v0 up
/opt/mellanox/iproute2/sbin/ip link set dev enp8s0f0v0 name vf

ifconfig bond_0 1.1.1.1/24 up

set +x
