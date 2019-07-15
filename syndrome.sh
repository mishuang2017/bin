#!/bin/bash

SYNDROME=${1:?Need syndrome. i.e. 0x368b01}
HCA1=`ls -1 /sys/class/infiniband | head -1`
HCA=${2:-$HCA1}

# for fallback
CX4_GIT="/.autodirect/mtrsysgwork/roid/gerrit2/cx4_fw"

SYSFS=/sys/class/infiniband/$HCA
if [ ! -e $SYSFS ]; then
    echo "Can't find HCA $HCA"
    exit 1
fi

if [[ "$SYNDROME" == 0x* ]]; then
    SYNDROME=${SYNDROME:2}
fi

echo "SYNDROME $SYNDROME"

TYPE=`cat $SYSFS/hca_type`
FW=`cat $SYSFS/fw_ver`
echo "HCA $HCA"
echo "TYPE $TYPE"
echo "FW $FW"
test -z $FW && exit 1
test -z $TYPE && exit 1

type=${TYPE:2}
fw=${FW//./_}
echo type $type
echo fw $fw
test -z $fw && exit 1
test -z $type && exit 1

if (( type == 4121 )); then
	type=4119
fi
if (( type == 4122 )); then
	type=4119
fi

log="/mswg/release/BUILDS/fw-${type}/fw-${type}-rel-${fw}-build-001/etc/syndrome_list.log"

echo $log

ls -1 $log
if [ ! -e $log ]; then
    echo "Can't find synrome log"
else
    grep -i -m 1 $SYNDROME $log
    if [ "$?" = 0 ]; then
        exit 0
    fi
    echo "Can't find syndrome in syndrome_list.log"
fi

grep -i $SYNDROME $log

echo "Try to look in cx4_git"
if [ ! -e $CX4_GIT ]; then
    echo "Cannot find $CX4_GIT"
    exit 1
fi
cd $CX4_GIT
git grep -i fwassert\(.*$SYNDROME || echo "No results"
