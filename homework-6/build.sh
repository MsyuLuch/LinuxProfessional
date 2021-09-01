#!/bin/bash

wget -q https://www.openssl.org/source/latest.tar.gz && tar -xf latest.tar.gz

rpmdev-setuptree

wget -q https://nginx.org/packages/centos/7/SRPMS/nginx-1.14.1-1.el7_4.ngx.src.rpm && rpm -Uvh nginx-1.14.1-1.el7_4.ngx.src.rpm

wget -q https://raw.githubusercontent.com/MsyuLuch/LinuxProfessional/main/homework-6/nginx.spec && mv -f nginx.spec rpmbuild/SPECS/

sudo rpmbuild -bb --quiet rpmbuild/SPECS/nginx.spec

yum localinstall -y rpmbuild/RPMS/x86_64/nginx-1.14.1-1.el7_4.ngx.x86_64.rpm

systemctl start nginx && systemctl enable nginx

mkdir /usr/share/nginx/html/repo
cp rpmbuild/RPMS/x86_64/nginx-1.14.1-1.el7_4.ngx.x86_64.rpm /usr/share/nginx/html/repo/

createrepo /usr/share/nginx/html/repo/

sed -i 's/location \/ {/location \/ {\n autoindex on;/g' /etc/nginx/conf.d/default.conf
nginx -s reload

curl -a http://localhost/repo/

cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF

yum repolist enabled | grep otus
