# **Домашнее задание №19**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **Настройка PXE сервера для автоматической установки**
 
Цель:
Отрабатываем навыки установки и настройки DHCP, TFTP, PXE загрузчика и автоматической загрузки

- Следуя шагам из документа https://docs.centos.org/en-US/8-docs/advanced-install/assembly_preparing-for-a-network-install 
установить и настроить загрузку по сети для дистрибутива CentOS8. 
- В качестве шаблона воспользуйтесь репозиторием https://github.com/nixuser/virtlab/tree/main/centos_pxe.
- Поменять установку из репозитория NFS на установку из репозитория HTTP.
- Настроить автоматическую установку для созданного kickstart файла (*) Файл загружается по HTTP.

Формат сдачи ДЗ - vagrant + ansible

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `VagrantFile` - файл описывающий виртуальную инфраструктуру для `Vagrant`

# **Описание процесса выполнения домашнего задания №19**

PXE (Preboot Execution Environment) — инструмент для установки ОС по сети без использования локальных носителей данных.
Системы будут загружаться при помощи PXE с использованием загрузочного образа, расположенного на сервере. 

- Настроим NGINX, на котором будут размещаться установочные файлы.
В конфигурационном файле `/etc/nginx/nginx.conf` заменим путь до директории, в которой будут 
расположены файлы для установки ОС:  
```
root /mnt;
``` 
- Установим и настроим DHCP. Изменим конфигурационный файл и запустим DHCP сервер:
```
subnet 10.0.0.0 netmask 255.255.255.0 {
	#option routers 10.0.0.254;
	range 10.0.0.100 10.0.0.120;
	class "pxeclients" {
	  match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
	  next-server 10.0.0.20;
	  if option architecture-type = 00:07 {
	    filename "uefi/shim.efi";
	    } else {
	    filename "pxelinux/pxelinux.0";
	  }
	}
}
```
- Установим и настроим TFTP сервер.
- Настроим PXE-загрузку

В `tftpboot/` создадим каталог `pxelinux/` и скопируйте в него необходимые файлы:
```
pxelinux.0
libutil.c32
menu.c32
libmenu.c32
ldlinux.c32
vesamenu.c32
```

Добавим файл конфигурации в `pxelinux/`. Имя файла может быть определено как default. Например `/var/lib/tftpboot/pxelinux/default`
```
     default menu
        prompt 0
        timeout 600
        MENU TITLE Demo PXE setup
        LABEL linux
          menu label ^Install system
          kernel images/CentOS-7/vmlinuz
          append initrd=images/CentOS-7/initrd.img ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos7-install
        LABEL linux-auto
          menu label ^Auto install system
          menu default
          kernel images/CentOS-7/vmlinuz
          append initrd=images/CentOS-7/initrd.img ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos7-install inst.ks=http://10.0.0.20/ks.cfg
        LABEL vesa
          menu label Install system with ^basic video driver
          kernel images/CentOS-7/vmlinuz
          append initrd=images/CentOS-7/initrd.img ip=dhcp inst.xdriver=vesa nomodeset
        LABEL rescue
          menu label ^Rescue installed system
          kernel images/CentOS-7/vmlinuz
          append initrd=images/CentOS-7/initrd.img rescue
        LABEL local
          menu label Boot from ^local drive
          localboot 0xffff
```

![Menu PXE](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-19/images/menu.jpg)

Для загрузки программы установки используется параметр:
```
inst.repo= (параметр Anaconda). Позволяет загрузить программу установки и настроить источник установки
```

Скопируем загрузочные образы в tftp/:
```
cp /путь/x86_64/os/images/pxeboot/{vmlinuz,initrd.img} /var/lib/tftpboot/pxelinux/
```
Для автоматической установки понадобиться kickstart файл, который представляет собой простой текстовый файл, 
содержащий список параметров установки.

После этого сервер PXE будет готов к установке. 
Запускаем `pxeclient` и проверяем.

![Install](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-19/images/install.jpg)
