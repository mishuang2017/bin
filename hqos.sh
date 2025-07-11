#!/bin/bash

cmd=devlink

devlink dev eswitch set pci/0000:08:00.0 mode switchdev;
echo 3 > /sys/class/net/enp8s0f0/device/sriov_numvfs

$cmd port function rate add pci/0000:08:00.0/group0
$cmd port function rate set pci/0000:08:00.0/group0 tx_share 5Gbit
$cmd port function rate set pci/0000:08:00.0/1 parent group0
$cmd port function rate add pci/0000:08:00.0/grouproot
$cmd port function rate set pci/0000:08:00.0/group0 parent grouproot
$cmd port function rate set pci/0000:08:00.0/1 noparent
$cmd port function rate set pci/0000:08:00.0/group0 parent grouproot
$cmd port function rate set pci/0000:08:00.0/1 parent group0
$cmd port function rate set pci/0000:08:00.0/grouproot tx_max 18Gbit
$cmd port function rate show
