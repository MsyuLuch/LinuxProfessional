# **Домашнее задание №3**

Для выполнения работы потребуются следующие инструменты:

- **VirtualBox** - среда виртуализации, позволяет создавать и выполнять виртуальные машины;
- **Vagrant** - ПО для создания и конфигурирования виртуальной среды. В данном случае в качестве среды виртуализации используется *VirtualBox*; (https://www.vagrantup.com/downloads.html);

# **Цель**
 
Работа с LVM
 
На имеющемся образе (centos/7 1804.2) https://gitlab.com/otus_linux/stands-03-lvm

`/dev/mapper/VolGroup00-LogVol00 38G 738M 37G 2% /`

- уменьшить том под / до 8G
- выделить том под /home
- выделить том под /var (/var - сделать в mirror)
- для /home - сделать том для снэпшотов
- прописать монтирование в fstab (попробовать с разными опциями и разными файловыми системами на выбор)

Работа со снапшотами:
- сгенерировать файлы в /home/
- снять снапшот
- удалить часть файлов
- восстановиться со снапшота

Залоггировать работу можно утилитой script, скриншотами и т.п.

# **Исходные данные**

Ссылка на проект https://github.com/MsyuLuch/LinuxProfessional/tree/main/homework-3

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
- `history_log_copy.txt` - log терминальной сессии

---
# **Описание процесса выполнения домашнего задания №3**

***Уменьшить том под / до 8G***

Первоначальная конфигурация:
```
#lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk 
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
sde                       8:64   0    1G  0 disk 
# df -hT
Filesystem                      Type      Size  Used Avail Use% Mounted on
devtmpfs                        devtmpfs  110M     0  110M   0% /dev
tmpfs                           tmpfs     118M     0  118M   0% /dev/shm
tmpfs                           tmpfs     118M  4.6M  113M   4% /run
tmpfs                           tmpfs     118M     0  118M   0% /sys/fs/cgroup
/dev/mapper/VolGroup00-LogVol00 xfs        38G  1.4G   37G   4% /
/dev/sda2                       xfs      1014M   86M  929M   9% /boot
vagrant                         vboxsf    477G  110G  367G  24% /vagrant
tmpfs                           tmpfs      24M     0   24M   0% /run/user/1000
```

Подготовим временный том для / раздела. Для этого создадим Physical Volume (/dev/sdb), Volume Group (vg_root), Logical Volume (lv_root):

```
pvcreate /dev/sdb
vgcreate vg_root /dev/sdb
lvcreate -n lv_root -l +100%FREE /dev/vg_root
```

Создаем на lv_root файловую систему и смонтируем его, чтобы перенести туда данные:

```
mkfs.xfs /dev/vg_root/lv_root
mount /dev/vg_root/lv_root /mnt
```

Скопируем все данные с / раздела в /mnt, с помощью утилиты xfsdump:

```
xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
```

Результат операций:
```
# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk 
└─vg_root-lv_root       253:2    0   10G  0 lvm  /mnt
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
sde                       8:64   0    1G  0 disk 

# df -hT
Filesystem                      Type      Size  Used Avail Use% Mounted on
devtmpfs                        devtmpfs  110M     0  110M   0% /dev
tmpfs                           tmpfs     118M     0  118M   0% /dev/shm
tmpfs                           tmpfs     118M  4.6M  113M   4% /run
tmpfs                           tmpfs     118M     0  118M   0% /sys/fs/cgroup
/dev/mapper/VolGroup00-LogVol00 xfs        38G  1.4G   37G   4% /
/dev/sda2                       xfs      1014M   86M  929M   9% /boot
vagrant                         vboxsf    477G  110G  367G  24% /vagrant
tmpfs                           tmpfs      24M     0   24M   0% /run/user/1000
/dev/mapper/vg_root-lv_root     xfs        10G   33M   10G   1% /mnt
```

Переконфигурируем grub для того, чтобы при старте перейти в новый / (примонтированный на данный момент в папку /mnt)

```
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
chroot /mnt/
grub2-mkconfig -o /boot/grub2/grub.cfg
```

Обновим образ initrd:

```
cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
```

Для того, чтобы при загрузке был смонтирован нужный \, необходимо в файле
/boot/grub2/grub.cfg заменить rd.lvm.lv=VolGroup00/LogVol00 на rd.lvm.lv=vg_root/lv_root

Перезагружаемся с новым / томом:
```
# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol00 253:2    0 37.5G  0 lvm  
sdb                       8:16   0   10G  0 disk 
└─vg_root-lv_root       253:0    0   10G  0 lvm  /
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
sde                       8:64   0    1G  0 disk 

# df -hT
Filesystem                  Type      Size  Used Avail Use% Mounted on
devtmpfs                    devtmpfs  109M     0  109M   0% /dev
tmpfs                       tmpfs     118M     0  118M   0% /dev/shm
tmpfs                       tmpfs     118M  4.6M  113M   4% /run
tmpfs                       tmpfs     118M     0  118M   0% /sys/fs/cgroup
/dev/mapper/vg_root-lv_root xfs        10G  1.4G  8.7G  14% /
/dev/sda2                   xfs      1014M   86M  929M   9% /boot
/vagrant                    vboxsf    477G  110G  367G  24% /vagrant
tmpfs                       tmpfs      24M     0   24M   0% /run/user/1000
```

Изменим размер старой VG и вернем на него \. 
Для этого удаляем старый LV размеров в 40G и создаем новый на 8G:

```
lvremove /dev/VolGroup00/LogVol00
lvcreate -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
```

Создаем на вновь созданном LV файловую систему, монтируем его в /mnt, переносим данные с /dev/vg_root/lv_root в /mnt

```
mkfs.xfs /dev/VolGroup00/LogVol00
mount /dev/VolGroup00/LogVol00 /mnt
xfsdump -J - /dev/vg_root/lv_root | xfsrestore -J - /mnt
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
```

Повторяем действия с загрузчиком:

```
chroot /mnt/
grub2-mkconfig -o /boot/grub2/grub.cfg
cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g;
s/.img//g"` --force; done
```
Можно не перезагружаясь продолжить выполнять следующий шаг.

***Выделить том под /var в зеркало***

На свободных дисках создаем зеркало:

```
pvcreate /dev/sdc /dev/sdd
vgcreate vg_var /dev/sdc /dev/sdd
lvcreate -L 950M -m1 -n lv_var vg_var
```
Создаем на вновь созданном LV файловую систему и перемещаем туда /var:
```
mkfs.ext4 /dev/vg_var/lv_var
mount /dev/vg_var/lv_var /mnt
cp -aR /var/* /mnt/ 
```

Монтируем новую var в каталог /var:

```
umount /mnt
mount /dev/vg_var/lv_var /var
```

Правим fstab для автоматического монтирования /var:
```
echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
```

Перезагружаемся в новую (уменьшенную root):

```
# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol00 253:2    0 37.5G  0 lvm  
sdb                       8:16   0   10G  0 disk 
└─vg_root-lv_root       253:0    0   10G  0 lvm  /
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
sde                       8:64   0    1G  0 disk 

# df -hT
Filesystem                  Type      Size  Used Avail Use% Mounted on
devtmpfs                    devtmpfs  109M     0  109M   0% /dev
tmpfs                       tmpfs     118M     0  118M   0% /dev/shm
tmpfs                       tmpfs     118M  4.6M  113M   4% /run
tmpfs                       tmpfs     118M     0  118M   0% /sys/fs/cgroup
/dev/mapper/vg_root-lv_root xfs        10G  1.4G  8.7G  14% /
/dev/sda2                   xfs      1014M   86M  929M   9% /boot
/vagrant                    vboxsf    477G  110G  367G  24% /vagrant
tmpfs                       tmpfs      24M     0   24M   0% /run/user/1000
```

Удаляем временную Volume Group:

```
lvremove /dev/vg_root/lv_root
vgremove /dev/vg_root
pvremove /dev/sdb
```

***Выделить том под /home, сделать том для снапшотов, восстановиться со снапшота***

Создаем LV размером 2G, на нем создаем файловую систему xfs. 
Монтируем LV в папку /mnt и переносим данные из папки /home на новый LV.
Очищаем папку /home, монтируем новый LV в папку /home.
```
lvcreate -n LogVol_Home -L 2G /dev/VolGroup00
mkfs.xfs /dev/VolGroup00/LogVol_Home
mount /dev/VolGroup00/LogVol_Home /mnt/
cp -aR /home/* /mnt/ 
rm -rf /home/*
umount /mnt
mount /dev/VolGroup00/LogVol_Home /home/
```

Правим fstab для автоматического монтирования /home:

```
echo "`blkid | grep Home | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab
```

```
# cat /etc/fstab -T

#
# /etc/fstab
# Created by anaconda on Sat May 12 18:50:26 2018
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/VolGroup00-LogVol00 /                       xfs     defaults        0 0
UUID=570897ca-e759-4c81-90cf-389da6eee4cc /boot                   xfs     defaults        0 0
/dev/mapper/VolGroup00-LogVol01 swap                    swap    defaults        0 0
#VAGRANT-BEGIN
# The contents below are automatically generated by Vagrant. Do not modify.
vagrant /vagrant vboxsf uid=1000,gid=1000,_netdev 0 0
#VAGRANT-END
UUID="a14883b3-106b-438d-b5c9-a9984a9c5c6d" /var ext4 defaults 0 0
UUID="8ba87846-3bdb-4167-b123-475b3874ef8a" /home xfs defaults 0 0

```

Сгенерируем файлы в /home/:

```
 touch /home/file{1..20}
```

Снимаем снапшот:

```
 lvcreate -L 100MB -s -n home_snap /dev/VolGroup00/LogVol_Home
```

Удаляем часть файлов:

```
rm -f /home/file{11..20}
```

Восстанавливаем файлы со снапшота:

```
umount /home
lvconvert --merge /dev/VolGroup00/home_snap
mount /home
```

Результат:
```
# lsblk
NAME                       MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                          8:0    0   40G  0 disk
├─sda1                       8:1    0    1M  0 part
├─sda2                       8:2    0    1G  0 part /boot
└─sda3                       8:3    0   39G  0 part
  ├─VolGroup00-LogVol00    253:0    0    8G  0 lvm  /
  ├─VolGroup00-LogVol01    253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol_Home 253:7    0    2G  0 lvm  /home
sdb                          8:16   0   10G  0 disk
sdc                          8:32   0    2G  0 disk
├─vg_var-lv_var_rmeta_0    253:2    0    4M  0 lvm
│ └─vg_var-lv_var          253:6    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0   253:3    0  952M  0 lvm
  └─vg_var-lv_var          253:6    0  952M  0 lvm  /var
sdd                          8:48   0    1G  0 disk
├─vg_var-lv_var_rmeta_1    253:4    0    4M  0 lvm
│ └─vg_var-lv_var          253:6    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1   253:5    0  952M  0 lvm
  └─vg_var-lv_var          253:6    0  952M  0 lvm  /var
sde                          8:64   0    1G  0 disk

# df -hT
Filesystem                         Type      Size  Used Avail Use% Mounted on
devtmpfs                           devtmpfs  109M     0  109M   0% /dev
tmpfs                              tmpfs     118M     0  118M   0% /dev/shm
tmpfs                              tmpfs     118M  4.5M  114M   4% /run
tmpfs                              tmpfs     118M     0  118M   0% /sys/fs/cgroup
/dev/mapper/VolGroup00-LogVol00    xfs       8.0G  1.4G  6.7G  18% /
/dev/sda2                          xfs      1014M   86M  929M   9% /boot
/dev/mapper/vg_var-lv_var          ext4      922M  188M  670M  22% /var
/vagrant                           vboxsf    477G  111G  366G  24% /vagrant
/dev/mapper/VolGroup00-LogVol_Home xfs       2.0G   33M  2.0G   2% /home
```