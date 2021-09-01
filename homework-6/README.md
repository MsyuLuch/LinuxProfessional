# **Домашнее задание №6**

Для выполнения работы потребуются следующие инструменты:

- **VirtualBox** - среда виртуализации, позволяет создавать и выполнять виртуальные машины;
- **Vagrant** - ПО для создания и конфигурирования виртуальной среды. В данном случае в качестве среды виртуализации используется *VirtualBox*; (https://www.vagrantup.com/downloads.html);

# **Цель**
 
## **Собрать свой RPM пакет и разместить его в своем репозитории**
 
- создать свой RPM;
- создать свой репозиторий и разместить там свой RPM;
- реализовать это все в Vagrant.

# **Исходные данные**

Ссылка на проект https://github.com/MsyuLuch/LinuxProfessional/tree/main/homework-6

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
- `build.sh` - скрипт сборки пакета и создания репозитория
- `nginx.spec` - отредактированный spec-файл

Краткая инструкция для запуска проекта:
1. Поднимаем виртуальную машину. 
2. Меняем пользователя на root. 
3. Из домашнего каталога root запускаем скрипт build.sh.

# **Описание процесса выполнения домашнего задания №6**
Устанавливаем инструменты необходимые для сборки проекта:
```
yum install -y \
redhat-lsb-core \
wget \
rpmdevtools \
rpm-build \
createrepo \
yum-utils \
openssl-devel \
zlib-devel \ 
pcre-devel
```

Скачиваем и разархивируем исходники последнего `openssl`:
```
wget https://www.openssl.org/source/latest.tar.gz && tar -xvf latest.tar.gz
```

Подготавливаем дерево каталогов для сборки пакета в домашней директории:
```
rpmdev-setuptree
```

Скачиваем src-пакета NGINX и устанавливаем.

Для установки собранного пакета вводим команду:
  `rpm -Uvh <путь до собранного пакета>`:
  
  U — обновить, если пакет уже установлен в системе.
  
  v — вывод информации о ходе процесса.
  
  h — показывать статус установки.
```
wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.14.1-1.el7_4.ngx.src.rpm \
&& rpm -Uvh nginx-1.14.1-1.el7_4.ngx.src.rpm
```

Заменим spec файл на свой откорректированный:
```
wget https://raw.githubusercontent.com/MsyuLuch/LinuxProfessional/main/homework-6/nginx.spec \
&& mv -f nginx.spec rpmbuild/SPECS/nginx.spec
```

Собираем установочный RPM-пакет:
```
rpmbuild -bb rpmbuild/SPECS/nginx.spec
```

Установим собранный пакет:
```
yum localinstall -y rpmbuild/RPMS/x86_64/nginx-1.14.1-1.el7_4.ngx.x86_64.rpm
```

Запускаем nginx и добавляем его в автозагрузку:
```
systemctl start nginx && systemctl enable nginx
```

Создаем директорию, где будет расположен наш репозиторий и переносим в неё собранный пакет NGINX:
```
mkdir /usr/share/nginx/html/repo \
&& cp rpmbuild/RPMS/x86_64/nginx-1.14.1-1.el7_4.ngx.x86_64.rpm /usr/share/nginx/html/repo/
```

Выполняем команду создания репозитория в созданной директории:
```
createrepo /usr/share/nginx/html/repo/
```

Добавляем в конфиг файл NGINX строку `autoindex on;` и перезагружаем NGINX:
```
sed -i 's/location \/ {/location \/ {\n autoindex on;/g' /etc/nginx/conf.d/default.conf
nginx -s reload
```

Проверяем доступ к репозиторию:
```
curl -a http://localhost/repo/
```

Добавляем ссылку на наш репозиторий и проверяем его доступность командой `yum repolist enabled`:
```
cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF

yum repolist enabled | grep otus
```



