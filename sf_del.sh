for sf in $(/opt/mellanox/iproute2/sbin/mlxdevm port show | grep -i pcisf | grep -i "controller 1" | awk '{print $1}' | sed 's/:$//'); do
    echo "Deleting $sf..."
    /opt/mellanox/iproute2/sbin/mlxdevm port del $sf
done
