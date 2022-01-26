# **Домашнее задание №27**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **Репликация MySQL**
 
Варианты стенда:

В материалах приложены ссылки на Vagrantfile (https://gitlab.com/otus_linux/stands-mysql/-/tree/master/) для репликации и дамп базы bet.dmp.

Базу развернуть на мастере и настроить так, чтобы реплицировались таблицы: bookmaker, competition, market, odds, outcome.
Настроить GTID репликацию. 

Формат сдачи ДЗ - vagrant + ansible

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`

# **Описание процесса выполнения домашнего задания №27**

Репликация позволяет копировать данные с одного сервера базы данных MySQL (источника) на один или несколько серверов базы данных MySQL (реплики). 
Репликация по умолчанию асинхронна; репликам не требуется постоянное подключение для получения обновлений из источника. 
В зависимости от конфигурации вы можете реплицировать все базы данных, выбранные базы данных или даже выбранные таблицы в базе данных.

Преимущества репликации в MySQL включают в себя:

- Масштабируемые решения — распределение нагрузки между несколькими репликами для повышения производительности. В этой среде все записи и обновления должны выполняться на исходном сервере репликации. Однако чтение может выполняться на одной или нескольких репликах. Эта модель может повысить производительность операций записи (поскольку источник предназначен для обновлений), а также значительно повысить скорость чтения при увеличении числа реплик.

- Безопасность данных — поскольку данные реплицируются в реплику, а реплика может приостанавливать процесс репликации, можно запускать службы резервного копирования на реплике без повреждения соответствующих исходных данных.

- Аналитика — оперативные данные могут быть созданы в источнике, а анализ информации может выполняться в реплике, не влияя на производительность источника.

- Распространение данных на большие расстояния — вы можете использовать репликацию для создания локальной копии данных для использования на удаленном сайте без постоянного доступа к источнику.

Для проверки работы стенда запускаем `Vagrantfile`, заходим на master и проверяем:
```
SHOW MASTER STATUS\G
```

на replica:
```
SHOW SLAVE STATUS\G;
```

![MASTER](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-27/images/master.png)
![REPLICA](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-27/images/replica.png)

***Установка MYSQL***

Установите MySQL на основной сервер и реплику:
```
sudo yum install https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm 
sudo yum install mysql-community-server
```

После установки необходимо запустить команду, что установить пароль root и повысить безопасность сервера:
```
mysql_secure_installation
```

Добавим в домашнюю папку root файл `my.cnf` с логином и паролем:
```
[client]
user="root"
password="Replication2022#"
```

***Настройка MASTER***

Глобальный идентификатор транзакции (GTID) — это уникальный идентификатор, созданный и связанный с каждой транзакцией, 
совершенной на исходном сервере (источнике). Этот идентификатор уникален не только для сервера, на котором он был создан, но и для всех серверов 
в данной топологии репликации.

Когда клиентская транзакция фиксируется в источнике, ей присваивается новый GTID при условии, что транзакция была записана в двоичный журнал. 
Клиентские транзакции гарантированно имеют монотонно возрастающие GTID без пробелов между сгенерированными числами. 

Реплицированные транзакции сохраняют тот же GTID, который был назначен транзакции на исходном сервере. 

Для master настраиваем конфигурационный файл `/etc/my.cnf`:
```
[mysqld]
bind-address = 192.168.11.150

gtid_mode=ON
enforce-gtid-consistency

server-id = 1

log_bin = mysql-bin
log-error=/var/log/mysqld.log

replicate-do-db=bet
replicate-do-table=bet.bookmaker
replicate-do-table=bet.competition
replicate-do-table=bet.market
replicate-do-table=bet.odds
replicate-do-table=bet.outcome
```
Основные настройки:

`bind-address`                        - адрес, на котором будет слушать MySQL

`gtid_mode=ON
 enforce-gtid-consistency`            - активация GTID
 
`server-id`                           - порядковый номер сервера, для master =1

`log_bin`                             - активация режима логирования при репликации

`replicate-do-db, replicate-do-table` - определяет БД и таблицы для репликации

Перезагружаем процесс MySQL:
``` 
sudo systemctl restart mysqld 
```
Создадим пользователя для репликации и дадим ему права на репликацию:
```
CREATE USER 'replication_user'@'192.168.11.151' IDENTIFIED BY 'Replication2022#';
GRANT REPLICATION SLAVE ON *.* TO 'replication_user'@'192.168.11.151';
```
Создадим базу данных `bet`, загружаем данные из дампа и проверяем:
```
Last login: Tue Jan 25 07:09:08 2022 from 10.0.2.2
[vagrant@master ~]$ sudo su
[root@master vagrant]# mysql
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 5
Server version: 5.7.37-log MySQL Community Server (GPL)

Copyright (c) 2000, 2022, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> SHOW MASTER STATUS;
+------------------+----------+--------------+------------------+-------------------------------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set                         |
+------------------+----------+--------------+------------------+-------------------------------------------+
| mysql-bin.000002 |      464 |              |                  | 6ece991b-7da7-11ec-9473-5254004d77d3:1-39 |
+------------------+----------+--------------+------------------+-------------------------------------------+
1 row in set (0.01 sec)

mysql> SHOW BINARY LOGS;
+------------------+-----------+
| Log_name         | File_size |
+------------------+-----------+
| mysql-bin.000001 |     92744 |
| mysql-bin.000002 |       464 |
+------------------+-----------+
2 rows in set (0.01 sec)
```

***Настройка REPLICA***

Для replica настраиваем конфигурационный файл `/etc/my.cnf`, меняя порядковый номер сервера `server-id = 2`:
```
[mysqld]
bind-address = 192.168.11.151

gtid_mode=ON
enforce-gtid-consistency

server-id = 2
```
Перезагружаем процесс MySQL:
``` 
sudo systemctl restart mysqld 
```
Переводим сервер в режим реплики:
```
CHANGE MASTER TO MASTER_HOST="192.168.11.150", MASTER_PORT = 3306, MASTER_USER="replication_user", MASTER_PASSWORD="Replication2022#", MASTER_AUTO_POSITION=1;'
START SLAVE;
```
Проверяем:
```
SHOW SLAVE STATUS\G;
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 192.168.11.150
                  Master_User: replication_user
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000002
          Read_Master_Log_Pos: 194
               Relay_Log_File: replica-relay-bin.000005
                Relay_Log_Pos: 407
        Relay_Master_Log_File: mysql-bin.000002
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: 
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table: 
                   Last_Errno: 0
                   Last_Error: 
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 194
              Relay_Log_Space: 656
              Until_Condition: None
               Until_Log_File: 
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
           Master_SSL_CA_File: 
           Master_SSL_CA_Path: 
              Master_SSL_Cert: 
            Master_SSL_Cipher: 
               Master_SSL_Key: 
        Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error: 
               Last_SQL_Errno: 0
               Last_SQL_Error: 
  Replicate_Ignore_Server_Ids: 
             Master_Server_Id: 1
                  Master_UUID: 6ece991b-7da7-11ec-9473-5254004d77d3
             Master_Info_File: /var/lib/mysql/master.info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
           Master_Retry_Count: 86400
                  Master_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 
               Master_SSL_Crl: 
           Master_SSL_Crlpath: 
           Retrieved_Gtid_Set: 6ece991b-7da7-11ec-9473-5254004d77d3:1-38
            Executed_Gtid_Set: 6ece991b-7da7-11ec-9473-5254004d77d3:1-38
                Auto_Position: 1
         Replicate_Rewrite_DB: 
                 Channel_Name: 
           Master_TLS_Version: 
1 row in set (0.01 sec)
```

Проверяем работу репликации. На мастере добавляем запись в таблицу:
```
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| bet                |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
5 rows in set (0.04 sec)

mysql> use bet
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> show tables;
+------------------+
| Tables_in_bet    |
+------------------+
| bookmaker        |
| competition      |
| events_on_demand |
| market           |
| odds             |
| outcome          |
| v_same_event     |
+------------------+
7 rows in set (0.01 sec)

mysql> select * from bookmaker
    -> ;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
4 rows in set (0.01 sec)

mysql> INSERT INTO bookmaker (id,bookmaker_name) VALUES(10,'books');
Query OK, 1 row affected (0.04 sec)

mysql> select * from bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  4 | betway         |
| 10 | books          |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)
```
Проверяем на реплике:
```
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| bet                |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
5 rows in set (0.03 sec)

mysql> use bet;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> show tables;
+------------------+
| Tables_in_bet    |
+------------------+
| bookmaker        |
| competition      |
| events_on_demand |
| market           |
| odds             |
| outcome          |
| v_same_event     |
+------------------+
7 rows in set (0.01 sec)

mysql> select * from bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  4 | betway         |
| 10 | books          |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)
```


