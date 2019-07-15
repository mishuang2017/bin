#! /bin/sh

TMP=/tmp/of.txt
count=200000
cur=0
rm -f $TMP

for ((k=0;k<=3;k++))
do
    for((i=0;i<=254;i++))
    do
        for((j=0;j<=254;j++))
        do
            echo "table=0, priority=10, ip,nw_dst=10.$k.$i.$j, in_port="ens2f0_0" action=output:vxlan0"
            let cur+=1
            [ $cur -eq $count ] && break;
        done
        [ $cur -eq $count ] && break;
    done
    [ $cur -eq $count ] && break;
done >> $TMP

br=br
ovs-ofctl add-flow $br -O openflow13 $TMP
ovs-ofctl dump-flows $br | wc -l
