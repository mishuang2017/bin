#!/bin/bash

# hosts=10.237.14.183-184_cx5
hosts=$1
password=$2

[[ -z $hosts ]] && exit
[[ -z $password ]] && exit

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

file=~cmi/mi/cloud_alias

sed -i "/alias $num1=/d" $file
sed -i "/alias $num2=/d" $file

cat << EOF >> $file
alias $num1='ssh cmi@$host1'
alias $num2='ssh cmi@$host2'
EOF

set -x
for host in $host1 $host2; do
	sshpass -p $password ssh-copy-id  -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root@$host

	ssh root@$host "if [[ ! -d /images/cmi ]]; then
		mkdir -p /images/cmi; \
		chown cmi.mtl /images/cmi; \
		ln -s /labhome/cmi/mi /images/cmi; \
		mv /root/.bashrc bashrc.orig; \
		ln -s /labhome/cmi/.bashrc /root; \
		ln -s /labhome/cmi/.tmux.conf /root; \
		ln -s /labhome/cmi/.vimrc /root; \
		ln -s /labhome/cmi/.vim /root; \
		/bin/cp /labhome/cmi/.crash /root; \
		test -f /bin/tmux || yum install -y tmux ctags kexec-tools; \
		fi "
done
set +x
