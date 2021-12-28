# **Домашнее задание №18**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **Сетевая лаборатория**
 
[https://github.com/erlong15/otus-linux/tree/network](https://github.com/erlong15/otus-linux/tree/network)

Vagrantfile с начальным  построением сети

- inetRouter 
- centralRouter
- centralServer

**Планируемая архитектура**

***Сеть office1***

192.168.2.0/26 - dev

192.168.2.64/26 - test servers

192.168.2.128/26 - managers

192.168.2.192/26 - office hardware

***Сеть office2***

192.168.1.0/25 - dev

192.168.1.128/26 - test servers

192.168.1.192/26 - office hardware


***Сеть central***

192.168.0.0/28 - directors

192.168.0.32/28 - office hardware

192.168.0.64/26 - wifi

Office1 ---\
              
              -----> Central --IRouter --> internet
              
Office2----/

**Теоретическая часть**
- Найти свободные подсети
- Посчитать сколько узлов в каждой подсети, включая свободные
- Указать broadcast адрес для каждой подсети
- Проверить нет ли ошибок при разбиении

**Практическая часть**
- Соединить офисы в сеть согласно схеме и настроить роутинг
- Все сервера и роутеры должны ходить в инет черз inetRouter
- Все сервера должны видеть друг друга
- У всех новых серверов отключить дефолт на нат (eth0), который вагрант поднимает для связи
- При нехватке сетевых интервейсов добавить по несколько адресов на интерфейс

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `VagrantFile` - файл описывающий виртуальную инфраструктуру для `Vagrant`

# **Описание процесса выполнения домашнего задания №18**

| 	 Сеть    |  network 	|   min IP	|   max IP	|   hosts	|   direct broadcast	|   mask	|
|---	 |---	|---	|---	|---	|---	|---	|
|  office1 - dev            |   192.168.2.0/26	|   192.168.2.1	    |   192.168.2.62	|   62	|   192.168.2.63	|   255.255.255.192	|
|  office1 - test servers	|   192.168.2.64/26	|   192.168.2.65	|   192.168.2.126	|   62	|   192.168.2.127	|   255.255.255.192	|
|  office1 - managers    	|   192.168.2.128/26|   192.168.2.129	|   192.168.2.190	|   62	|   192.168.2.191	|   255.255.255.192	|
|  office1 - hardware     	|   192.168.2.192/26|   192.168.2.193	|   192.168.2.254	|   62	|   192.168.2.255	|   255.255.255.192 |

| 	 Сеть    |  network 	|   min IP	|   max IP	|   hosts	|   direct broadcast	|   mask	|
|---	 |---	|---	|---	|---	|---	|---	|
|  office2 - dev            |   192.168.1.0/25	|   192.168.1.1	    |   192.168.1.126	|   126	|   192.168.1.127	|   255.255.255.128	|
|  office2 - test servers	|   192.168.1.128/26|   192.168.1.129	|   192.168.1.190	|   62	|   192.168.1.191	|   255.255.255.192	|
|  office2 - hardware    	|   192.168.1.192/26|   192.168.1.193	|   192.168.1.254 	|   62	|   192.168.1.255	|   255.255.255.192	|


Исправим маску для `central - directors`  и `central - hardware` сети:

| 	 Сеть    |  network 	|   min IP	|   max IP	|   hosts	|   direct broadcast	|   mask	|
|---	 |---	|---	|---	|---	|---	|---	|
|  central - directors  |   192.168.0.0/27	|   192.168.0.1     |   192.168.0.30	|   30	|   192.168.0.31	|   255.255.255.224 	|
|  central - hardware	|   192.168.0.32/27 |   192.168.0.33	|   192.168.0.62	|   30	|   192.168.0.63	|   255.255.255.224 	|
|  central - wifi   	|   192.168.0.64/26	|   192.168.0.65 	|   192.168.0.126	|   62	|   192.168.0.127 	|   255.255.255.192 	|


| 	 Сеть    |  network 	|   min IP	|   max IP	|   hosts	|   direct broadcast	|   mask	|
|---	 |---	|---	|---	|---	|---	|---	|
|  свободная    |   192.168.0.128/25	|   192.168.0.129    |   192.168.0.254 	|   126	|   192.168.0.255	|   255.255.255.128  	|

Схема сети:

![Schema](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-18/schema.jpg)

Выполняем Vagrantfile

Устанавливаем дополнительные утилиты для тестирования сети:
```
yum install net-tools -y
yum install traceroute -y
```

Отключаем маршрут по-умолчанию у всех машин:
```
echo "DEFROUTE=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0 
```

Так же в /etc/sysctl.conf добавляем опции, разрешающие форвардинг пакетов:
```
echo net.ipv4.conf.all.forwarding=1  >> /etc/sysctl.conf
```

Добавляем в файл `hosts` имена машин для упрощения тестирования:
```
192.168.255.1 inetRouter
192.168.0.1 centralRouter
192.168.0.10 centralServer
192.168.2.1 office1Router
192.168.2.10 office1Server
192.168.1.1 office2Router
192.168.1.10 office2Server
```
Проверяем настройки маршрутов, необходимо убедиться, что маршрут по умолчанию отключен, 
и настроена маршрутизация через inetRouter

inetRouter:
```
[vagrant@inetRouter ~]$ netstat -nr
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         10.0.2.2        0.0.0.0         UG        0 0          0 eth0
10.0.2.0        0.0.0.0         255.255.255.0   U         0 0          0 eth0
192.168.0.0     192.168.255.2   255.255.0.0     UG        0 0          0 eth1
192.168.255.0   0.0.0.0         255.255.255.252 U         0 0          0 eth1
```

centralRouter:
```
[vagrant@centralRouter ~]$ netstat -nr
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         192.168.255.1   0.0.0.0         UG        0 0          0 eth1
10.0.2.0        0.0.0.0         255.255.255.0   U         0 0          0 eth0
192.168.0.0     0.0.0.0         255.255.255.224 U         0 0          0 eth2
192.168.0.32    0.0.0.0         255.255.255.224 U         0 0          0 eth3
192.168.0.64    0.0.0.0         255.255.255.192 U         0 0          0 eth4
192.168.1.0     192.168.253.2   255.255.255.0   UG        0 0          0 eth1
192.168.2.0     192.168.254.2   255.255.255.0   UG        0 0          0 eth1
192.168.253.0   0.0.0.0         255.255.255.252 U         0 0          0 eth1
192.168.254.0   0.0.0.0         255.255.255.252 U         0 0          0 eth1
192.168.255.0   0.0.0.0         255.255.255.252 U         0 0          0 eth1
```

office1Router:
```
[vagrant@office1Router ~]$ netstat -nr
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         192.168.254.1   0.0.0.0         UG        0 0          0 eth1
10.0.2.0        0.0.0.0         255.255.255.0   U         0 0          0 eth0
192.168.2.0     0.0.0.0         255.255.255.192 U         0 0          0 eth2
192.168.2.64    0.0.0.0         255.255.255.192 U         0 0          0 eth3
192.168.2.128   0.0.0.0         255.255.255.192 U         0 0          0 eth4
192.168.2.192   0.0.0.0         255.255.255.192 U         0 0          0 eth5
192.168.254.0   0.0.0.0         255.255.255.252 U         0 0          0 eth1
```

office2Router:
```
[vagrant@office2Router ~]$ netstat -nr
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         192.168.253.1   0.0.0.0         UG        0 0          0 eth1
10.0.2.0        0.0.0.0         255.255.255.0   U         0 0          0 eth0
192.168.1.0     0.0.0.0         255.255.255.128 U         0 0          0 eth2
192.168.1.128   0.0.0.0         255.255.255.192 U         0 0          0 eth3
192.168.1.192   0.0.0.0         255.255.255.192 U         0 0          0 eth4
192.168.253.0   0.0.0.0         255.255.255.252 U         0 0          0 eth1
```

Проверяем маршрут пакетов до `ya.ru` для серверов

office1Server:
```
[vagrant@office1Server ~]$  traceroute ya.ru
traceroute to ya.ru (87.250.250.242), 30 hops max, 60 byte packets
 1  office1Router (192.168.2.1)  0.423 ms  0.402 ms  0.381 ms
 2  192.168.254.1 (192.168.254.1)  0.468 ms  0.529 ms  0.512 ms
 3  inetRouter (192.168.255.1)  0.676 ms  0.656 ms  0.681 ms
```

office2Server:
```
[vagrant@office2Server ~]$  traceroute ya.ru
traceroute to ya.ru (87.250.250.242), 30 hops max, 60 byte packets
 1  office2Router (192.168.1.1)  0.389 ms  0.354 ms  0.333 ms
 2  192.168.253.1 (192.168.253.1)  0.560 ms  0.541 ms  0.606 ms
 3  inetRouter (192.168.255.1)  0.782 ms  0.762 ms  1.066 ms
```

centralServer:
```
[vagrant@centralServer ~]$ traceroute ya.ru
traceroute to ya.ru (87.250.250.242), 30 hops max, 60 byte packets
 1  centralRouter (192.168.0.1)  0.367 ms  0.318 ms  0.253 ms
 2  inetRouter (192.168.255.1)  0.546 ms  0.657 ms  0.577 ms
```