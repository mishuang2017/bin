#!/bin/bash

# hosts=10.237.14.183-184_cx5
hosts=$1
password=$2

[[ -z $hosts ]] && exit

host1=${hosts/-*/}
echo host1=$host1
num1=${host1/*./}
echo num1=$num1

host0=$(echo $hosts | sed 's/\.[^.]*$/./')
echo host0=$host0

num2=${hosts/*-/}
num2=${num2/_*/}
host2=$host0$num2
echo host2=$host2
echo num2=$num2

sed -i "/alias $num1=/d" ~/.bashrc
sed -i "/alias $num2=/d" ~/.bashrc

cat << EOF >> ~/.bashrc
alias $num1='ssh root@$host1'
alias $num2='ssh root@$host2'
EOF

[[ -z $password ]] && exit

sshpass -p $password ssh-copy-id  -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root@$host1
sshpass -p $password ssh-copy-id  -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root@$host2

set -x
for host in $host1 $host2; do
	ssh root@$host "mkdir -p /images/cmi; \
		chown cmi.mtl /images/cmi; \
		ln -s /labhome/cmi/mi /images/cmi; \
		mv /root/.bashrc bashrc.orig; \
		ln -s /labhome/cmi/.bashrc /root; \
		ln -s /labhome/cmi/.tmux.conf /root; \
		ln -s /labhome/cmi/.vimrc /root; \
		ln -s /labhome/cmi/.vim /root; \
		/bin/cp /labhome/cmi/.crash /root; \
		yum install -y tmux"
	done
set +x