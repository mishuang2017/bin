#!/bin/bash

####### remove change-id and issue ########

# git send-email --dry-run /labhome/cmi/sflow/ofproto/0/r11/* --to=dev@openvswitch.org --cc=echaudro@redhat.com --cc=i.maximets@ovn.org --cc=elibr@nvidia.com -cc=roniba@nvidia.com
git send-email --dry-run /labhome/cmi/sflow/saeed/0002-net-psample-Introduce-stubs-to-remove-NIC-driver-dep.patch --to=NBU-linux-internal@nvidia.com -cc=jiri@nvidia.com --cc=saeedm@nvidia.com

git send-email --dry-run /labhome/cmi/sflow/psample/12/0001-net-psample-Fix-netlink-skb-length-with-tunnel-info.patch --to=NBU-linux-internal@nvidia.com -cc=idosch@nvidia.com --suppress-cc=all

git send-email --dry-run /labhome/cmi/sflow/psample/12/0001-net-psample-Fix-netlink-skb-length-with-tunnel-info.patch --to=netdev@vger.kernel.org -cc=kuba@kernel.org -cc=idosch@nvidia.com -cc=jiri@nvidia.com

# git send-email /labhome/cmi/sflow/ofproto/0/r5_2/* --to=dev@openvswitch.org --cc=i.maximets@ovn.org --cc=elibr@nvidia.com -cc=roniba@nvidia.com
# i.maximets@ovn.org
# simon.horman@netronome.com
# sriharsha.basavapatna@broadcom.com
# hemal.shah@broadcom.com
# ian.stokes@intel.com
# u9012063@gmail.com
