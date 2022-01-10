# **Домашнее задание №26**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **Развертывание веб приложения**
 
Варианты стенда:

1. nginx + php-fpm (laravel/wordpress) + python (flask/django) + js(react/angular);
2. nginx + java (tomcat/jetty/netty) + go + ruby;
3. можно свои комбинации.

Реализации на выбор:
1. на хостовой системе через конфиги в /etc;
2. деплой через docker-compose.

К сдаче принимается:
- vagrant стэнд с проброшенными на локалхост портами
- каждый порт на свой сайт
- через NGINX

Формат сдачи ДЗ - vagrant + ansible

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `VagrantFile` - файл описывающий виртуальную инфраструктуру для `Vagrant`

# **Описание процесса выполнения домашнего задания №26**

Проверим работу стендов:
```
http://10.0.0.100:8080  PHP-FPM
http://10.0.0.100:8081  DJANGO
http://10.0.0.100:8082  NodeJS
```
![PHP-FPM](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-26/image/php-fpm.png)
![DJANGO](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-26/image/django.png)
![NODEJS](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-26/image/nodejs.png)

Установим NGINX, он позволит проксировать запросы от пользователя, направляя их на разные backend`s. Добавим в конфигурацию NGINX дополнительные файлы для каждого стенда.

PHP-FPM будет слушать на localhost порт 9000:
```
        location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include /etc/nginx/fastcgi_params;
        } 
```
DJANGO будет слушать сокет `uwsgi`:
```
        location / {
            include uwsgi_params;
        uwsgi_pass unix:/run/uwsgi/firstsite.sock;
        } 
```
NODEJS будет слушать на localhost порт 8000:
```
        location / {
            proxy_pass http://localhost:8000;
        } 
```

***Первый стенд - PHP-FPM***

PHP-FPM — это альтернативная реализация PHP FastCGI с несколькими дополнительными возможностями, которые обычно используются для высоконагруженных сайтов.

Создадим директорию `/var/www/php-fpm` и поместим в неё файл `index.php` со следующим содержимым:
```
<?php phpinfo() ?>
```

Установим php-fpm и необходимые для его работы пакеты:
```
- name: Install packages for php-fpm
  yum:
    name:
      - php
      - php-fpm 
      - php-cli
      - php-json
      - php-pdo 
      - php-mysql
      - php-zip
      - php-gd 
      - php-mbstring
      - php-curl
      - php-xml
      - php-pear
      - php-bcmath
    state: present 
```

Запускаем php-fpm:
```
systemctl start php-fpm
```
Можно проверять работу стенда.

***Второй стенд - Django***

Django — это высокоуровневый веб-фреймворк Python с открытым исходным кодом, предназначенный для помощи разработчикам в создании безопасных, масштабируемых и поддерживаемых веб-приложений.

Установим Python 3.6 и необходимые для работы пакеты из репозитория `IUS`, для этого предварительно подключим репозиторий: 
```
- name: Add repository repo.ius.io
  yum:
    name: https://repo.ius.io/ius-release-el7.rpm
    state: present

- name: Install Python from IUS
  yum:
    name: ['python36u', 'python36u-pip', 'python36u-devel']
    state: present
```

Создадим ссылки на pyton3 и pip3, с помощью менеджера пакетов pip установим Django:
```
pip3 install Django==2.1.*  
```

Чтобы создать новый проект Django с именем firstsite используем утилиту командной строки django-admin:
```
/usr/local/bin/django-admin startproject firstsite
```

Приведенная выше команда создаст каталог firstsite в текущем каталоге:
```
firstsite/
|-- manage.py
`-- firstsite
    |-- __init__.py
    |-- settings.py
    |-- urls.py
    `-- wsgi.py
```
Внутри этого каталога есть основной скрипт для управления проектами с именем manage.py и каталог, включающий конфигурацию базы данных, а также настройки для конкретного приложения. Отредактируем файл с настройками settings.py,
добавив IP нашего хоста:
```
ALLOWED_HOSTS = ['10.0.0.100']
```

Теперь нужно настроить uWSGI – сервер приложений, взаимодействующий с приложениями с помощью простого интерфейса WSGI.
Теперь установим uWSGI:
```
sudo pip3 install uwsgi
```
Запустим сервер в режиме Emperor mode, что позволит ведущему процессу управлять отдельными приложениями автоматически. 
Создадим конфигурационный файл `/etc/uwsgi/sites/firstsite.ini`:
```
[uwsgi]
project = firstsite
username = django
base = /var/www/%(username)
chdir = %(base)/%(project)
module = %(project).wsgi:application
master = true
processes = 5
uid = %(username)
socket = /run/uwsgi/%(project).sock
chown-socket = %(username):nginx
chmod-socket = 660
vacuum = true
daemonize=/var/log/uwsgi/firstsite.log
```

В файле опишем несколько переменных, чтобы сделать файл более универсальным:
```
project - имя проекта
username - имя пользователя, от имени которого запускается проект
base - путь к домашнему каталогу
chdir - изменяет корневой каталог проекта 
module - импортируем callable application из файла wsgi.py в каталоге проекта
processes - cоздает главный процесс с 5 рабочими процессами
socket - прослушивать будем сокет, на который установим права для пользователя
vacuum - опция автоматически очистит файл сокета после остановки сервиса
```

Django-проекты обслуживаются сервером приложений. Теперь нужно автоматизировать этот процесс. Для этого создадим unit-файл:
```
[Unit]
Description=uWSGI Emperor service
[Service]
ExecStartPre=/usr/bin/bash -c 'mkdir -p /run/uwsgi; chown django:nginx /run/uwsgi'
ExecStart=/usr/local/bin/uwsgi --emperor /etc/uwsgi/sites
Restart=always
KillSignal=SIGQUIT
Type=notify
NotifyAccess=all
[Install]
WantedBy=multi-user.target
```

Директива `ExecStartPre` запускает указанные в ней компоненты. В данном случае она создаст каталог `/run/uwsgi`, принадлежащий текущему пользователю. Директива `ExecStart` запускает сервис, в данном случае `/usr/local/bin/uwsgi` 
в режиме `Emperor mode`.

Запустим сервис:
```
sudo systemctl start uwsgi
```
Можно проверять работу стенда.

***Третий стенд - NodeJS***

Node или Node.js — программная платформа, основанная на движке V8, превращающая JavaScript из узкоспециализированного языка в язык общего назначения.

Добавим репозиторий NodeSource, текущая версия LTS Node.js - версия 14.x.:
```
curl -sL https://rpm.nodesource.com/setup_14.x | bash -
```

Установим Node.js и npm:
```
sudo yum install nodejs
```

Создадим простое приложение Node.js (hello.js), приложение будет слушать заданный адрес (localhost) и порт (8000) и возвращать фразу `Hello World` с HTTP-кодом 200:
```
var http = require('http');
http.createServer(function (req, res) {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('Hello World\n');
}).listen(8000, '127.0.0.1');
console.log('Server running at http://localhost:8000/');
```

Теперь нужно установить PM2. Это менеджер процессов Node.js. PM2 предоставляет простой способ управления и демонизации приложений.
Установку можно выполнить при помощи пакетного менеджера npm на сервере app:
```
sudo npm install pm2@latest -g
```

Запустим приложение:
```
pm2 start hello.js
```

PM2 автоматически устанавливает App name (имя файла без расширения .js) и PM2 id. Также PM2 предоставляет другую информацию: PID процесса, текущее состояние, использование памяти.
Запущенное с помощью PM2 приложение будет автоматически перезапускаться в случае ошибок или сбоев, однако автоматический запуск приложения нужно настроить отдельно. Для этого существует подкоманда startup.
Эта команда генерирует и настраивает сценарий запуска менеджера PM2 и всех его процессов вместе с загрузкой сервера. Также нужно указать платформу (в данном случае это systemd).
```
sudo pm2 startup systemd
```

Можно проверять работу стенда.