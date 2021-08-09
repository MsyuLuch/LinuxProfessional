# **Домашнее задание №2**

Выполнение действий приведенных в методичке позволит познакомиться с такими инструментами, как `Vagrant` и `Packer`, получить базовые навыки работы с системами контроля версий (`Github`). Получить навыки создания кастомных образов виртуальных машин, обновлению ядра системы из репозитория и основам распространения образов через репозиторий `Vagrant Cloud`.

Для выполнения работы потребуются следующие инструменты:

- **VirtualBox** - среда виртуализации, позволяет создавать и выполнять виртуальные машины;
- **Vagrant** - ПО для создания и конфигурирования виртуальной среды. В данном случае в качестве среды виртуализации используется *VirtualBox*; (https://www.vagrantup.com/downloads.html)
- **mdadm** - утилита для работы с программными RAID-массивами различных уровней; 
- **Git** - система контроля версий

- **Ссылка на репозиторий** - https://github.com/
- **Vagrant Cloud** - https://app.vagrantup.com

# **Цель**
 
Результатом данной работы будет создание кастомного образа centos/7 с обновленным ядром и его публикация в Vagrant Cloud.
 
# **Исходные данные**

Ссылка на проект https://github.com/MsyuLuch/LinuxProfessional/tree/main/homework-1

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`

Ссылка на обновленный образ в Vagrant Cloud https://app.vagrantup.com/MsyuLuch/boxes/centos-7-5

---
# **Описание процесса выполнения домашнего задания №1**

# **1. Kernel update**

### **1.1 Клонирование и запуск**

Клонируем репозиторий:
```
git clone https://github.com/dmitry-lyutenko/manual_kernel_update
```
Здесь:
- `manual` - директория с руководством по выполнению домашнего задания
- `packer` - директория со скриптами для `packer`'а
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`

Запускаем виртуальную машину и логинимся:
```
vagrant up
vagrant ssh
```

### **1.2 kernel update**

Подключаем репозиторий, для обновления ядра.
```
sudo yum install -y http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
```

В репозитории есть две версии ядер:
 - `kernel-ml` - наиболее свежая стабильная версия.
 - `kernel-lt` - стабильная версия с длительной поддержкой, но менее свежая, чем первая.

Ставим последнее ядро:
```
sudo yum --enablerepo elrepo-kernel install kernel-ml -y
```

### **1.3 grub update**

Обновляем конфигурацию загрузчика:
```
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```
Выбираем загрузку с новым ядром по-умолчанию:
```
sudo grub2-set-default 0
```
Перезагружаем виртуальную машину:
```
sudo reboot
```
Проверяем версию ядра:
```
uname -r
```

---

# **2. Packer**

### **2.1 packer build**
Создаем свой образ системы, с уже установленым ядром 5й версии.
В директории `packer` выполняем команду:
```
packer build centos.json
```

### **2.2 vagrant init (тестирование)**
Импортируем образ в `vagrant`:
```
vagrant box add --name centos-7-5 centos-7.7.1908-kernel-5-x86_64-Minimal.box
```
Проверияем его в списке имеющихся образов:
```
vagrant box list
centos-7-5            (virtualbox, 0)
```
Создаем новый Vagrantfile, можно использовать имеющийся. 
```
vagrant init centos-7-5
```
Запускаем виртуальную машину, подключаемся к ней и проверяем версию ядра:

```
vagrant up
vagrant ssh    
uname -r
```
Удаляем тестовый образ из локального хранилища:
```
vagrant box remove centos-7-5
```
---
# **3. Vagrant cloud**

Логинимся в `vagrant cloud`:
```
vagrant cloud auth login
Vagrant Cloud username or email: <user_email>
Password (will be hidden): 
Token description (Defaults to "Vagrant login from DS-WS"):
You are now logged in.
```
Публикуем полученный бокс:
```
vagrant cloud publish --release <username>/centos-7-5 1.0 virtualbox \
        centos-7.7.1908-kernel-5-x86_64-Minimal.box
```
Здесь:
 - `cloud publish` - загрузить образ в облако;
 - `release` - указывает на необходимость публикации образа после загрузки;
 - `<username>/centos-7-5` - `username`, указаный при публикации и имя образа;
 - `1.0` - версия образа;
 - `virtualbox` - провайдер;
 - `centos-7.7.1908-kernel-5-x86_64-Minimal.box` - имя файла загружаемого образа;
