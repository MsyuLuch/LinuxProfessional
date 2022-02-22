# **Проект**

🔖Итоговый проект курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

Создание рабочего проекта
веб проект с развертыванием нескольких виртуальных машин должен отвечать следующим требованиям:

- включен https;
- основная инфраструктура в DMZ зоне;
- firewall на входе;
- сбор метрик и настроенный alerting;
- везде включен selinux;
- организован централизованный сбор логов.

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`

# **Описание процесса выполнения**

![schema](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-27/images/schema.jpg)

Проект состоит из 6 виртуальных машин:
- proxy
- web
- mysql primary
- mysql secondary
- monitoring
- elk

На всех машинах установлен Centos 7, включен SELinux, firewall.

В качестве web-проекта выбран Wordpress — свободно распространяемая система управления содержимым сайта с открытым исходным кодом; написана на PHP; сервер базы данных — MySQL.

<details><summary>**Настройка SELinux и Firewalld**</summary>

Команды для проверки работы SELinux:
```
Посмотреть состояние работы SELinux (развернуто):
# sestatus

Посмотреть кратко — работает или нет:
# getenforce
```

На веб-сервере разрешаем подключение к базе данных MySQL
```
- name: setsebool httpd_can_network_connect_db
  shell: setsebool -P httpd_can_network_connect_db 1 
```

Общие команды для управления firewalld:
```
Посмотреть состояние:
firewall-cmd --state
systemctl status firewalld

Мягко перечитать правила (применить настройки):
firewall-cmd --reload

Посмотреть созданные правила:
firewall-cmd --list-all
```

На каждой машине, в соответствии с её функциональностью перед началом установки необходимых пакетов, открываем порты или разрешаем работу соответствующих сервисов:
```
- name: Open Firewall for services (MySQL, NFS)
  firewalld:
    service: "{{ item }}"
    permanent: yes
    state: enabled
  with_items:
    - mysql
    - nfs
    - mountd
    - rpc-bind  
```
```
- name: Open Firewall ports (Prometheus)
  block:
    - name: Allow Ports
      firewalld:
        port: "{{ item }}"
        permanent: true
        state: enabled
      loop: [ '9090/tcp', '9093/tcp', '9094/tcp', '9100/tcp', '9094/udp' ]
```

</details>

<details><summary>**Установка и настройка MySQL**</summary>

Развернем два сервера баз данных: primary и secondary. Настроим между ними репликацию.
Подключаем репозиторий `https://repo.mysql.com/` и устанавливаем MySQL 8.0

Чтобы настроить репликацию меняем id сервера и включаем режим `gtid_mode = ON` (глобальные идентификаторы транзакции).
Конфигурационные файлы обоих серверов соответственно:
primary
```
[mysqld]
bind-address = {{ master_server_ip }}

gtid_mode = ON
enforce-gtid-consistency = ON

server-id = 1

log_bin = mysql-bin
log-error=/var/log/mysqld.log

replicate-do-db=wordpress
```

secondary
```
[mysqld]
bind-address = {{ replica_server_ip }}

gtid_mode = ON
enforce-gtid-consistency = ON

server-id = 2
```

</details>

<details><summary>**Установка Wordpress**</summary>

### ***Настройка Proxy***

![Как создать надежный SSL-сертификат для локальной разработки] (https://medium.com/nuances-of-programming/%D0%BA%D0%B0%D0%BA-%D1%81%D0%BE%D0%B7%D0%B4%D0%B0%D0%B2%D0%B0%D1%82%D1%8C-%D0%BD%D0%B0%D0%B4%D0%B5%D0%B6%D0%BD%D1%8B%D0%B5-ssl-%D1%81%D0%B5%D1%80%D1%82%D0%B8%D1%84%D0%B8%D0%BA%D0%B0%D1%82%D1%8B-%D0%B4%D0%BB%D1%8F-%D0%BB%D0%BE%D0%BA%D0%B0%D0%BB%D1%8C%D0%BD%D0%BE%D0%B9-%D1%80%D0%B0%D0%B7%D1%80%D0%B0%D0%B1%D0%BE%D1%82%D0%BA%D0%B8-8f73f76df3d4)

Воспользуемся инструкцией и создадим самоподписанный SSL сертификат для настройки HTTPS соединения между Пользователями - Proxy - Web.
Файлы сертификата (`localhost.crt`, `localhost.key`) разместим в директориях NGINX `/etc/nginx/ssl` и Apache `/etc/httpd/ssl` соответственно.
NGINX будет слушать на порту 80 и 443, перенаправляя весь трафик на 443 порт (https):
```
server {
        listen 80;
        return 301 https://{{ virtual_domain }}$request_uri;
        }

server {
        listen 443 ssl;

        server_name {{ virtual_domain }};

        # Указываем пути к сертификатам
        ssl_certificate /etc/nginx/ssl/localhost.crt; 
        ssl_certificate_key /etc/nginx/ssl/localhost.key;

        access_log /var/log/nginx/{{ virtual_domain }}_access.log;
        error_log /var/log/nginx/{{ virtual_domain }}_error.log;  

        location / {
                proxy_pass https://{{ web_server_ip }};
                proxy_set_header Host $host;
                proxy_set_header X-Forwarded-Proto https;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header X-Forwarded-Port 443;
                proxy_set_header Proxy "";
        }
}    
``` 

### ***Настройка Apache***

Настроим виртуальный хост Apache на работу по протоколу https:
```
<VirtualHost *:80 *:443>
   ServerAdmin webmaster@localhost
   ServerName {{ http_host }}
   DocumentRoot {{ wordpress_directory }}
   ErrorLog /var/log/httpd/{{ http_host }}_error.log
   CustomLog /var/log/httpd/{{ http_host }}_access.log combined

   <Directory {{ wordpress_directory }}>
     Options Indexes FollowSymLinks
     AllowOverride all
     Require all granted
   </Directory>
</VirtualHost>
```

### ***Настройка Wordpress***
Скачиваем с официального сайта wordpress последнюю версию проекта, разархивируем файлы в рабочую директорию.
До начала работы проекта, необходимо создать базу данных `Wordpress`.

В конфигурационный файл wordpress `wp-config.php` добавим строки, определяющие работу по https протоколу:
```
if($_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https'){

    $_SERVER['HTTPS'] = 'on';
        $_SERVER['SERVER_PORT'] = 443;
        }

define('WP_HOME','https://{{ virtual_domain }}/');
define('WP_SITEURL','https://{{ virtual_domain }}/');
``` 

</details>

