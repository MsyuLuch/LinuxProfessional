#!/bin/bash

SHARE_DIR=/var/nfs_share

selinuxenabled && setenforce 0

cat >/etc/selinux/config<<__EOF
SELINUX=disabled
SELINUXTYPE=targeted
__EOF

yum install nfs-utils -y

systemctl start nfs-server.service && systemctl enable nfs-server.service

mkdir $SHARE_DIR
chmod o+w $SHARE_DIR

echo ${SHARE_DIR} *\(rw\) >> /etc/exports

exportfs -s
exportfs -rav

systemctl start firewalld && systemctl enable firewalld

firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=mountd
firewall-cmd --reload