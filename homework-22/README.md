# **Домашнее задание №22**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **Настраиваем split-dns**
 
Цель:

Взять стенд https://github.com/erlong15/vagrant-bind

-- Добавить еще один сервер client2. завести в зоне dns.lab имена:
- web1 - смотрит на клиент1
- web2 - смотрит на клиент2

-- Завести еще одну зону newdns.lab. завести в ней запись:
- www - смотрит на обоих клиентов

-- Настроить split-dns:
- клиент1 - видит обе зоны, но в зоне dns.lab только web1
- клиент2 - видит только dns.lab

Настроить все без выключения selinux

Формат сдачи ДЗ - vagrant + ansible

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `VagrantFile` - файл описывающий виртуальную инфраструктуру для `Vagrant`

# **Описание процесса выполнения домашнего задания №22**

`Vagrantfile` запускает Primary Server DNS - `NS01`, Secondary Server DNS - `NS02` и два клиента с разными правами чтения зон.

***Настроим split-dns*** 

DNS view - представляет собой конфигурацию, позволяющую по-разному отвечать на один и тот же запрос DNS в зависимости 
от источника запроса. Это позволяет возвращать одну версию данных зоны одной группе клиентов, а другую версию - другой группе клиентов. 
DNS view определяют одну или несколько зон и один или несколько списков управления доступом (ACL):

```
# определим два списка управления доступом:
acl internal-01 { !key client2-key; key client1-key; 192.168.50.15; };
acl internal-02 { !key client1-key; key client2-key; 192.168.50.16; };
```
Для обеспечения безопасности передачи сообщений DNS, используется TSIG (механизм общих секретов и вычислительно необратимой хеш-функции  для проверки
подлинности  DNS  сообщений). При настроенном и работающем механизме TSIG, DNS-сервер добавляет TSIG запись в раздел дополнительных данных
сообщения DNS и подтверждает, что отправитель сообщения обладает общим с получателем криптографическим ключом, и что сообщение не изменилось после того, как было отправлено. 
Чтобы использовать TSIG для идентификации, необходимо создать несколько TSIG ключей для сторон обменивающихся данными. Секрет представляет собой ключ в кодировке
Base64, созданной с помощью программы dnssec-keygen, которая входит в состав BIND:
```
# dnssec-keygen -a HMAK-MD5 -b 128 -n HOST client1-key
# dnssec-keygen -a HMAK-MD5 -b 128 -n HOST client2-key

# ключи, созданные для обмена между Primary и Secondary серверами
key "client1-key" {
    algorithm hmac-md5;
    secret "rxhWF7tRU62XClAiEw5UBQ==";
};
key "client2-key" {
    algorithm hmac-md5;
    secret "GfDq8H3S9nZn+tOmaLQajA==";
};
```

Базовая настройка Primary Server DNS описана в конфигурационном файле `/etc/named.conf`:
```
...................................................................................................
# Зоны доступные для client1

view "internal-01" {
    match-clients { "internal-01"; };

zone "dns.lab" {
    type master;
    file "/etc/named/named.dns.lab.client1";
    also-notify { 192.168.50.11 key client1-key; };
};

zone "50.168.192.in-addr.arpa" {
    type master;
    also-notify { 192.168.50.11 key client1-key; };
    file "/etc/named/named.dns.lab.rev";
};

zone "newdns.lab" {
    type master;
    also-notify { 192.168.50.11 key client1-key; };
    file "/etc/named/named.newdns.lab";
};
}
...................................................................................................
# Зоны доступные для client2

view "internal-02" {
    match-clients { "internal-02"; };

zone "dns.lab" {
    type master;
    also-notify { 192.168.50.11 key client2-key; };
    file "/etc/named/named.dns.lab";
};

zone "50.168.192.in-addr.arpa" {
    type master;
    also-notify { 192.168.50.11 key client2-key; };
    file "/etc/named/named.dns.lab.rev";
};
}
```

Файл зоны прямого просмотра `newdns.lab`:
```
$TTL 3600
$ORIGIN newdns.lab.
@               IN      SOA     ns01.newdns.lab. root.newdns.lab. (
                            2711201407 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.newdns.lab.
                IN      NS      ns02.newdns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11

; WEB Servers
@               IN      A       192.168.50.15
@               IN      A       192.168.50.16
www             IN      CNAME   newdns.lab.
```

- SOA-запись (Start of authority).
SOA-запись DNS определяет авторитетную информацию о доменном имени и зоне в целом.

- A-запись (Address).
Связывает IP с доменным именем. 

- NS-запись (Name Server).
Определяет сервер, который отвечает за выбранную вами зону. У каждого домена должна быть хотя бы одна NS-запись.

- CNAME-запись (Name Alias).
Позволяет создавать отсылки к ранее созданным A-записям и PTR-записям.

Редактируя файл зоны, необходимо увеличивать значение serial перед перезапуском процесса named.

---

***Secondary Server DNS***

На случай, если Primary Server DNS будет недоступен, рекомендуется настроить Secondary Server DNS. 

Конфигурационный файл Secondary Server DNS отличается указанием типа DNS сервера - `type slave` и указанием основного сервера `masters { 192.168.50.10; };`.
Передача зоны доступна при наличии ключа:

```
zone "dns.lab" {
    type slave;
    masters { 192.168.50.10 key client1-key; };
    file "/etc/named/named.client1.dns.lab";
};
```
---
***Настройка DNS на клиентах***

Необходимо отредактировать файл `/etc/resolv.conf`, прописав имя домена и ip адреса dns серверов:
```
domain dns.lab
search dns.lab
nameserver 192.168.50.10
nameserver 192.168.50.11
```

---

**Client1:**

Видит зону `dns.lab`, но внутри зоны только `web1.dns.lab` и  зону `new.dns.lab`

```
[vagrant@client ~]$ dig dns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.8 <<>> dns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 49540
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 2, ADDITIONAL: 3

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;dns.lab.                       IN      A

;; ANSWER SECTION:
dns.lab.                3600    IN      A       192.168.50.10
dns.lab.                3600    IN      A       192.168.50.11

;; AUTHORITY SECTION:
dns.lab.                3600    IN      NS      ns01.dns.lab.
dns.lab.                3600    IN      NS      ns02.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.           3600    IN      A       192.168.50.10
ns02.dns.lab.           3600    IN      A       192.168.50.11

;; Query time: 4 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Tue Dec 14 05:24:20 UTC 2021
;; MSG SIZE  rcvd: 138
```

```
[vagrant@client ~]$ nslookup web1.dns.lab
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   web1.dns.lab
Address: 192.168.50.15

[vagrant@client ~]$ nslookup web2.dns.lab
Server:         192.168.50.10
Address:        192.168.50.10#53

** server can't find web2.dns.lab: NXDOMAIN

[vagrant@client ~]$ nslookup newdns.lab
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   newdns.lab
Address: 192.168.50.16
Name:   newdns.lab
Address: 192.168.50.15
```

```
[vagrant@client ~]$ dig newdns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.8 <<>> newdns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 44665
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 2, ADDITIONAL: 3

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;newdns.lab.                    IN      A

;; ANSWER SECTION:
newdns.lab.             3600    IN      A       192.168.50.16
newdns.lab.             3600    IN      A       192.168.50.15

;; AUTHORITY SECTION:
newdns.lab.             3600    IN      NS      ns01.newdns.lab.
newdns.lab.             3600    IN      NS      ns02.newdns.lab.

;; ADDITIONAL SECTION:
ns01.newdns.lab.        3600    IN      A       192.168.50.10
ns02.newdns.lab.        3600    IN      A       192.168.50.11

;; Query time: 6 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Tue Dec 14 05:26:15 UTC 2021
;; MSG SIZE  rcvd: 141
```

**Client2:**

Видит только зону `dns.lab`

```
[vagrant@client2 ~]$ dig dns.lab 192.168.50.10

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.8 <<>> dns.lab 192.168.50.10
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 31354
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 2, ADDITIONAL: 3

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;dns.lab.                       IN      A

;; ANSWER SECTION:
dns.lab.                3600    IN      A       192.168.50.11
dns.lab.                3600    IN      A       192.168.50.10

;; AUTHORITY SECTION:
dns.lab.                3600    IN      NS      ns02.dns.lab.
dns.lab.                3600    IN      NS      ns01.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.           3600    IN      A       192.168.50.10
ns02.dns.lab.           3600    IN      A       192.168.50.11

;; Query time: 6 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Tue Dec 14 13:56:48 UTC 2021
;; MSG SIZE  rcvd: 138

;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 20481
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;192.168.50.10.                 IN      A

;; AUTHORITY SECTION:
.                       10800   IN      SOA     a.root-servers.net. nstld.verisign-grs.com. 2021121400 1800 900 604800 86400

;; Query time: 1255 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Tue Dec 14 13:56:49 UTC 2021
;; MSG SIZE  rcvd: 117
```

```
[vagrant@client2 ~]$ dig dns.lab 192.168.50.11

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.8 <<>> dns.lab 192.168.50.11
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 5781
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 2, ADDITIONAL: 3

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;dns.lab.                       IN      A

;; ANSWER SECTION:
dns.lab.                3600    IN      A       192.168.50.10
dns.lab.                3600    IN      A       192.168.50.11

;; AUTHORITY SECTION:
dns.lab.                3600    IN      NS      ns02.dns.lab.
dns.lab.                3600    IN      NS      ns01.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.           3600    IN      A       192.168.50.10
ns02.dns.lab.           3600    IN      A       192.168.50.11

;; Query time: 0 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Tue Dec 14 13:56:52 UTC 2021
;; MSG SIZE  rcvd: 138

;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 21401
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;192.168.50.11.                 IN      A

;; AUTHORITY SECTION:
.                       10800   IN      SOA     a.root-servers.net. nstld.verisign-grs.com. 2021121400 1800 900 604800 86400

;; Query time: 288 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Tue Dec 14 13:56:52 UTC 2021
;; MSG SIZE  rcvd: 117
```

```
[vagrant@client2 ~]$ nslookup dns.lab 192.168.50.10
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   dns.lab
Address: 192.168.50.11
Name:   dns.lab
Address: 192.168.50.10

[vagrant@client2 ~]$ nslookup dns.lab 192.168.50.11
Server:         192.168.50.11
Address:        192.168.50.11#53

Name:   dns.lab
Address: 192.168.50.10
Name:   dns.lab
Address: 192.168.50.11

[vagrant@client2 ~]$ nslookup web1.dns.lab 192.168.50.11
Server:         192.168.50.11
Address:        192.168.50.11#53

Name:   web1.dns.lab
Address: 192.168.50.15

[vagrant@client2 ~]$ nslookup web2.dns.lab 192.168.50.11
Server:         192.168.50.11
Address:        192.168.50.11#53

Name:   web2.dns.lab
Address: 192.168.50.16

[vagrant@client2 ~]$ nslookup newdns.lab 192.168.50.11
Server:         192.168.50.11
Address:        192.168.50.11#53

** server can't find newdns.lab: NXDOMAIN

[vagrant@client2 ~]$ nslookup newdns.lab 192.168.50.10
Server:         192.168.50.10
Address:        192.168.50.10#53

** server can't find newdns.lab: NXDOMAIN
```

***BIND и SELinux***

Файлы в директории `/etc/named` должны быть промаркированы `named_zone_t` типом. Чтобы восстановить измененную маркировку необходимо выполнить команду `restorecon -R /etc/named`.