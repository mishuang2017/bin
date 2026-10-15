mst_device="0002:01:00.0"
sf_id=$(/opt/mellanox/iproute2/sbin/mlxdevm port add pci/$mst_device flavour pcisf pfnum 0 sfnum 1 | head -1 | awk '{print $1}' | sed 's/\://')
/opt/mellanox/iproute2/sbin/mlxdevm port function set $sf_id hw_addr 02:25:f2:8d:a2:41 trust on state active
auxiliary_device_id=$(mlnx-sf -a show -i $sf_id | grep "Auxiliary device" | grep -Eo '[0-9]+$')
echo mlx5_core.sf.$auxiliary_device_id  > /sys/bus/auxiliary/drivers/mlx5_core.sf_cfg/unbind
echo mlx5_core.sf.$auxiliary_device_id > /sys/bus/auxiliary/drivers/mlx5_core.sf/bind
mlnx-sf -a show -i $sf_id
