set -x

modprobe bonding
# echo '2' > /sys/class/net/enp8s0f0/device/sriov_numvfs
# ip link set dev enp8s0f0 vf 0 state enable
# ip link set dev enp8s0f0 vf 1 state enable
# ip link set dev enp8s0f0 vf 0 mac 00:00:00:00:00:01
# ip link set dev enp8s0f0 vf 1 mac 00:00:00:00:00:02
# echo '0000:08:00.2' > /sys/bus/pci/drivers/mlx5_core/unbind
# echo '0000:08:00.3' > /sys/bus/pci/drivers/mlx5_core/unbind
devlink dev eswitch set pci/0000:08:00.0 mode switchdev

# echo '2' > /sys/class/net/enp8s0f1/device/sriov_numvfs
# ip link set dev enp8s0f1 vf 0 state enable
# ip link set dev enp8s0f1 vf 1 state enable
# ip link set dev enp8s0f1 vf 0 mac 00:00:00:00:00:01
# ip link set dev enp8s0f1 vf 1 mac 00:00:00:00:00:02
# echo '0000:08:00.6' > /sys/bus/pci/drivers/mlx5_core/unbind
# echo '0000:08:00.7' > /sys/bus/pci/drivers/mlx5_core/unbind
devlink dev eswitch set pci/0000:08:00.1 mode switchdev

link=enp8s0f0
link2=enp8s0f1

ip link set dev $link link down
ip link set dev $link2 down
# ip link add name bond0 type bond mode active-backup miimon 100
ip link add name bond0 type bond mode 802.3ad xmit_hash_policy layer3+4 miimon 100
ip link set dev $link master bond0
ip link set dev $link2 master bond0
ip link set dev bond0 up
ip link set dev $link up
ip link set dev $link2 up

set +x
