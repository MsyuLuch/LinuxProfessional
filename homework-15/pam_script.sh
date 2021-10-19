#!/bin/bash

groupadd admin
useradd -G admin can_user
useradd -G cant_user

echo "123" | sudo passwd --stdin can_user &&\
echo "123" | sudo passwd --stdin cant_user

sed -i "2i auth       required     pam_exec.so /usr/local/bin/pam_script.sh"  /etc/pam.d/sshd

cat <<'EOF' > /usr/local/bin/pam_script.sh
#!/bin/bash
if [[ `grep $PAM_USER /etc/group | grep 'admin'` ]]
then
exit 0
fi
if [[ `date +%u` > 5 ]]
then
exit 1
fi
EOF

chmod +x /usr/local/bin/pam_script.sh

sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd

yum install yum-utils -y
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install docker-ce docker-ce-cli containerd.io -y
systemctl enable --now docker

useradd docker_user
echo "123" | sudo passwd --stdin docker_user
usermod -aG docker docker_user

echo %docker_user ALL=NOPASSWD: /bin/systemctl restart docker.service>>/etc/sudoers
