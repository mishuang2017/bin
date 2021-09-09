ovs-appctl -t ovs-vswitchd exit --cleanup
ovs-appctl -t ovsdb-server exit

pkill ovsdb-server
pkill ovs-vswitchd

ovsdb-tool create conf.db ./vswitchd/vswitch.ovsschema
ovsdb-server --detach --no-chdir --pidfile --log-file --remote=punix:/var/run/openvswitch/db.sock
ovs-vsctl --no-wait init
ovs-vswitchd --enable-dummy --disable-system --disable-system-route  --detach --no-chdir --pidfile --log-file -vvconn -vofproto_dpif -vunixctl

add_of_br () {
set -x
    local brnum=$1; shift
    local br=br$brnum
    local dpid=fedcba987654321$brnum
    local mac=aa:55:aa:55:00:0$brnum
    ovs-vsctl \
        -- add-br $br \
        -- set bridge $br datapath-type=dummy \
                          fail-mode=secure \
                          other-config:datapath-id=$dpid \
                          other-config:hwaddr=$mac \
                          protocols="[OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15]" \
        -- "$@"
set +x
}

ovs-vsctl del-br br0
add_of_br 0 set Bridge br0 fail-mode=standalone
ovs-vsctl -- add-port br0 p1 -- set Interface p1 type=dummy ofport_request=1 -- add-port br0 p2 -- set Interface p2 type=dummy ofport_request=2

  ovs-vsctl \
     set Interface br0 options:ifindex=1002 -- \
     set Interface p1 options:ifindex=1004 -- \
     set Interface p2 options:ifindex=1003 -- \
     set Bridge br0 sflow=@sf -- \
     --id=@sf create sflow targets=\"127.0.0.1:6343\" \
       header=128 sampling=1 polling=1000 agent=lo

ovs-appctl netdev-dummy/receive p1 'in_port(2),eth(src=50:54:00:00:00:05,dst=FF:FF:FF:FF:FF:FF),eth_type(0x0806),arp(sip=192.168.0.2,tip=192.168.0.1,op=1,sha=50:54:00:00:00:05,tha=00:00:00:00:00:00)'
sleep 1
ovs-appctl netdev-dummy/receive p2 'in_port(1),eth(src=50:54:00:00:00:07,dst=FF:FF:FF:FF:FF:FF),eth_type(0x0806),arp(sip=192.168.0.1,tip=192.168.0.2,op=1,sha=50:54:00:00:00:07,tha=00:00:00:00:00:00)'
sleep 1
ovs-appctl netdev-dummy/receive p1 'in_port(2),eth(src=50:54:00:00:00:05,dst=50:54:00:00:00:07),eth_type(0x0800),ipv4(src=192.168.0.1,dst=192.168.0.2,proto=1,tos=0,ttl=64,frag=no),icmp(type=8,code=0)'
sleep 1
ovs-appctl netdev-dummy/receive p2 'in_port(1),eth(src=50:54:00:00:00:07,dst=50:54:00:00:00:05),eth_type(0x0800),ipv4(src=192.168.0.2,dst=192.168.0.1,proto=1,tos=0,ttl=64,frag=no),icmp(type=0,code=0)'
ovs-appctl netdev-dummy/receive p2 'in_port(1),eth(src=50:54:00:00:00:07,dst=50:54:00:00:00:05),eth_type(0x86dd),ipv6(src=fe80::1,dst=fe80::2,label=0,proto=10,tclass=0x70,hlimit=128,frag=no)'
