#!/bin/bash

function install-packages
{
set -x
	systemctl disable yum-updatesd
	systemctl stop yum-updatesd
	sleep 1
	systemctl disable packagekitd
	systemctl stop packagekitd
	sleep 1

	yum -y update vim-minimal
	sleep 1
	yum -y install vim-enhanced
	sleep 1

	for i in nis sudo yp-tools ypbind ypserv autofs; do
		yum -y install $i
	done
	sleep 1
	for i in tmux cscope ctags screen ncurses-devel openssl-devel gcc gcc-c++ patch *lzo* *elf* git bison readline-devel snappy-devel wget tcl tcl-devel tk tk-devel git-email rpm-build bc; do
		yum -y install $i
	done
	sleep 1
	systemctl disable gdm
	systemctl stop gdm
	sleep 1
set +x
}

function config-network
{
set -x
	systemctl disable NetworkManager
	systemctl stop NetworkManager
	sleep 1
	systemctl disable firewalld
	systemctl stop firewalld
	sleep 1
	systemctl enable network
	sleep 1
	systemctl enable kdump
	systemctl start kdump
	sleep 1
set +x
}

function config-nis
{
set -x

	cat << EOF > /etc/nsswitch.conf
passwd:     files nis
shadow:     files nis
group:      files nis
hosts:      files dns nis
bootparams: nisplus [NOTFOUND=return] files
ethers:     files
netmasks:   files
networks:   files
protocols:  files
rpc:        files
services:   files
netgroup:   files nis
publickey:  nisplus
automount:  files nis
aliases:    files nis
EOF

	cat << EOF > /etc/sudoers
#
# This file MUST be edited with the 'visudo' command as root.
#
# Please consider adding local content in /etc/sudoers.d/ instead of
# directly modifying this file.
#
# See the man page for details on how to write a sudoers file.
#
Defaults    env_reset
Defaults    mail_badpass
Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Host alias specification

# User alias specification

# Cmnd alias specification

##
# Cmnd alias specification
##
Cmnd_Alias      DUMPS = /usr/sbin/dump, /usr/sbin/rdump, /usr/sbin/restore, \
/usr/sbin/rrestore, /usr/bin/mt

Cmnd_Alias      KILL = /usr/bin/kill, /usr/bin/pkill, /bin/kill, /usr/bin/killall
Cmnd_Alias      PRINTING = /usr/sbin/lpc, /usr/bin/lprm
Cmnd_Alias      SHUTDOWN = /usr/sbin/shutdown, /usr/bin/reboot -h
Cmnd_Alias      HALT = /usr/sbin/halt, /usr/sbin/fasthalt, /usr/sbin/shutdown -h, /usr/bin/reboot -h
Cmnd_Alias      REBOOT = /usr/sbin/reboot, /usr/sbin/fastboot, /usr/sbin/shutdown -r

Cmnd_Alias      SHELLS = /usr/bin/sh, /usr/bin/csh, /usr/bin/ksh, \
/usr/local/bin/tcsh, /usr/bin/rsh, \
/usr/local/bin/zsh, /bin/sh, /sbin/sh, \
/bin/bash, /usr/bin/bash, /usr/local/bin/bash

Cmnd_Alias      SU = /bin/su, /usr/bin/su, /usr/bin/sudo
Cmnd_Alias      VISUDO = /usr/sbin/visudo
Cmnd_Alias      VIPW = /usr/sbin/vipw, /usr/bin/passwd, /usr/bin/chsh, \
/usr/bin/chfn

Cmnd_Alias      NETWORKING = /sbin/route, /sbin/ifconfig, /bin/ping, \
/sbin/dhclient, /usr/bin/net, /sbin/iptables, \
/usr/bin/rfcomm, /usr/bin/wvdial, /sbin/iwconfig, \
/sbin/mii-tool, /sbin/ethtool, /usr/bin/minicom

Cmnd_Alias      SOFTWARE = /bin/rpm, /usr/bin/up2date, /usr/bin/yum
Cmnd_Alias      SERVICES = /sbin/service, /sbin/chkconfig
Cmnd_Alias      LOCATE = /usr/bin/updatedb
Cmnd_Alias      STORAGE = /sbin/fdisk, /sbin/sfdisk, /sbin/parted, /sbin/partprobe, /bin/mount, /bin/umount
Cmnd_Alias      DELEGATING = /bin/chown, /bin/chmod, /bin/chgrp
Cmnd_Alias      DRIVERS = /sbin/modprobe, /sbin/insmod

Cmnd_Alias    NOUSERS=/bin/rmuser root, /bin/passwd root, /bin/pwdadm root
Cmnd_Alias    NOSU=/usr/bin/su - root, /usr/bin/su - ,/usr/bin/su --
Cmnd_Alias    NOSU1=/usr/bin/su root, /usr/bin/su albert, /usr/bin/su "", /usr/bin/su dmitrym
Cmnd_Alias    NOSU2=/bin/passwd root
Cmnd_Alias    NOSU3=/usr/bin/sudo su, /usr/bin/sudo su --
Cmnd_Alias    NOSHELLS=/sbin/sh, /usr/bin/sh, /usr/bin/csh, /usr/bin/ksh, /usr/local/bin/tcsh, /usr/bin/rsh, /usr/local/bin/zsh, /bin/bash, /usr/bin/bash, /usr/local/bin/bash


# User privilege specification
root    ALL=(ALL:ALL) ALL

# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL

Cmnd_Alias      FORBIDDEN = VISUDO, VIPW
Cmnd_Alias      PASSCMDS = SHUTDOWN, HALT, REBOOT, SU, VIPW, NOUSERS, NOSU, NOSU1, NOSU2,      NOSU3, VISUDO

# Temporary allow-all-to-anyone line - will be deleted in future
ALL     ALL=(ALL) NOPASSWD: ALL, (root) PASSWD: FORBIDDEN, NOPASSWD: ALL, !FORBIDDEN

# See sudoers(5) for more information on "#include" directives:

#includedir /etc/sudoers.d
EOF

	cat << EOF > /etc/yp.conf
domain lab.mtl.com server 10.12.68.108
domain lab.mtl.com server 10.12.68.102
EOF

	echo lab.mtl.com > /etc/defaultdomain

	systemctl enable ypbind.service
	sleep 1
	systemctl enable autofs.service
	sleep 1

	systemctl start ypbind.service
	sleep 1
	systemctl start autofs.service
	sleep 1

	yptest | head -n 20

	for file in .bashrc .vim .vimrc .screenrc .tmux.conf; do
		/bin/rm ~/$file
		ln -s ~chrism/$file .
		sleep 1
	done

	cp ~chrism/.crash .
	sleep 1

	home=/home1/chrism
	mkdir -p $home
	chown chrism.mtl $home
	sleep 1

	cp ~chrism//labhome/chrism/config/authorized_keys ~
set +x
}

set -x
install-packages
config-network
config-nis

sed -i 's/timeout=30/timeout=10/' /lib/systemd/system/NetworkManager-wait-online.service
sleep 1

sed -i 's/SELINUX=enforcing/SELINUX=disable/' /etc/selinux/config
setenforce 0

set +x
# http://xmodulo.com/how-to-configure-linux-bridge-interface.html
