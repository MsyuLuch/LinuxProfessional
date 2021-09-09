# **Домашнее задание №7**

Для выполнения работы потребуются следующие инструменты:

- **VirtualBox** - среда виртуализации, позволяет создавать и выполнять виртуальные машины;
- **Vagrant** - ПО для создания и конфигурирования виртуальной среды. В данном случае в качестве среды виртуализации используется *VirtualBox*; (https://www.vagrantup.com/downloads.html);

# **Цель**
 
## **Работа с загрузчиком**
 
- Попасть в систему без пароля несколькими способами.
- Установить систему с LVM, после чего переименовать VG.
- Добавить модуль в initrd.

# **Исходные данные**

Ссылка на проект https://github.com/MsyuLuch/LinuxProfessional/tree/main/homework-7

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
 2. Установить систему с LVM, после чего переименовать VG
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
- `rn-root-vg.sh` - скрипт для переименования VG основного раздела
 3. Добавить модуль в initrd
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
- `add-module.sh` - скрипт для добавления модуля в initrd

# **Описание процесса выполнения домашнего задания №7**

***1. Сброс пароля пользователя root на CentOS 8***

Включите сервер CentOS.
Когда появится загрузочное меню GRUB, выберите версию ядра, которую вы хотите загрузить, 
и нажмите `e`, чтобы отредактировать выбранную загрузочную запись.
Внесите изменения в загрузочную запись,добавив `rd.break`
Нажмите `Ctrl + x`, чтобы войти в аварийный, однопользовательский режим.
Введите следующую команду для монтирования корневой файловой системы (/) в режиме чтения/записи:
```
mount -o remount,rw /sysroot
```
Перейдите в каталог `/sysroot` и сбросьте пароль `root`.
```
chroot /sysroot/
```
Измените пароль пользователя `root`:
```
passwd root
```
После обновления пароля `root` введите следующую команду, чтобы включить перемаркировку SELinux при перезагрузке:
```
touch /.autorelabel
```
Далее необходимо перезагрузить сервер CentOS в обычном режиме:
```
exit
exit
reboot
```
Дождитесь завершения процесса перемаркировки SELinux.
Это займет некоторое время в зависимости от размера файловой системы и скорости вашего жесткого диска.
После завершения перемаркировки файловой системы вы можете войти на сервер CentOS 8 с новым паролем root!

***2. Установить систему с LVM, переименовать VG***

Запускаем ВМ и проверяем текущие настройки:

```
# lsblk
NAME                   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                      8:0    0   64G  0 disk
└─sda1                   8:1    0   64G  0 part
  ├─vagrant--vg-root   253:0    0   63G  0 lvm  /
  └─vagrant--vg-swap_1 253:1    0  980M  0 lvm  [SWAP]

# vgs
  VG         #PV #LV #SN Attr   VSize   VFree
  vagrant-vg   1   2   0 wz--n- <64.00g    0

```

Выполняем скрипт `rn-root-vg.sh` с правами администратора. Можно перезагрузиться и проверить результат.

***Описание работы скрипта***

Чтобы переименовать VG используем команду
```
vgrename ${oldvg} ${newvg}
```

Необходимо изменить точки монтирования в системе в файле `/etc/fstab` : 
```
sed -i "s/${oldvg}/${newvg}/g" /etc/fstab
sed -i "s/${oldvgdash}/${newvgdash}/g" /etc/fstab
```
Обновим VG в конфигурационных файлах GRUB:
```
sed -i "s/${oldvg}/${newvg}/g" /boot/grub/grub.cfg
sed -i "s/${oldvgdash}/${newvgdash}/g" /boot/grub/grub.cfg

sed -i "s/${oldvg}/${newvg}/g" /boot/grub/menu.lst
sed -i "s/${oldvgdash}/${newvgdash}/g" /boot/grub/menu.lst

sed -i "s/${oldvg}/${newvg}/g" /etc/initramfs-tools/conf.d/resume
sed -i "s/${oldvgdash}/${newvgdash}/g" /etc/initramfs-tools/conf.d/resume
```
Обновим существующий образ ядра с новыми настройками:
```
update-initramfs -c -k all
```
Освободим swap (чтобы можно было перезагрузить систему с новыми параметрами):
```
swapoff -a && swapon -a
```

***3. Добавить модуль в initrd***

dracut - утилита создания initramfs (initial RAM disk image, загружаемый в оперативную память файл с образом файловой системы), используемого при загрузке Linux в качестве первоначальной корневой файловой системы. 

Создаем свою директорию для нового модуля в `/usr/lib/dracut/modules.d/` и добавляем в неё два скрипта `module-setup.sh` и `test.sh`:
```
mkdir /usr/lib/dracut/modules.d/01test
cd /usr/lib/dracut/modules.d/01test
```
```
cat >module-setup.sh<<EOF

#------------------------------------------------
#!/bin/bash

check() {
     return 0
}
depends() {
     return 0
}
install() {
     inst_hook cleanup 00 "/usr/lib/dracut/modules.d/01test/test.sh"
}
#------------------------------------------------
EOF
```

```
cat >test.sh<<EOF
#------------------------------------------------
#!/bin/bash
exec 0<>/dev/console 1<>/dev/console 2<>/dev/console
cat <<'msgend'
 ___________________
< I'm dracut module >
 -------------------
    \
     \
        .--.
       |o_o |
       |:_/ |
      //   \ \
     (|     | )
    /'\_   _/`\
    \___)=(___/
msgend
sleep 10
echo " continuing...."
#------------------------------------------------
EOF
```

Оба скрипта делаем исполняемыми:
```
chmod +x module-setup.sh && chmod +x test.sh
```
Создаем новый initramfs: 
```
dracut -f -v
```
Убедимся что модуль добавлен:
```
lsinitrd -m /boot/initramfs-$(uname -r).img | grep test
```