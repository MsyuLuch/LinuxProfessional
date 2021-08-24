#!/bin/bash

SHARE_IP=10.0.0.41
SHARE_DIR=10.0.0.41:/var/nfs_share
MNT_DIR=/mnt/nfs_share

# disable selinux or permissive

selinuxenabled && setenforce 0

cat >/etc/selinux/config<<__EOF
SELINUX=disabled
SELINUXTYPE=targeted
__EOF

yum install nfs-utils -y

systemctl start nfs-server.service && systemctl enable nfs-server.service

showmount --exports $SHARE_IP

mkdir $MNT_DIR
mount -t nfs $SHARE_DIR $MNT_DIR

SHARE_IP_v3=10.0.0.42
SHARE_DIR_v3=10.0.0.42:/var/nfs_share_v3
MNT_DIR_v3=/mnt/nfs_share_v3

showmount --exports $SHARE_IP_v3

mkdir $MNT_DIR_v3
mount -t nfs -o vers=3,proto=udp $SHARE_DIR_v3 $MNT_DIR_v3

echo ${SHARE_DIR} ${MNT_DIR} nfs defaults 0 0 >> /etc/fstab
echo ${SHARE_DIR_v3} ${MNT_DIR_v3} nfs vers=3,proto=udp defaults 0 0 >> /etc/fstab
