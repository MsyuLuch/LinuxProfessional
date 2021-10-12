# **Домашнее задание №11**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **Практика с SELinux**
 
Цель:
Тренируем умение работать с SELinux: диагностировать проблемы и модифицировать политики SELinux для корректной работы приложений, если это требуется.

1. Запустить nginx на нестандартном порту 3-мя разными способами:
- переключатели setsebool;
- добавление нестандартного порта в имеющийся тип;
- формирование и установка модуля SELinux. К сдаче:
README с описанием каждого решения (скриншоты и демонстрация приветствуются).
2. Обеспечить работоспособность приложения при включенном selinux.
- развернуть приложенный стенд https://github.com/mbfx/otus-linux-adm/tree/master/selinux_dns_problems;
- выяснить причину неработоспособности механизма обновления зоны (см. README);
- предложить решение (или решения) для данной проблемы;
- выбрать одно из решений для реализации, предварительно обосновав выбор;
- реализовать выбранное решение и продемонстрировать его работоспособность. К сдаче:
README с анализом причины неработоспособности, возможными способами решения и обоснованием выбора одного из них;
исправленный стенд или демонстрация работоспособной системы скриншотами и описанием.

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания

    1:
    - `VagrantFile` - файл описывающий виртуальную инфраструктуру для `Vagrant` для первого задания
    - `ansible.cfg` - conf-файл для Ansible
    - `playbook-web-nginx.yml` -  playbook для установки NGINX
    - `/roles/` - файлы роли для установки NGINX
    - `/inventories/` - файлы, описывающие основные параметры для хостов

# **Описание процесса выполнения домашнего задания №11**

# ***Запустить nginx на нестандартном порту 3-мя разными способами***

Запускаем стенд с помощью Vagrant (директория 1). 

Проверяем статус Selinux:
```
[root@server ~]# sestatus
SELinux status:                 enabled
SELinuxfs mount:                /sys/fs/selinux
SELinux root directory:         /etc/selinux
Loaded policy name:             targeted
Current mode:                   enforcing
Mode from config file:          enforcing
Policy MLS status:              enabled
Policy deny_unknown status:     allowed
Max kernel policy version:      31

[root@server ~]# getenforce
Enforcing
```
Запускаем NGINX, смотрим ошибки и рекомендации в audit.log:
```
[root@server ~]# systemctl start nginx
Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.

[root@server ~]# audit2why < /var/log/audit/audit.log
type=AVC msg=audit(1633333290.088:1073): avc:  denied  { name_bind } for  pid=3291 comm="nginx" src=8065 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

	Was caused by:
	The boolean nis_enabled was set incorrectly. 
	Description:
	Allow nis to enabled

	Allow access by executing:
	# setsebool -P nis_enabled 1

```
1. Использование параметризованных политик Selinux
 
Воспользуемся рекомендацией, установим значение политики `nis_enabled` в ON:
```
[root@server ~]# setsebool -P nis_enabled 1
```
Запускаем NGINX, проверяем статус:
```
[root@server ~]# systemctl start nginx
[root@server ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)
   Active: active (running) since Mon 2021-10-04 07:48:00 UTC; 6s ago
  Process: 3346 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 3343 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
  Process: 3341 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 3347 (nginx)
   CGroup: /system.slice/nginx.service
           ├─3347 nginx: master process /usr/sbin/nginx
           └─3348 nginx: worker process

Oct 04 07:47:59 server systemd[1]: Starting The nginx HTTP and reverse prox.....
Oct 04 07:48:00 server nginx[3343]: nginx: the configuration file /etc/ngin...ok
Oct 04 07:48:00 server nginx[3343]: nginx: configuration file /etc/nginx/ng...ul
Oct 04 07:48:00 server systemd[1]: Started The nginx HTTP and reverse proxy...r.
Hint: Some lines were ellipsized, use -l to show in full.
[root@server ~]# ss -tnlp
State      Recv-Q Send-Q Local Address:Port               Peer Address:Port              
LISTEN     0      128          *:22                       *:*                   users:(("sshd",pid=2303,fd=3))
LISTEN     0      100    127.0.0.1:25                       *:*                   users:(("master",pid=1005,fd=13))
LISTEN     0      128          *:8065                     *:*                   users:(("nginx",pid=3348,fd=6),("nginx",pid=3347,fd=6))
LISTEN     0      128          *:111                      *:*                   users:(("rpcbind",pid=343,fd=8))
LISTEN     0      128       [::]:22                    [::]:*                   users:(("sshd",pid=2303,fd=4))
LISTEN     0      100      [::1]:25                    [::]:*                   users:(("master",pid=1005,fd=14))
LISTEN     0      128       [::]:8065                  [::]:*                   users:(("nginx",pid=3348,fd=7),("nginx",pid=3347,fd=7))
LISTEN     0      128       [::]:111                   [::]:*                   users:(("rpcbind",pid=343,fd=11))
```
2. Создание модуля с правилами Selinux

При попытке запустить NGINX, Selinux пишет ошибки и рекомендации по их устранению в файл `audit.log`. 
Для добавления разрешающей политики можно использовать утилиту `audit2allow`. 
Формируем модуль, на основе рекомендаций из лога и загружаем его:
```
[root@server ~]# audit2allow -M httpd_add --debug < /var/log/audit/audit.log

******************** IMPORTANT ***********************
To make this policy package active, execute:

semodule -i httpd_add.pp

[root@server ~]# semodule -i httpd_add.pp
```
Запускаем NGINX и проверяем статус:
```
[root@server ~]# systemctl start nginx
[root@server ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)
   Active: active (running) since Mon 2021-10-04 09:38:41 UTC; 8s ago
  Process: 4641 ExecReload=/usr/sbin/nginx -s reload (code=exited, status=0/SUCCESS)
  Process: 24855 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 24853 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
  Process: 24850 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 24856 (nginx)
   CGroup: /system.slice/nginx.service
           ├─24856 nginx: master process /usr/sbin/nginx
           └─24857 nginx: worker process

Oct 04 09:38:40 server systemd[1]: Starting The nginx HTTP and reverse proxy server...
Oct 04 09:38:40 server nginx[24853]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Oct 04 09:38:40 server nginx[24853]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Oct 04 09:38:41 server systemd[1]: Started The nginx HTTP and reverse proxy server.
[root@server ~]# ss -tnlp
State      Recv-Q Send-Q                              Local Address:Port                                             Peer Address:Port              
LISTEN     0      128                                             *:8065                                                        *:*                   users:(("nginx",pid=24857,fd=6),("nginx",pid=24856,fd=6))
LISTEN     0      128                                             *:111                                                         *:*                   users:(("rpcbind",pid=344,fd=8))
LISTEN     0      128                                             *:22                                                          *:*                   users:(("sshd",pid=3405,fd=3))
LISTEN     0      100                                     127.0.0.1:25                                                          *:*                   users:(("master",pid=1050,fd=13))
LISTEN     0      128                                          [::]:8065                                                     [::]:*                   users:(("nginx",pid=24857,fd=7),("nginx",pid=24856,fd=7))
LISTEN     0      128                                          [::]:111                                                      [::]:*                   users:(("rpcbind",pid=344,fd=11))
LISTEN     0      128                                          [::]:22                                                       [::]:*                   users:(("sshd",pid=3405,fd=4))
LISTEN     0      100                                         [::1]:25                                                       [::]:*                   users:(("master",pid=1050,fd=14))
```

3. Добавляем порт в разрешенные для данного сервиса

Просматриваем список доступных портов для запуска сервиса
```
[root@server ~]# semanage port -l | grep http 
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989
```
Добавляем новый порт и проверяем работу NGINX:
```
[root@server ~]# semanage port -a -t http_port_t -p tcp 8065
```
Запускаем NGINX и проверяем статус:
```
[root@server ~]# systemctl start nginx
[root@server ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)
   Active: active (running) since Mon 2021-10-04 11:29:19 UTC; 7s ago
  Process: 4683 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 4681 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
  Process: 4678 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 4684 (nginx)
   CGroup: /system.slice/nginx.service
           ├─4684 nginx: master process /usr/sbin/nginx
           └─4685 nginx: worker process

Oct 04 11:29:18 server systemd[1]: Starting The nginx HTTP and reverse proxy server...
Oct 04 11:29:18 server nginx[4681]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Oct 04 11:29:18 server nginx[4681]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Oct 04 11:29:19 server systemd[1]: Started The nginx HTTP and reverse proxy server.

[root@server ~]# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      8065, 80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989

[root@server ~]# ss -tnlp
State      Recv-Q Send-Q                              Local Address:Port                                             Peer Address:Port              
LISTEN     0      128                                             *:22                                                          *:*                   users:(("sshd",pid=3397,fd=3))
LISTEN     0      100                                     127.0.0.1:25                                                          *:*                   users:(("master",pid=1035,fd=13))
LISTEN     0      128                                             *:8065                                                        *:*                   users:(("nginx",pid=4685,fd=6),("nginx",pid=4684,fd=6))
LISTEN     0      128                                             *:111                                                         *:*                   users:(("rpcbind",pid=341,fd=8))
LISTEN     0      128                                          [::]:22                                                       [::]:*                   users:(("sshd",pid=3397,fd=4))
LISTEN     0      100                                         [::1]:25                                                       [::]:*                   users:(("master",pid=1035,fd=14))
LISTEN     0      128                                          [::]:8065                                                     [::]:*                   users:(("nginx",pid=4685,fd=7),("nginx",pid=4684,fd=7))
LISTEN     0      128                                          [::]:111                                                      [::]:*                   users:(("rpcbind",pid=341,fd=11))
```

# ***Обеспечить работоспособность приложения при включенном selinux***

Скачиваем `https://github.com/mbfx/otus-linux-adm/tree/master/selinux_dns_problems`. Поднимаем виртуальные машины. 
Подключаемся к клиентской машине и пробуем выполнить удаленное обновление зоны `ddns.lab`:
```
###############################
### Welcome to the DNS lab! ###
###############################

- Use this client to test the enviroment
- with dig or nslookup. Ex:
    dig @192.168.50.10 ns01.dns.lab

- nsupdate is available in the ddns.lab zone. Ex:
    nsupdate -k /etc/named.zonetransfer.key
    server 192.168.50.10
    zone ddns.lab 
    update add www.ddns.lab. 60 A 192.168.50.15
    send

- rndc is also available to manage the servers
    rndc -c ~/rndc.conf reload
```
Получаем ошибку:
```
[vagrant@client ~]$ dig @192.168.50.10 ns01.dns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.7 <<>> @192.168.50.10 ns01.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 8932
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;ns01.dns.lab.			IN	A

;; ANSWER SECTION:
ns01.dns.lab.		3600	IN	A	192.168.50.10

;; AUTHORITY SECTION:
dns.lab.		3600	IN	NS	ns01.dns.lab.

;; Query time: 30 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Tue Oct 05 12:08:09 UTC 2021
;; MSG SIZE  rcvd: 71

[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
update failed: SERVFAIL
```
Подключаемся к dns серверу, с помощью утилиты `audit2why`, смотрим ошибки в файле `audit.log`:
```
[root@ns01 ~]# audit2why < /var/log/audit/audit.log
type=AVC msg=audit(1633435767.697:2038): avc:  denied  { create } for  pid=5230 comm="isc-worker0000" name="named.ddns.lab.view1.jnl" scontext=system_u:system_r:named_t:s0 tcontext=system_u:object_r:etc_t:s0 tclass=file permissive=0

	Was caused by:
		Missing type enforcement (TE) allow rule.

		You can use audit2allow to generate a loadable module to allow this access.
```
Формируем модуль с разрешающими правилами для Selinux из данного лога:
```
[root@ns01 ~]# audit2allow -M named-allow --debug < /var/log/audit/audit.log
******************** IMPORTANT ***********************
To make this policy package active, execute:

semodule -i named-allow.pp
```
Загружаем модуль:
```
[root@ns01 ~]# semodule -i named-allow.pp
``` 
Снова пробуем с клиента подключиться, ошибка повторяется, смотрим лог:
```
Oct  5 13:21:43 user-VirtualBox python: SELinux is preventing isc-worker0000 from write access on the file /etc/named/dynamic/named.ddns.lab.view1.jnl.#012#012*****  Plugin catchall_labels (83.8 confidence) suggests   *******************#012#012If you want to allow isc-worker0000 to have write access on the named.ddns.lab.view1.jnl file#012Then you need to change the label on /etc/named/dynamic/named.ddns.lab.view1.jnl#012Do#012# semanage fcontext -a -t FILE_TYPE '/etc/named/dynamic/named.ddns.lab.view1.jnl'#012where FILE_TYPE is one of the following: afs_cache_t, dnssec_trigger_var_run_t, initrc_tmp_t, ipa_var_lib_t, krb5_host_rcache_t, krb5_keytab_t, named_cache_t, named_log_t, named_tmp_t, named_var_run_t, named_zone_t, puppet_tmp_t, user_cron_spool_t, user_tmp_t.#012Then execute:#012restorecon -v '/etc/named/dynamic/named.ddns.lab.view1.jnl'#012#012#012*****  Plugin catchall (17.1 confidence) suggests   **************************#012#012If you believe that isc-worker0000 should be allowed write access on the named.ddns.lab.view1.jnl file by default.#012Then you should report this as a bug.#012You can generate a local policy module to allow this access.#012Do#012allow this access for now by executing:#012# ausearch -c 'isc-worker0000' --raw | audit2allow -M my-iscworker0000#012# semodule -i my-iscworker0000.pp#012
```
Выполняем рекомендации:
```
[root@ns01 ~]# ausearch -c 'isc-worker0000' --raw | audit2allow -M my-iscworker0000 | semodule -i my-iscworker0000.pp
```
Проверяем статус сервиса `named`, ошибок нет:
```
[root@ns01 ~]# systemctl status named      
● named.service - Berkeley Internet Name Domain (DNS)
   Loaded: loaded (/usr/lib/systemd/system/named.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2021-10-05 12:11:06 UTC; 1h 38min ago
  Process: 25630 ExecStop=/bin/sh -c /usr/sbin/rndc stop > /dev/null 2>&1 || /bin/kill -TERM $MAINPID (code=exited, status=0/SUCCESS)
  Process: 25646 ExecStart=/usr/sbin/named -u named -c ${NAMEDCONF} $OPTIONS (code=exited, status=0/SUCCESS)
  Process: 25642 ExecStartPre=/bin/bash -c if [ ! "$DISABLE_ZONE_CHECKING" == "yes" ]; then /usr/sbin/named-checkconf -z "$NAMEDCONF"; else echo "Checking of zone files is disabled"; fi (code=exited, status=0/SUCCESS)
 Main PID: 25647 (named)
   CGroup: /system.slice/named.service
           └─25647 /usr/sbin/named -u named -c /etc/named.conf

Oct 05 13:26:43 ns01 named[25647]: client @0x7f43c803c3e0 192.168.50.15#28002/key zonetransfer....oved
Oct 05 13:26:43 ns01 named[25647]: client @0x7f43c803c3e0 192.168.50.15#28002/key zonetransfer....0.15
Oct 05 13:26:43 ns01 named[25647]: client @0x7f43c803c3e0 192.168.50.15#28002/key zonetransfer....more
Oct 05 13:32:52 ns01 named[25647]: client @0x7f43c803c3e0 192.168.50.15#28002/key zonetransfer....oved
Oct 05 13:32:52 ns01 named[25647]: client @0x7f43c803c3e0 192.168.50.15#28002/key zonetransfer....0.15
Oct 05 13:32:52 ns01 named[25647]: client @0x7f43c803c3e0 192.168.50.15#28002/key zonetransfer....more
Oct 05 13:45:58 ns01 named[25647]: client @0x7f43c803c3e0 192.168.50.15#28002/key zonetransfer....oved
Oct 05 13:48:20 ns01 named[25647]: client @0x7f43c803c3e0 192.168.50.15#56239/key zonetransfer....oved
Oct 05 13:48:20 ns01 named[25647]: client @0x7f43c803c3e0 192.168.50.15#56239/key zonetransfer....0.15
Oct 05 13:48:20 ns01 named[25647]: client @0x7f43c803c3e0 192.168.50.15#56239/key zonetransfer....more
Hint: Some lines were ellipsized, use -l to show in full.
```
Пробуем подключиться с клиента вновь, на этот раз успешно, логи dns сервера подтверждают:
```
root@ns01 ~]# systemctl status -l named
● named.service - Berkeley Internet Name Domain (DNS)
   Loaded: loaded (/usr/lib/systemd/system/named.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2021-10-05 13:53:00 UTC; 2min 7s ago
  Process: 25794 ExecStop=/bin/sh -c /usr/sbin/rndc stop > /dev/null 2>&1 || /bin/kill -TERM $MAINPID (code=exited, status=0/SUCCESS)
  Process: 25810 ExecStart=/usr/sbin/named -u named -c ${NAMEDCONF} $OPTIONS (code=exited, status=0/SUCCESS)
  Process: 25807 ExecStartPre=/bin/bash -c if [ ! "$DISABLE_ZONE_CHECKING" == "yes" ]; then /usr/sbin/named-checkconf -z "$NAMEDCONF"; else echo "Checking of zone files is disabled"; fi (code=exited, status=0/SUCCESS)
 Main PID: 25811 (named)
   CGroup: /system.slice/named.service
           └─25811 /usr/sbin/named -u named -c /etc/named.conf

Oct 05 13:54:18 ns01 named[25811]: client @0x7f7f9803c3e0 192.168.50.15#56239/key zonetransfer.key: view view1: signer "zonetransfer.key" approved
Oct 05 13:54:18 ns01 named[25811]: client @0x7f7f9803c3e0 192.168.50.15#56239/key zonetransfer.key: view view1: updating zone 'ddns.lab/IN': adding an RR at 'www.ddns.lab' A 192.168.50.15
```
![It`s work!](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-12/images/NS01-Client.png)
--------------------------------------------------------------------------
Рекомендации по устранению проблемы:
- проверить разрешения на доступ к основным файлам:
```
[root@ns01 ~]# ls -Z /etc/named.conf 
-rw-r-----. root named system_u:object_r:named_conf_t:s0 /etc/named.conf

[root@ns01 ~]# ls -Z /etc/named/     
drw-rwx---. root named unconfined_u:object_r:etc_t:s0   dynamic
-rw-rw----. root named system_u:object_r:etc_t:s0       named.50.168.192.rev
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab.view1
-rw-rw----. root named system_u:object_r:etc_t:s0       named.newdns.lab

[root@ns01 ~]# ls -Z /etc/named/dynamic/
-rw-rw----. named named system_u:object_r:etc_t:s0       named.ddns.lab
-rw-rw----. named named system_u:object_r:etc_t:s0       named.ddns.lab.view1
-rw-r--r--. named named system_u:object_r:etc_t:s0       named.ddns.lab.view1.jnl
``` 
Если тип контекста необходимо изменить, можно использовать команды:
```
# смена типа
chcon -t named_zone_t /var/named/named.localhost

# восстановления контекста файла
restorecon -v /var/named/named.localhost

# восстановления контекста каталога
restorecon -R -v /var/named/dynamic
```
- проверить содержимое `audit.log` и выполнить рекомендации по формированию модуля с разрешающими правилами для Selinux:
```
audit2why < /var/log/audit/audit.log
```
В данном случае проблема была в отсутствии разрешающих правил для создания и записи в журнал `named.ddns.lab.view1.jnl`, при попытке удаленного обновления зоны.
Поэтому решением проблемы было добавление этих правил в Selinux.
Альтернативный, но не предпочтительный, вариант решения проблемы, отключить Selinux:
```
setenforce 0
```