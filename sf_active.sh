i=0
for sf in $(/opt/mellanox/iproute2/sbin/mlxdevm port show | grep -i pcisf | grep -i "controller 1" | awk '{print $1}' | sed 's/:$//'); do
    # Set the function to active
    /opt/mellanox/iproute2/sbin/mlxdevm port function set $sf state active
    # Print progress with the SF index and the specific PCI device ID
    echo "SF $i ($sf) -> Active"
    i=$((i+1))
done
