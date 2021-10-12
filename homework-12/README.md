# **Домашнее задание №12**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **Инициализация системы. Systemd.**
 
Выполнить следующие задания и подготовить развёртывание результата выполнения с использованием Vagrant и Vagrant shell provisioner (или Ansible, на Ваше усмотрение):
  
 1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig).
 2. Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi).
 3. Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами.

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
--------------------------------------------------

- `script.sh` - скрипт, который ищет фразу в log-файле
- `checklog` - файл с параметрами запуска скрипта
- `checklog.service` - сервис для запуска скрипта 
- `checklog.timer` -  unit модуль для запуска сервиса checklog по расписанию
----------------------------------------------------

- `spawn-fcgi.service` - unit модуль для запуска сервиса spawn-fcgi
- `spawn-fcgi` - файл с параметрами запуска spawn-fcgi
----------------------------------------------------

- `httpd@.service` - unit модуль для запуска сервисов httpd@
- `apache1.conf` - конфигурационный файл Apache для первого инстанса
- `apache2.conf` - конфигурационный файл Apache для второго инстанса

# **Описание процесса выполнения домашнего задания №12**

# ***Создание сервиса мониторинга log-файла***

Опишем скрипт для мониторинга log-файла на поиск конкретной фразы `script.sh`
```
#!/bin/bash

# файл с параметрами, необходимыми для запуска скрипта
# STRING - искомое слово
# FILENAME - log-файл, в котором будем искать
. /etc/sysconfig/checklog

# текущая дата
DATE=`date`

# проверяем заполненность параметров
if [[ ! "$STRING" ]]; then
    logger $DATE : "STRING param is FULL (/etc/sysconfig/checklog)"
    exit 0
fi

if [[ ! "$FILENAME" ]]; then
    logger $DATE : "FILENAME is FULL (/etc/sysconfig/checklog)"
    exit 0
fi

# ищем STRING в FILENAME, если находим, добавляем в message сообщение 
if grep -Fxq "$STRING" "$FILENAME"
then
    logger $DATE : $FILENAME - $STRING '(EXIST)'
else
    exit 0
fi
```
Опишем unit сервис для запуска скрипта `checklog.service`
```
[Unit]
Description=Checklog

[Service]
Type=simple
EnvironmentFile=/etc/sysconfig/checklog
ExecStart=/bin/bash '/opt/script.sh'

[Install]
WantedBy=multi-user.target
```
Опишем unit таймера для данного сервиса `checklog.timer`

OnActiveSec - определяет таймер относительно момента времени его активации
OnBootSec - определяет таймер при загрузке системы
```
[Unit]
Description=Execute checklog every 30 sec

[Timer]
# Run after booting one second
OnActiveSec=1s
OnBootSec=1m
# Run every one hour or one munite
OnUnitActiveSec=30s

Unit=checklog.service

[Install]
WantedBy=multi-user.target
```
Проверим работу сервиса и содержимое `/var/log/messages`:
```
[vagrant@server ~]$ sudo systemctl start checklog.timer
[vagrant@server ~]$ sudo systemctl status checklog.timer
● checklog.timer - Execute checklog every 30 sec
   Loaded: loaded (/etc/systemd/system/checklog.timer; disabled; vendor preset: disabled)
   Active: active (waiting) since Mon 2021-10-11 04:28:18 UTC; 11s ago
  Trigger: Mon 2021-10-11 04:28:48 UTC; 18s left

Oct 11 04:28:18 server systemd[1]: Started Execute checklog every 30 sec.
[vagrant@server ~]$ sudo tail /var/log/messages 
Oct 11 04:28:18 user-VirtualBox systemd[1]: Started Checklog.
Oct 11 04:28:19 user-VirtualBox root[4244]: Mon Oct 11 04:28:19 UTC 2021 : /var/log/backup_database.log - ERROR (EXIST)
Oct 11 04:28:19 user-VirtualBox systemd[1]: checklog.service: Succeeded.
Oct 11 04:28:52 user-VirtualBox systemd[1]: Started Checklog.
Oct 11 04:28:53 user-VirtualBox root[4259]: Mon Oct 11 04:28:53 UTC 2021 : /var/log/backup_database.log - ERROR (EXIST)
```
# ***Переписать init-скрипт spawn-fcgi на unit-файл***

Устанавливаем необходимые пакеты: 
 ```
yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y
```
Создаем unit модуль для spawn-fcgi сервиса `/etc/systemd/system/spawn-fcgi.service`
```
[Unit]
Description=Spawn-fcgi service
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
Запускаем сервис и проверяем его статус: 
```
[root@server vagrant]# systemctl start spawn-fcgi.service
[root@server vagrant]# systemctl status spawn-fcgi.service
● spawn-fcgi.service - Spawn-fcgi service
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
   Active: active (running) since Mon 2021-10-11 04:49:16 UTC; 8s ago
 Main PID: 21402 (php-cgi)
    Tasks: 33 (limit: 5976)
   Memory: 18.6M
   CGroup: /system.slice/spawn-fcgi.service
           ├─21402 /usr/bin/php-cgi
           ├─21404 /usr/bin/php-cgi
           ├─21405 /usr/bin/php-cgi
           ├─21406 /usr/bin/php-cgi
           ├─21407 /usr/bin/php-cgi
           ├─21408 /usr/bin/php-cgi
           ├─21409 /usr/bin/php-cgi
           ├─21410 /usr/bin/php-cgi
           ├─21411 /usr/bin/php-cgi
           ├─21412 /usr/bin/php-cgi
           ├─21413 /usr/bin/php-cgi
           ├─21414 /usr/bin/php-cgi
           ├─21415 /usr/bin/php-cgi
           ├─21416 /usr/bin/php-cgi
           ├─21417 /usr/bin/php-cgi
           ├─21418 /usr/bin/php-cgi
```

# ***Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера***

Создадим unit модуля для сервиса httpd `/etc/systemd/system/httpd@.service`.

%i - шаблон, имя инстанса, которое будет заменено в каждой новой версии сервиса
```
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd@.service(8)

[Service]
Type=notify
Environment=LANG=C
Environment=HTTPD_INSTANCE=%i
ExecStartPre=/bin/mkdir -m 710 -p /run/httpd/instance-%i
ExecStartPre=/bin/chown root.apache /run/httpd/instance-%i
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND -f conf/%i.conf
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful -f conf/%i.conf
# Send SIGWINCH for graceful stop
KillSignal=SIGWINCH
KillMode=mixed
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```
Скопируем конфигурационные файлы Apache, изменив для разных инстансов порт и PID процесса:
```
/etc/httpd/conf/apache1.conf :
Listen 8081
PidFile /var/run/instance-apache1.pid

--------------------------------------------

/etc/httpd/conf/apache2.conf :
Listen 8082
PidFile /var/run/instance-apache2.pid
``` 
Запускаем сервисы и проверяем результат:
```  
systemctl start httpd@apache1.service
systemctl start httpd@apache2.service
```
```
[vagrant@server ~]$ ss -tnlp
State               Recv-Q        Send-Q                 Local Address:Port
LISTEN              0             128                    0.0.0.0:111
LISTEN              0             128                    0.0.0.0:22
LISTEN              0             128                       [::]:111
LISTEN              0             128                          *:8081
LISTEN              0             128                          *:8082
LISTEN              0             128                       [::]:22
```

```                                      
[vagrant@server ~]$ systemctl status httpd@apache1.service
● httpd@apache1.service - The Apache HTTP Server
   Loaded: loaded (/etc/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Tue 2021-10-12 02:31:57 UTC; 1min 3s ago
     Docs: man:httpd@.service(8)
  Process: 4269 ExecStartPre=/bin/chown root.apache /run/httpd/instance-apache1 (code=exited, status=0/SUCCESS)
  Process: 4268 ExecStartPre=/bin/mkdir -m 710 -p /run/httpd/instance-apache1 (code=exited, status=0/SUCCESS)
Main PID: 4272 (httpd)
   Status: "Running, listening on: port 8081"
    Tasks: 213 (limit: 5976)
   Memory: 30.4M
   CGroup: /system.slice/system-httpd.slice/httpd@apache1.service
           ├─4272 /usr/sbin/httpd -DFOREGROUND -f conf/apache1.conf
           ├─4278 /usr/sbin/httpd -DFOREGROUND -f conf/apache1.conf
           ├─4279 /usr/sbin/httpd -DFOREGROUND -f conf/apache1.conf
           ├─4280 /usr/sbin/httpd -DFOREGROUND -f conf/apache1.conf
           └─4281 /usr/sbin/httpd -DFOREGROUND -f conf/apache1.conf
```
```
[vagrant@server ~]$ systemctl status httpd@apache2.service
● httpd@apache2.service - The Apache HTTP Server
   Loaded: loaded (/etc/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Tue 2021-10-12 02:32:03 UTC; 1min 3s ago
     Docs: man:httpd@.service(8)
  Process: 4303 ExecStartPre=/bin/chown root.apache /run/httpd/instance-apache2 (code=exited, status=0/SUCCESS)
  Process: 4276 ExecStartPre=/bin/mkdir -m 710 -p /run/httpd/instance-apache2 (code=exited, status=0/SUCCESS)
 Main PID: 4495 (httpd)
   Status: "Running, listening on: port 8082"
    Tasks: 213 (limit: 5976)
   Memory: 28.1M
   CGroup: /system.slice/system-httpd.slice/httpd@apache2.service
           ├─4495 /usr/sbin/httpd -DFOREGROUND -f conf/apache2.conf
           ├─4503 /usr/sbin/httpd -DFOREGROUND -f conf/apache2.conf
           ├─4504 /usr/sbin/httpd -DFOREGROUND -f conf/apache2.conf
           ├─4505 /usr/sbin/httpd -DFOREGROUND -f conf/apache2.conf
           └─4506 /usr/sbin/httpd -DFOREGROUND -f conf/apache2.conf
```


