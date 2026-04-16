for i in {0..99}; do
    sf_id=$(/opt/mellanox/iproute2/sbin/mlxdevm port add pci/0000:03:00.0 flavour pcisf pfnum 0 sfnum $i controller 1 | grep "pci/" | awk '{print $1}' | sed 's/:$//')
    if [ -n "$sf_id" ]; then
        echo "SF $i ($sf_id) -> Created"
    else
        echo "Failed to create SF at index $i"
    fi
done
