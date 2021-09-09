#!/bin/bash

oldvg="vagrant-vg"
oldvgdash="vagrant--vg"
newvg="root-vg"
newvgdash="root--vg"

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

vgrename ${oldvg} ${newvg}
sed -i "s/${oldvg}/${newvg}/g" /etc/fstab
sed -i "s/${oldvgdash}/${newvgdash}/g" /etc/fstab
sed -i "s/${oldvg}/${newvg}/g" /boot/grub/grub.cfg
sed -i "s/${oldvgdash}/${newvgdash}/g" /boot/grub/grub.cfg
sed -i "s/${oldvg}/${newvg}/g" /boot/grub/menu.lst
sed -i "s/${oldvgdash}/${newvgdash}/g" /boot/grub/menu.lst
sed -i "s/${oldvg}/${newvg}/g" /etc/initramfs-tools/conf.d/resume
sed -i "s/${oldvgdash}/${newvgdash}/g" /etc/initramfs-tools/conf.d/resume
update-initramfs -c -k all

swapoff -a && swapon -a