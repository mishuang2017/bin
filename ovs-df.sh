#!/bin/bash

NOC="\o033[0;0m"
RED="\o033[0;31m"
GREEN="\o033[0;32m"
YELLOW="\o033[0;33m"
BLUE="\o033[0;34m"
PURPLE="\o033[0;35m"
MAGENTA="\o033[0;36m"

color="\
sed -e 's/\(actions\)/$RED\1$NOC/'     | \
sed -e 's/\(ct_state\|recirc_id\|recirc\)/$YELLOW\1$NOC/g' | \
sed -e 's/\(.trk\|.new\|.est\)/$PURPLE\1$NOC/g' | \
sed -e 's/\([+-]\?df\|[+-]\?csum\|[+-]\?key\|\bct\b\)/$PURPLE\1$NOC/g' | \
sed -e 's/\(proto\|frag\|ttl\|tos\|src\|tp_dst\|dst\|tun_id\|flags\)/$MAGENTA\1$NOC/g' | \
sed -e 's/\(eth_type(\)\(0x....\)/\1$GREEN\2$NOC/g' | \
sed -e 's/\(commit\)/$GREEN\1$NOC/g' | \
sed -e 's/\(eth_type\|ipv4\|ipv6\|in_port\|tunnel\)/$YELLOW\1$NOC/g' | \
sed -e 's/\(eth\b\|set\)/$BLUE\1$NOC/g'    \
"
eval "ovs-appctl dpctl/dump-flows --names $@ | $color | sort"
