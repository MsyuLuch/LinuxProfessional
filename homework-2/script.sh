#!/bin/bash

# Занулим на всякий случай суперблоки
mdadm --zero-superblock --force /dev/sd{b,c,d,e,f}

# Создаем RAID5 из 5 дисков
mdadm --create --verbose --force /dev/md0 -l 5 -n 5 /dev/sd{b,c,d,e,f}

# Проверяем, что получилось
cat /proc/mdstat
mdadm -D /dev/md0

# Создаем конфигурационный файл mdadm.conf в директории /etc/mdadm/
mkdir /etc/mdadm/
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf

# Заполняем его информацией о созданном RAID5
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf

# с помощью утилиты parted создаем раздел GPT на RAID
parted -s /dev/md0 mklabel gpt

# и делим его на 5 одинаковых партиций
parted /dev/md0 mkpart primary ext4 0% 20%
parted /dev/md0 mkpart primary ext4 20% 40%
parted /dev/md0 mkpart primary ext4 40% 60%
parted /dev/md0 mkpart primary ext4 60% 80%
parted /dev/md0 mkpart primary ext4 80% 100%

# создаем на каждой партиции файловую систему ext4
for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done

# создаем в каталогек raid директории part1, part2..... 5
mkdir -p /raid/part{1,2,3,4,5}

# монтируем созданные партиции md0p1,md0p2.... к каталогам part1.....
for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done

# заносим информацию о вновь созданных разделах в fstab, чтобы после перезагрузки,
# разделы автоматически примонтировались
echo "#RAID" >> /etc/fstab

# UUID="8fc9d795-640d-4886-9ec0-b41583608314" /u01 ext4 defaults 0 0
# UUID уникальный номер каждого раздела
for i in $(seq 1 5); do echo `sudo blkid /dev/md0p$i | awk '{print $2}'` /u0$i ext4 defaults 0 0 >> /etc/fstab; done
