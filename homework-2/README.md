# **Домашнее задание №2**

Выполнение действий приведенных в методичке позволит познакомиться с такими инструментами, как `Vagrant` и `Packer`, получить базовые навыки работы с системами контроля версий (`Github`). Получить навыки создания кастомных образов виртуальных машин, обновлению ядра системы из репозитория и основам распространения образов через репозиторий `Vagrant Cloud`.

Для выполнения работы потребуются следующие инструменты:

- **VirtualBox** - среда виртуализации, позволяет создавать и выполнять виртуальные машины;
- **Vagrant** - ПО для создания и конфигурирования виртуальной среды. В данном случае в качестве среды виртуализации используется *VirtualBox*; (https://www.vagrantup.com/downloads.html)
- **mdadm** - утилита для работы с программными RAID-массивами различных уровней; 
- **Git** - система контроля версий

# **Цель**
 
Работа с mdadm:

- добавить в Vagrantfile еще дисков;
- сломать/починить raid;
- собрать R0/R5/R10 на выбор;
- прописать собранный рейд в конф, чтобы рейд собирался при загрузке;
- создать GPT раздел и 5 партиций.
 
# **Исходные данные**

Ссылка на проект https://github.com/MsyuLuch/LinuxProfessional/tree/main/homework-2

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant` (сразу собирает систему с подключенным рейдом и смонтированными разделами)
- `Script.sh` - скрипт для создания рейда, конф для автосборки рейда при загрузке

---
# **Описание процесса выполнения домашнего задания №2**

Добавим в VagrantFile 5 дисков для сборки RAID5:

```
:disks => {
        :sata1 => {
            :dfile => './sata1.vdi',
            :size => 250,
            :port => 1
        },
        :sata2 => {
            :dfile => './sata2.vdi',
            :size => 250,
            :port => 2
        },
        :sata3 => {
            :dfile => './sata3.vdi',
            :size => 250,
            :port => 3
        },
        :sata4 => {
            :dfile => './sata4.vdi',
            :size => 250,
            :port => 4
        },
      :sata5 => {
            :dfile => './sata5.vdi',
            :size => 250,
            :port => 5
        }
```

Запускаем виртуальную машину и логинимся:
```
vagrant up
vagrant ssh
```

Утилиты mdadm, smartmontools, hdparm, gdisk ставятся автоматически при старте ВМ:
```
box.vm.provision "shell", inline: <<-SHELL
	      mkdir -p ~root/.ssh
              cp ~vagrant/.ssh/auth* ~root/.ssh
	      yum install -y mdadm smartmontools hdparm gdisk
  	  SHELL
```
Занулим на всякий случай суперблоки:
```
mdadm --zero-superblock --force /dev/sd{b,c,d,e,f}
```
Создаем RAID5 ( Опция -l):
```
mdadm --create --verbose /dev/md0 -l 5 -n 5 /dev/sd{b,c,d,e,f}
```
Проверяем собранный RAID5:
```
cat /proc/mdstat
mdadm -D /dev/md0
```
Создаем конфигурационный файл mdadm.conf:
```
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
```
С помощью утилиты parted создаем раздел GPT на RAID:
```
parted -s /dev/md0 mklabel gpt
```
Делим его на 5 одинаковых разделов:
```
parted /dev/md0 mkpart primary ext4 0% 20%
parted /dev/md0 mkpart primary ext4 20% 40%
parted /dev/md0 mkpart primary ext4 40% 60%
parted /dev/md0 mkpart primary ext4 60% 80%
parted /dev/md0 mkpart primary ext4 80% 100%
```
Cоздаем файловые системы ext4 на каждом разделе:
```
for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
```
Монтируем их по каталогам:
```
mkdir -p /raid/part{1,2,3,4,5}
 for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
```
Заносим информацию о вновь созданных разделах в fstab, чтобы после перезагрузки, разделы автоматически примонтировались:
```
echo "#RAID" >> /etc/fstab
for i in $(seq 1 5); do echo `sudo blkid /dev/md0p$i | awk '{print $2}'` /u0$i ext4 defaults 0 0 >> /etc/fstab; done
```
В результате в файле /ect/fstab будут строки следующего вида:
```
UUID="8fc9d795-640d-4886-9ec0-b41583608314" /u01 ext4 defaults 0 0
```
где UUID уникальный номер каждого раздела

Если всё прошло удачно собираем все действия по созданию RAID5 и разделов в скрипт https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-2/script.sh

Проверяем работу скрипта на ВМ собранной с нуля, с помощью VagrantFile https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-2/VagrantFile

Теперь можно перенести команды по созданию RAID5 в VagrantFile:
```
       box.vm.provision "shell", inline: <<-SHELL
            mkdir -p ~root/.ssh
                cp ~vagrant/.ssh/auth* ~root/.ssh
            yum install -y mdadm smartmontools hdparm gdisk
            mdadm --zero-superblock --force /dev/sd{b,c,d,e,f}
            mdadm --create --verbose --force /dev/md0 -l 5 -n 5 /dev/sd{b,c,d,e,f}
            cat /proc/mdstat
            mkdir /etc/mdadm/
            echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
            mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
            parted -s /dev/md0 mklabel gpt
            parted /dev/md0 mkpart primary ext4 0% 20%
            parted /dev/md0 mkpart primary ext4 20% 40%
            parted /dev/md0 mkpart primary ext4 40% 60%
            parted /dev/md0 mkpart primary ext4 60% 80%
            parted /dev/md0 mkpart primary ext4 80% 100%
            for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
            mkdir -p /raid/part{1,2,3,4,5}
            for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
            echo "#RAID" >> /etc/fstab
            for i in $(seq 1 5); do echo `sudo blkid /dev/md0p$i | awk '{print $2}'` /u0$i ext4 defaults 0 0 >> /etc/fstab; done
            sed -i '65s/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
            systemctl restart sshd
        SHELL
```
ссылка на новый Vagrantfile https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-2/new/VagrantFile
