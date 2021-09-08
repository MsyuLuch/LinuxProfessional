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
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
- `build.sh` - скрипт сборки пакета и создания репозитория
- `nginx.spec` - отредактированный spec-файл

# **Описание процесса выполнения домашнего задания №7**

***1. Сброс пароля пользователя root на CentOS 8***

Включите сервер CentOS.
Когда появится загрузочное меню GRUB, выберите версию ядра, которую вы хотите загрузить, 
и нажмите `e`, чтобы отредактировать выбранную загрузочную запись.
Замените параметр `ro` на `rw init=/sysroot/bin/sh`
Нажмите `Ctrl + x`, чтобы войти в аварийный, однопользовательский режим.
Введите следующую команду для монтирования корневой файловой системы (/) в режиме чтения/записи:
```
chroot /sysroot/
```
Измените пароль пользователя root:
```
passwd root
```
После обновления пароля root введите следующую команду, чтобы включить перемаркировку SELinux при перезагрузке:
```
touch /.autorelabel
```
Далее необходимо перезагрузить сервер CentOS в обычном режиме:
```
exit
reboot
```
Дождитесь завершения процесса перемаркировки SELinux.
Это займет некоторое время в зависимости от размера файловой системы и скорости вашего жесткого диска.
После завершения перемаркировки файловой системы вы можете войти на сервер CentOS 8 с новым паролем root!

https://voxlink.ru/kb/linux/kak-sbrosit-zabytyj-parol-root-v-rhel-centos-i-fedora/
https://vk.com/@over_view-sbros-parolya-polzovatelya-root-v-centos-8-rhel-8

***2. Установить систему с LVM, переименовать VG***
https://forums.centos.org/viewtopic.php?f=47&t=62406&sid=dae6bd2fb670ad27853db2a817bbe532&start=10
https://qastack.ru/ubuntu/765058/how-do-you-rename-the-volume-group-that-contains-the-root-volume-in-lvm
https://unix.stackexchange.com/questions/574181/lvm-renaming-a-volume-group-and-ensuring-system-can-boot
https://stackoverflow.com/questions/49822594/vagrant-how-to-specify-the-disk-size
https://www.atktng.dev/en/post/vagrant-extend-disksize/
https://medium.com/@kanrangsan/how-to-automatically-resize-virtual-box-disk-with-vagrant-9f0f48aa46b3

```
vgrename /dev/vg02 /dev/my_volume_group

clear;echo '';echo "    Change Volume Group name...";echo '';old_name=$(vgs --noheadings -o vg_name | tr -d '  '); echo "    Current VG name: ${old_name}"; echo -n "    Enter a new VG name (leave blank to quit, no changes) > ";read new_name; if [ "${new_name}" = "" ] || [ "${new_name}" = "${old_name}" ]; then echo -e "\n    Nothing to do, quitting...\n";else echo -n "    Make backup of \"initramfs-$(uname -r).img\" [Y|n]: "; read bak; if [ "${bak}" = "y" ] || [ "${bak}" = "Y" ] || [ "${bak}" = "" ]; then cp /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.bak;fi; echo -e "\n\n"; vgrename -v $old_name $new_name; sed -i "s/\/${old_name}-/\/${new_name}-/g" /etc/fstab; echo '    '; sed -i "s/\([/=]\)${old_name}\([-/]\)/\1${new_name}\2/g" /boot/grub2/grub.cfg; dracut -f -v /boot/initramfs-$(uname -r).img $(uname -r);  echo ""; echo "    Done..."; echo "    A reboot is required.  Scan the above output before continuing."; echo -e "    Brought to you by ITI Studios http://CanadianDomainRegistry.ca\n";  echo -n "    Reboot now [Y|n] >"; read reboot; if [ "${reboot}" = "y" ] || [ "${reboot}" = "Y" ] || [ "${reboot}" = "" ]; then systemctl reboot -f; else echo "";echo "    *You must reboot to save these settings, at the prompt enter: systemctl reboot -f"; echo "";fi;fi;  # End of script

vgrename -v $old_name $new_name;
sed -i "s/\/${old_name}-/\/${new_name}-/g" /etc/fstab;
sed -i "s/\([/=]\)${old_name}\([-/]\)/\1${new_name}\2/g" /boot/grub2/grub.cfg;
dracut -f -v /boot/initramfs-$(uname -r).img $(uname -r);
systemctl reboot -f;
```
***3. Добавить модуль в initrd***