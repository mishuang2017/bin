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

ip r d 5.5.5.0/24
ip r d 5.5.5.0/24 nhid 38

ip nexthop del id 38
ip nexthop del id 39
ip nexthop del id 40

ip nexthop add id 39 dev $nic1
ip nexthop add id 40 dev $nic2
ip nexthop add id 38 group 39/40
ip route r 5.5.5.0/24 nhid 38 proto static metric 20

set +x
