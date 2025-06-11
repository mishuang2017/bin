nic1=enp8s0f0
nic2=enp8s0f1

pci1=0000:08:00.0
pci2=0000:08:00.1

ip1=1.1.1.1
ip2=2.2.2.1

set -x

for pci in $pci1 $pci2; do
        devlink dev eswitch set pci/$pci mode legacy
        devlink dev eswitch set pci/$pci mode switchdev
done

# for nic in $nic1 $nic2 $nic3 $nic4; do
# done

ifconfig $nic1 $ip1/24 up
ifconfig $nic2 $ip2/24 up

ip r r 5.5.5.0/24 nexthop via $ip1 dev $nic1 nexthop via $ip2 dev $nic2
