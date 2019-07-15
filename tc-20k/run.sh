#!/bin/bash

# split -l 100000 /tmp/udp.txt tc

for i in tc*; do
	echo $i; time tc -b $i &
done
