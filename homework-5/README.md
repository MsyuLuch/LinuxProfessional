# **Домашнее задание №5**

Для выполнения работы потребуются следующие инструменты:

- **VirtualBox** - среда виртуализации, позволяет создавать и выполнять виртуальные машины;
- **Vagrant** - ПО для создания и конфигурирования виртуальной среды. В данном случае в качестве среды виртуализации используется *VirtualBox*; (https://www.vagrantup.com/downloads.html);

# **Цель**
 
## **Практические навыки работы с NFS**
 
Vagrant стенд для NFS https://github.com/nixuser/virtlab/blob/main/nfs_server/Vagrantfile

NFS:

- vagrant up должен поднимать 2 виртуалки: сервер и клиент;
- на сервер должна быть расшарена директория;
- на клиента она должна автоматически монтироваться при старте (fstab или autofs);
- в шаре должна быть папка upload с правами на запись;
- требования для NFS: NFSv3 по UDP, включенный firewall.

# **Исходные данные**

Ссылка на проект https://github.com/MsyuLuch/LinuxProfessional/tree/main/homework-5

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
- `init_server_v3.sh` - скрипт инициализации для сервера (nfs v3)
- `init_server.sh` - скрипт инициализации для сервера (nfs v4)
- `init_client.sh` - скрипт инициализации для клиента

# **Описание процесса выполнения домашнего задания №5**

Поднимаем 3 виртуальных машины: 2 сервера и клиент:
На `server_v3` при старте запускается скрипт init_server_v3_sh:
```
#!/bin/bash

# директория, которую будем расшаривать
SHARE_DIR=/var/nfs_share_v3

# выключаем selinux
selinuxenabled && setenforce 0

cat >/etc/selinux/config<<__EOF
SELINUX=disabled
SELINUXTYPE=targeted
__EOF

# устанавливаем NFS сервер
yum install nfs-utils -y

# создаем директорию для расшаривания и даем на нее права всем на запись
mkdir $SHARE_DIR
chmod o+w $SHARE_DIR

# внесем изменения в конфигурационный файл /etc/exports (права для экспортируемой файловой системы на чтение и запись):
echo ${SHARE_DIR} *\(rw\) >> /etc/exports

# в конфиг файле прописываем принудительно использовать версию v3
cat >/etc/nfs.conf<<__EOF
[nfsd]
vers3=y
__EOF

# запускаем nfs сервер и добавляем его в автозагрузку
systemctl start nfs-server.service && systemctl enable nfs-server.service

# Применим настройки NFS сервера и проверим результат:
exportfs -s
exportfs -rav

# запускаем firewalld и добавляем его в автозагрузку
systemctl start firewalld && systemctl enable firewalld 

# добавляем службы nfs, rpc-bind, mountd в firewalld
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=mountd
firewall-cmd --reload

# дополнительно для nfs v3 открываем порты
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
firewall-cmd --add-port=32769/udp 
firewall-cmd --add-port=32803/tcp
```

На ВМ `server` при старте запускается скрипт init_server_sh:
```
#!/bin/bash

# директория, которую будем расшаривать
SHARE_DIR=/var/nfs_share

# выключаем selinux
selinuxenabled && setenforce 0

cat >/etc/selinux/config<<__EOF
SELINUX=disabled
SELINUXTYPE=targeted
__EOF

# устанавливаем NFS сервер
yum install nfs-utils -y

# создаем директорию для расшаривания и даем на нее права всем на запись
mkdir $SHARE_DIR
chmod o+w $SHARE_DIR

# внесем изменения в конфигурационный файл /etc/exports (права для расшаренной директории на чтение и запись):
echo ${SHARE_DIR} *\(rw\) >> /etc/exports

# в конфиг файле прописываем принудитель использовать версию v3
cat >/etc/nfs.conf<<__EOF
[nfsd]
vers3=y
__EOF

# запускаем nfs сервер и добавляем его в автозагрузку
systemctl start nfs-server.service && systemctl enable nfs-server.service

# Применим настройки NFS сервера и проверим результат:
exportfs -s
exportfs -rav

# запускаем firewalld и добавляем его в автозагрузку
systemctl start firewalld && systemctl enable firewalld 

# добавляем службы nfs, rpc-bind, mountd в firewalld
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=mountd
firewall-cmd --reload
```
На ВМ `client` при старте запускается скрипт init_client_sh:
```
#!/bin/bash

# ip ВМ использующей версию nfs v4 и ссылка на экспортируемую файловую систему
SHARE_IP=10.0.0.41
SHARE_DIR=10.0.0.41:/var/nfs_share
# точка монтивания
MNT_DIR=/mnt/nfs_share

# отключаем selinux
selinuxenabled && setenforce 0

cat >/etc/selinux/config<<__EOF
SELINUX=disabled
SELINUXTYPE=targeted
__EOF

# устанавливаем nsf сервер
yum install nfs-utils -y

# запускаем nfs сервер и добавляем его в автозагрузку
systemctl start nfs-server.service && systemctl enable nfs-server.service

# проверяем файловые системы, которые экспортирует сервер NFS
showmount --exports $SHARE_IP

# создаем директорию и выполняем монтирование удаленного ресурса
mkdir $MNT_DIR
mount -t nfs $SHARE_DIR $MNT_DIR

# добавляем строку в файл fstab для автоматического монтирования при старте ВМ
echo ${SHARE_DIR} ${MNT_DIR} nfs defaults 0 0 >> /etc/fstab

# ip ВМ использующей версию nfs v3 и директория, которую будем монтировать
SHARE_IP_v3=10.0.0.42
SHARE_DIR_v3=10.0.0.42:/var/nfs_share_v3
MNT_DIR_v3=/mnt/nfs_share_v3

# проверяем файловые системы, которые экспортирует сервер NFS
showmount --exports $SHARE_IP_v3

# создаем директорию и выполняем монтирование удаленной файлововй системы с опциями использовать версию nfs v3 по протоколу udp
mkdir $MNT_DIR_v3
mount -t nfs -o vers=3,proto=udp $SHARE_DIR_v3 $MNT_DIR_v3

# добавляем строку (опции монтирования прописываем дополнительно) в файл fstab для автоматического монтирования при старте ВМ
echo ${SHARE_DIR_v3} ${MNT_DIR_v3} nfs vers=3,proto=udp defaults 0 0 >> /etc/fstab
```
Авторизуемся на клиенте и попробуем создать файл и проверить появился ли он на сервере:
```
[root@client vagrant]# touch /mnt/nfs_share_v3/file1
[root@client vagrant]# touch /mnt/nfs_share/file1

[root@server vagrant]# ls -la /var/nfs_share
total 0
drwxrwxrwx 2 root   root   19 Aug 20 05:03 .
drwxr-xr-x 3 root   root   18 Aug 20 05:01 ..
-rw-r--r-- 1 nobody nobody  0 Aug 20 05:03 file1

[root@nfsv3 vagrant]# ls -la /var/nfs_share_v3
total 0
drwxr-xrwx.  2 root      root       32 Aug 24 01:44 .
drwxr-xr-x. 19 root      root      274 Aug 24 00:56 ..
-rw-r--r--.  1 nfsnobody nfsnobody   0 Aug 24 01:43 file1
```
