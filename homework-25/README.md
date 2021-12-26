# **Домашнее задание №25**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **LDAP**
 
1. Установить FreeIPA;
2. Написать Ansible playbook для конфигурации клиента;

3*. Настроить аутентификацию по SSH-ключам;

4**. Firewall должен быть включен на сервере и на клиенте.

Формат сдачи ДЗ - vagrant + ansible

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `VagrantFile` - файл описывающий виртуальную инфраструктуру для `Vagrant`

# **Описание процесса выполнения домашнего задания №25**

FreeIpa (Free Identity Policy Audit) - открытый проект компании RedHat, основан на нескольких открытых проектах (389 Directory Server, MIT Kerberos, NTP, DNS (bind), Dogtag certificate system). 
Присутствует возможность множественной репликации для отказоустойчивости. Поддержка множества интерфейсов управления (CLI, Web UI, XMLRPC и JSONRPC API) и Python SDK).

Основные функции:
- Централизованное управление учётными записями
- Управление правилами для sudo
- Правила доступа к серверам по ssh
- DNS сервер
- Центр сертификации
- Web UI
- Интеграция с другими сервисами нуждающихся в авторизации (веб страницы, vpn сервера)
- Ntp сервер

`Vagrantfile` разворачивает 3 виртуальных машины: ldap-master, ldap-replica и ldap-client.
Для проверки можно получить информацию о пользователях LDAP на каждой из виртуальных машин (заведено 2 пользователя - admin, test):
```
echo "Secret123" | kinit admin
ipa user-find --all
```

**Установка и использование FreeIPA**

Сначала нужно подготовить сервер к запуску FreeIPA: указать имя хоста сервера, обновить системные пакеты, проверить записи DNS и настройки брандмауэра.
Все машины, на которых работает FreeIPA, должны использовать полные доменные имена (FQDN) как имена хостов. Кроме того, имя хоста каждого сервера должно разрешаться по его IP-адресу, а не по localhost.

Указать имя хоста можно используя команду hostname:
```
hostname server1.ipa.test
hostname server2.ipa.test
hostname client.ipa.test
```

Дополнительно пропишем в `/etc/hosts` соответствия между ip и именем хоста:
```
[vagrant@client ~]$ cat /etc/hosts
192.168.56.10 server1.ipa.test server1.ipa.test
192.168.56.11 server2.ipa.test server2.ipa.test
192.168.56.15 client.ipa.test client.ipa.test
```

Необходимо открыть несколько портов, которые используются службами FreeIPA:
```
firewall-cmd --permanent --add-port=53/{tcp,udp} --add-port={80,443}/tcp --add-port={88,464}/{tcp,udp} --add-port=123/udp --add-port={389,636}/tcp

firewall-cmd --reload
```
* где:

53 — запросы DNS. Не обязателен, если мы не планируем использовать наш сервер в качестве сервера DNS

80 и 443 — http и https для доступа к веб-интерфейсу управления

88 и 464 — kerberos и kpasswd

123 — синхронизация времени

389 и 636 — ldap и ldaps соответственно

Установка выполняется из репозитория `epel-release`, для CentOS 7 установим необходимые пакеты:
```
yum install nss
yum install ipa-server
yum install ipa-server-dns
yum install bind-dyndb-ldap     
```
После выполняем конфигурирование сервиса, указав необходимые для установки данные:
```
yum ipa-server-install
# параметры необходимые для установки
      --realm IPA.TEST // имя зоны
      --domain ipa.test // доменное имя
      --hostname server1.ipa.test // FQDN имя сервера
      --ds-password "DMSecret456" // пароль для Directory Manager
      --admin-password "Secret123" // пароль IPA admin
      --ip-address 192.168.56.10 // IP адрес сервера
      --setup-dns // сконфигурировать DNS BIND
      --mkhomedir // включить опцию содания директорий пользователей
      --no-reverse // не нестраивать обратную зону    
      --auto-forwarders // настроить перенаправление запросов
```
Проверим, что система может выдать билет:
```
[root@server1 vagrant]# kinit admin
Password for admin@IPA.TEST:
[root@server1 vagrant]# klist
Ticket cache: KEYRING:persistent:0:0
Default principal: admin@IPA.TEST

Valid starting     Expires            Service principal
12/25/21 01:50:29  12/26/21 01:50:26  krbtgt/IPA.TEST@IPA.TEST
```

**Добавление реплики**

Добавим второй сервер FreeIPA и настроим репликацию с первым. Установим основные пакеты:
```
yum install ipa-server
yum install ipa-server-dns
```

Выполним конфигурирование клиента:
```
yum install ipa-client-install
# параметры необходимые для установки
      --realm IPA.TEST // имя зоны
      --domain ipa.test // доменное имя
      --server=server1.ipa.test // FQDN имя master сервера
      --ip-address=192.168.56.10 // IP адрес master сервера
      --hostname=server2.ipa.test // FQDN имя реплики 
      --principal admin // IPA admin
      --password "Secret123" // пароль IPA admin  
      --mkhomedir // включить опцию содания директорий пользователей
      --force-ntpd  // остановка служб синхронизации времени перед конфигурированием 
```

Для репликации каталога выполним команду:
```
ipa-replica-install 
# параметры необходимые для конфигурирования
      --admin-password "Secret123"
      --mkhomedir // включить опцию содания директорий пользователей
      --ip-address 192.168.56.11
      --setup-dns  // сконфигурировать DNS BIND
      --allow-zone-overlap // разрешить перекрытие зон
      --skip-conncheck // пропустить результаты проверки соединения
      --no-reverse // не нестраивать обратную зону     
      --no-forwarders // не нестраивать перенаправление запросов
```
Проверяем:
```
[root@server2 vagrant]# kinit admin
Password for admin@IPA.TEST: 
[root@server2 vagrant]# ipa user-find --all
---------------
2 users matched
---------------
  dn: uid=admin,cn=users,cn=accounts,dc=ipa,dc=test
  User login: admin
  Last name: Administrator
  Full name: Administrator
  Home directory: /home/admin
  GECOS: Administrator
  Login shell: /bin/bash
  Principal alias: admin@IPA.TEST
  User password expiration: 20220325005949Z
  UID: 403200000
  GID: 403200000
  Account disabled: False
  Preserved user: False
  Member of groups: admins, trust admins
  ipauniqueid: edf6f28c-651b-11ec-8b2a-5254004d77d3
  krbextradata: AAIFbcZhcm9vdC9hZG1pbkBJUEEuVEVTVAA=
  krblastpwdchange: 20211225005949Z
  objectclass: top, person, posixaccount, krbprincipalaux, krbticketpolicyaux, inetuser, ipaobject, ipasshuser, ipaSshGroupOfPubKeys

  dn: uid=test,cn=users,cn=accounts,dc=ipa,dc=test
  User login: test
  First name: TEST
  Last name: Test
  Full name: TEST Test
  Display name: TEST Test
  Initials: TT
  Home directory: /home/test
  GECOS: TEST Test
  Login shell: /bin/bash
  Principal name: test@IPA.TEST
  Principal alias: test@IPA.TEST
  User password expiration: 20211225010113Z
  Email address: test@test.ru
  UID: 403200001
  GID: 403200001
  SSH public key: ssh-rsa
                  AAAAB3NzaC1yc2EAAAADAQABAAABAQCw5NAT/08eLMyePATnRaZf/bBEaN+kxKAoQaj3yMc2hlGgiPo0LiXBXUInomzxSibzaLfAi5CkK3exZTkN1jh8AQ4WByIp2LmSnP+snR8GYxywA050kIwKGl1La1AS5Ww0jroxsLRwBvUGZZRuA74QVvTYO0HLltY8iSeFSmM9JFlGoJjPk1bcbuIvJxRT2uXF9+to1VUPp8fXmUAp10z+qLVsAwMbuDfi0hXz/WxaDm+0LaP3pXgJLCr0BmlOG8rahjo0XMyIrDc73CwEIXqD904IaGXxAAgEhnOIfL1rmwqWfRktMN1ycRe+u3stChY0tmEmPLWbAb+NKvg+aC27
                  test@client.ipa.test
  SSH public key fingerprint: SHA256:kqR/nbOrmF25NjUQxSJryzXxCT2wwwVqGPnwSl2r0dE test@client.ipa.test (ssh-rsa)
  Account disabled: False
  Preserved user: False
  Member of groups: ipausers
  ipauniqueid: 28cd9f1c-651e-11ec-a6e9-5254004d77d3
  krbextradata: AAJZbcZhcm9vdC9hZG1pbkBJUEEuVEVTVAA=
  krblastpwdchange: 20211225010113Z
  mepmanagedentry: cn=test,cn=groups,cn=accounts,dc=ipa,dc=test
  objectclass: top, person, organizationalperson, inetorgperson, inetuser, posixaccount, krbprincipalaux, krbticketpolicyaux, ipaobject, ipasshuser,
               ipaSshGroupOfPubKeys, mepOriginEntry
----------------------------
Number of entries returned 2
```

**Подключение клиента к домену**

Устанавливаем freeipa-client.
```
yum install freeipa-client
```
Проверим, что клиент может получать билет от сервера:
```
[root@client vagrant]# kinit admin
Password for admin@IPA.TEST: 

[root@client vagrant]# klist
Ticket cache: KEYRING:persistent:0:0
Default principal: admin@IPA.TEST

Valid starting     Expires            Service principal
12/25/21 01:50:42  12/26/21 01:50:39  krbtgt/IPA.TEST@IPA.TEST
```

Попробуем зайти через ssh по паролю и по ключу, которые предварительно были загружены на клиента:
```
[vagrant@client ~]$ echo "Secret123" | kinit admin
Password for admin@IPA.TEST: 
[vagrant@client ~]$ klist
Ticket cache: KEYRING:persistent:1000:1000
Default principal: admin@IPA.TEST

Valid starting     Expires            Service principal
12/26/21 04:06:51  12/27/21 04:06:51  krbtgt/IPA.TEST@IPA.TEST

[vagrant@client ~]$ ssh test@server1.ipa.test
Password: 
Password expired. Change your password now.
Current Password: 
New password: 
Retype new password: 
[test@server1 ~]$ hostname
server1.ipa.test
[test@server1 ~]$ exit
logout
Connection to server1.ipa.test closed.

[test@client ~]$ pwd
/home/test
[test@client ~]$ ssh test@server1.ipa.test
Last login: Sun Dec 26 04:07:59 2021 from 192.168.56.15
[test@server1 ~]$ hostanme
-bash: hostanme: command not found
[test@server1 ~]$ hostname
server1.ipa.test
```

