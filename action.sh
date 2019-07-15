#!/bin/bash

file=$1

/bin/rm -rf $file

max=24

set -x
for ((i = 1; i <= 65536; i++)); do
	if (( i % max == 1)); then
		printf "action add " >> $file
	fi
	printf "action ok index $i " >> $file
	if (( i % max == 0 )); then
		printf "\n" >> $file
	fi
done
set +x

tail -1 $file
