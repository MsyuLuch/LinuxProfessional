#!/bin/bash

SHARE_DIR=/var/nfs_share_v3

selinuxenabled && setenforce 0

cat >/etc/selinux/config<<__EOF
SELINUX=disabled
SELINUXTYPE=targeted
__EOF

yum install nfs-utils -y

mkdir $SHARE_DIR
chmod o+w $SHARE_DIR

echo ${SHARE_DIR} *\(rw\) >> /etc/exports

cat >/etc/nfs.conf<<__EOF
[nfsd]
vers3=y
__EOF

systemctl start nfs-server.service && systemctl enable nfs-server.service

exportfs -s
exportfs -rav

systemctl start firewalld && systemctl enable firewalld

firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=mountd
firewall-cmd --reload

firewall-cmd --add-port=111/tcp
firewall-cmd --add-port=111/udp
firewall-cmd --add-port=2049/tcp
firewall-cmd --add-port=2049/udp
firewall-cmd --add-port=892/tcp
firewall-cmd --add-port=892/udp
firewall-cmd --add-port=875/tcp
firewall-cmd --add-port=875/udp
firewall-cmd --add-port=662/tcp
firewall-cmd --add-port=662/udp
firewall-cmd --add-port=32769/tcp
firewall-cmd --add-port=32769/udp
firewall-cmd --add-port=32803/tcp
firewall-cmd --add-port=32803/udp
firewall-cmd --add-port=38467/tcp
firewall-cmd --add-port=38467/udp

