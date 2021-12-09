# **Домашнее задание №20**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **Сценарии iptables**
 
Цель:

- реализовать knocking port;
- centralRouter может попасть на ssh inetrRouter через knock скрипт пример в материалах;
- добавить inetRouter2, который виден (маршрутизируется (host-only тип сети для виртуалки)) с хоста или форвардится порт через локалхост;
- запустить nginx на centralServer;
- пробросить 80й порт на inetRouter2 8080;
- дефолт в интернет оставить через inetRouter.

Формат сдачи ДЗ - vagrant + ansible

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `VagrantFile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
- `roles\iptables` - роль для настройки фильтрации трафика на виртуальных машинах

# **Описание процесса выполнения домашнего задания №20**

Запустим `Vagrantfile`.

Port knocking — это сетевой защитный механизм, действие которого основано на следующем принципе: 
сетевой порт является по-умолчанию закрытым, но до тех пор, пока на него не поступит заранее определённая 
последовательность пакетов данных, которая «заставит» порт открыться. 
Работая в режиме демона совместно с iptables, knockd прослушивает сетевой интерфейс, 
ожидая корректной последовательности запросов на подключение. Как только knockd отлавливает корректную последовательность, 
он выполняет команду, определённую в конфигурационном файле knockd для данной последовательности — как правило, это вызов 
iptables, разрешающий соединение на определённый сетевой порт.

Текущая конфигурация knockd:
```
[options]
        UseSyslog
        logfile = /var/log/knockd.log

[openSSH]
        sequence = 2222,3333,4444
        seq_timeout = 20
        command = /sbin/iptables -I INPUT 1 -s %IP% -p tcp --dport ssh -j ACCEPT
        tcpflags = syn
[closeSSH]
        sequence = 4444,3333,2222
        seq_timeout = 20
        command = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
        tcpflags = syn
```

- `sequence` : последовательность портов, к которым необходимо получить доступ, чтобы открыть или закрыть порт 22. 
Порты по умолчанию: 2222, 3333, 4444, чтобы открыть его, и 4444, 3333, 2222, чтобы закрыть. 
Вы можете изменить их или добавить в список другие порты. 

- `seq_timeout` : период времени, в течение которого кто-то должен получить доступ к портам, чтобы инициировать их открытие или закрытие.

- `command` : Команда, отправляемая iptables при запуске действия открытия или закрытия. Эти команды либо добавляют правило к брандмауэру 
(чтобы открыть порт), либо отменяют его (чтобы закрыть порт).

- `tcpflags` : тип пакета, который каждый порт должен получить в секретной последовательности. 
Пакет SYN (синхронизация) является первым в запросе TCP- соединения, который называется трехсторонним рукопожатием .

В комплекте с демоном knockd поставляется утилита knock, которая может осуществлять необходимые серии подключений.
Чтобы проверить работу данного сервиса, необходимо зайти на `centralRouter` и попробовать подключиться к `inetRouter1`. После неудачной попытки подключения 
по ssh, выполнить команду `knock 192.168.255.1 2222 3333 4444`. В результате в iptables добавиться правило, 
определенное в конфигурационном файле и доступ к `inetRouter1` будет открыт.

```
Last login: Wed Dec  8 13:32:42 2021 from 10.0.2.2
[vagrant@centralRouter ~]$ sudo su

[root@centralRouter vagrant]# ssh knock@192.168.255.1          
ssh: connect to host 192.168.255.1 port 22: Connection refused

[root@centralRouter vagrant]# knock 192.168.255.1 2222 3333 4444

[root@centralRouter vagrant]# ssh knock@192.168.255.1
The authenticity of host '192.168.255.1 (192.168.255.1)' can't be established.
ECDSA key fingerprint is SHA256:4CG/BTWqWxHm08OMeuT8gV5C3aIAfPmCwucOgEUqeGM.
ECDSA key fingerprint is MD5:fc:cc:a7:b3:29:37:66:31:60:4f:c6:53:97:6d:6e:40.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.255.1' (ECDSA) to the list of known hosts.
knock@192.168.255.1's password:

[knock@inetRouter1 ~]$ hostname
inetRouter1
```

***Установим и запустим на `centralServer` NGINX:***

```
[vagrant@centralServer ~]$ curl -I localhost
HTTP/1.1 200 OK
Server: nginx/1.20.1
Date: Wed, 08 Dec 2021 13:42:31 GMT
Content-Type: text/html
Content-Length: 4833
Last-Modified: Fri, 16 May 2014 15:12:48 GMT
Connection: keep-alive
ETag: "53762af0-12e1"
Accept-Ranges: bytes
``` 

В `Vagrantfile` добавим проброс портов с хоста на `inetRouter2`:
```
box.vm.network "forwarded_port", guest: 8080, guest_ip: "192.168.255.5", host: 9999, host_ip: "127.0.0.1",  protocol: "tcp"
```

На `inetRouter2` в iptables добавим следующие правила, перенаправляя трафик с порта 8080 виртуальной машины `inetRouter2` 
на 80 порт виртуальной машины `centerServer`:
```
    - iptables -t nat -A PREROUTING -p tcp -m tcp --dport 8080 -j DNAT --to-destination 192.168.0.10:80
    - iptables -t nat -A OUTPUT -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.10:80
    - iptables -t nat -A POSTROUTING -j MASQUERADE
```

Проверяем на хостовой машине доступ к NGINX на `centralServer`:
```
user@user-B75H2-M3:~$ curl -I localhost:9999
HTTP/1.1 200 OK
Server: nginx/1.20.1
Date: Wed, 08 Dec 2021 13:45:05 GMT
Content-Type: text/html
Content-Length: 4833
Last-Modified: Fri, 16 May 2014 15:12:48 GMT
Connection: keep-alive
ETag: "53762af0-12e1"
Accept-Ranges: bytes
```

***Проверим маршрут доступа в интернет:***

centralRouter:

```
[root@centralRouter vagrant]# traceroute ya.ru
traceroute to ya.ru (87.250.250.242), 30 hops max, 60 byte packets
 1  inetRouter1 (192.168.255.1)  5.111 ms  4.815 ms  4.687 ms
 2  * * *
 3  * * *
 4  ipoe-gw.ttk-chita.ru (188.168.81.1)  37.530 ms  37.369 ms  37.162 ms
 5  cta06rb.transtelecom.net (188.43.240.158)  37.094 ms  36.907 ms  36.724 ms
 6  mskn17.transtelecom.net (188.43.3.214)  128.183 ms  125.102 ms  124.911 ms
 7  Yandex-gw.transtelecom.net (188.43.3.213)  92.763 ms  110.832 ms  109.988 ms
 8  sas-32z3-ae2-1.yndx.net (87.250.239.185)  109.434 ms * sas-32z3-ae1-1.yndx.net (87.250.239.183)  140.379 ms
 9  ya.ru (87.250.250.242)  107.692 ms *  100.038 ms
```

centralServer:

```
[vagrant@centralServer ~]$ traceroute ya.ru
traceroute to ya.ru (87.250.250.242), 30 hops max, 60 byte packets
 1  centralRouter (192.168.0.1)  0.526 ms  0.376 ms  0.228 ms
 2  inetRouter1 (192.168.255.1)  2.824 ms  2.630 ms  2.446 ms
 3  * * *
 4  * * *
 5  * * *
 6  cta06rb.transtelecom.net (188.43.240.158)  55.003 ms  54.514 ms  54.132 ms
 7  mskn17.transtelecom.net (188.43.3.214)  163.795 ms  191.465 ms  163.260 ms
 8  Yandex-gw.transtelecom.net (188.43.3.213)  144.553 ms  90.122 ms  89.474 ms
 9  * sas-32z3-ae1-1.yndx.net (87.250.239.183)  126.544 ms sas-32z3-ae2-1.yndx.net (87.250.239.185)  126.100 ms
10  * * ya.ru (87.250.250.242)  106.448 ms
```

Схема сети:

![Schema](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-20/image.png)