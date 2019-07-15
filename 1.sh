#!/bin/bash

cd /images/chrism/linux-4.9.79
make modules_install -j 32
make install

uname=$(uname -r)
cmdline=$(cat /proc/cmdline | cut -d " " -f 2-)
kexec -l /boot/vmlinuz-$uname --append="BOOT_IMAGE=/vmlinuz-$uname $cmdline" --initrd=/boot/initramfs-$uname.img
kexec -e
