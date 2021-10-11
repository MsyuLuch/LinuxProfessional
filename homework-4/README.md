# **Домашнее задание №4**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

Для выполнения работы потребуются следующие инструменты:

- **VirtualBox** - среда виртуализации, позволяет создавать и выполнять виртуальные машины;
- **Vagrant** - ПО для создания и конфигурирования виртуальной среды. В данном случае в качестве среды виртуализации используется *VirtualBox*; (https://www.vagrantup.com/downloads.html);

# **Цель**
 
## **Практические навыки работы с ZFS**
 
### 1. Определить алгоритм с наилучшим сжатием. 
Зачем: отрабатываем навыки работы с созданием томов и установкой параметров. Находим наилучшее сжатие. Шаги:
- определить какие алгоритмы сжатия поддерживает zfs (gzip gzip-N, zle lzjb, lz4);
- создать 4 файловых системы на каждой применить свой алгоритм сжатия; Для сжатия использовать либо текстовый файл либо группу файлов:
- скачать файл “Война и мир” и расположить на файловой системе wget -O War_and_Peace.txt http://www.gutenberg.org/ebooks/2600.txt.utf-8, либо скачать файл ядра распаковать и расположить на файловой системе.
Результат:
- список команд, которыми получен результат, с их выводами;
- вывод команды, из которой видно какой из алгоритмов лучше.

### 2. Определить настройки pool’a. 
Зачем: для переноса дисков между системами используется функция export/import. Отрабатываем навыки работы с файловой системой ZFS. Шаги:
- загрузить архив с файлами локально. https://drive.google.com/open?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg Распаковать.
- с помощью команды zfs import собрать pool ZFS;
- командами zfs определить настройки:
    - размер хранилища;
    - тип pool;
    - значение recordsize;
    - какое сжатие используется;
    - какая контрольная сумма используется. 

Результат:
- список команд которыми восстановили pool . Желательно с Output команд;
- файл с описанием настроек settings.

### 3. Найти сообщение от преподавателей. 
Зачем: для бэкапа используются технологии snapshot. Snapshot можно передавать между хостами и восстанавливать с помощью send/receive. Отрабатываем навыки восстановления snapshot и переноса файла. Шаги:
- скопировать файл из удаленной директории. https://drive.google.com/file/d/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG/view?usp=sharing Файл был получен командой zfs send otus/storage@task2 > otus_task2.file
- восстановить файл локально. zfs receive
- найти зашифрованное сообщение в файле secret_message
Результат:
- список шагов которыми восстанавливали;
- зашифрованное сообщение.

# **Исходные данные**

Ссылка на проект https://github.com/MsyuLuch/LinuxProfessional/tree/main/homework-3

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
- `history_log.txt` - log терминальной сессии

---
# **Описание процесса выполнения домашнего задания №4**

*** 1. Определить алгоритм с наилучшим сжатием***

Создаем пул хранения в ZFS (зеркало из 2х дисков /dev/sdb, /dev/sdc):
```
#zpool create -f storage mirror sdb sdc
```
Проверим состояние только что созданного пула:
```
# zpool status -v
  pool: storage
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        storage     ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdb     ONLINE       0     0     0
            sdc     ONLINE       0     0     0

errors: No known data errors

# zfs list
NAME      USED  AVAIL     REFER  MOUNTPOINT
storage  82.5K   832M       24K  /storage
```
Создаем файловые системы ZFS (названия выбираем в соответствии с алгоритмом сжатия, который будем использовать в дальнейшем):
```
#zfs create storage/fs-lzjb
#zfs create storage/fs-zle
#zfs create storage/fs-gzip
#zfs create storage/fs-gzip1
#zfs create storage/fs-gzip9
#zfs create storage/fs-lz4
```
Для файловых систем ZFS доступны следующие алгоритмы сжатия:
- gzip - стандартное сжатие UNIX.
- gzip- N - выбирает определенный уровень gzip. gzip-1 обеспечивает самое быстрое сжатие gzip. gzip-9 обеспечивает наилучшее сжатие данных. По умолчанию используется gzip-6 .
- lz4 - обеспечивает лучшее сжатие с меньшими затратами процессора
- lzjb - оптимизирован для производительности, обеспечивая при этом достойное сжатие
- zle - кодирование нулевой длины полезно для наборов данных с большими блоками нулей

Установим на каждой файловой системе свой алгоритм сжатия:
```
# zfs set compression=lzjb storage/fs-lzjb
# zfs set compression=zle storage/fs-zle
# zfs set compression=gzip storage/fs-gzip
# zfs set compression=gzip-1 storage/fs-gzip1
# zfs set compression=gzip-9 storage/fs-gzip9
# zfs set compression=lz4 storage/fs-lz4
```
Проверяем результат:
```
# zfs list
NAME               USED  AVAIL     REFER  MOUNTPOINT
storage            250K   832M     29.5K  /storage
storage/fs-gzip     24K   832M       24K  /storage/fs-gzip
storage/fs-gzip1    24K   832M       24K  /storage/fs-gzip1
storage/fs-gzip9    24K   832M       24K  /storage/fs-gzip9
storage/fs-lzjb     24K   832M       24K  /storage/fs-lzjb
storage/fs-zle      24K   832M       24K  /storage/fs-zle
```
Разместим на каждой файловой системе файл War_and_Peace.txt, размером 3.1М:
```
# ls -lh /storage/fs-gzip/
total 1.2M
-rw-r--r--. 1 root root 3.1M Aug 18 04:37 War_and_Peace.txt
```

```
# cp /storage/fs-gzip/War_and_Peace.txt /storage/fs-gzip1/
# cp /storage/fs-gzip/War_and_Peace.txt /storage/fs-gzip9/
# cp /storage/fs-gzip/War_and_Peace.txt /storage/fs-lzjb/
# cp /storage/fs-gzip/War_and_Peace.txt /storage/fs-zle/
# cp /storage/fs-gzip/War_and_Peace.txt /storage/fs-lz4/
```

Проверим степень сжатия для каждой файловой системы (наибольший у gzip9 - 2.63x):

```
# zfs get compressratio storage/fs-gzip
NAME             PROPERTY       VALUE  SOURCE
storage/fs-gzip  compressratio  2.62x  -

# zfs get compressratio storage/fs-gzip1
NAME              PROPERTY       VALUE  SOURCE
storage/fs-gzip1  compressratio  2.24x  -

# zfs get compressratio storage/fs-gzip9
NAME              PROPERTY       VALUE  SOURCE
storage/fs-gzip9  compressratio  2.63x  -

# zfs get compressratio storage/fs-lzjb
NAME             PROPERTY       VALUE  SOURCE
storage/fs-lzjb  compressratio  1.34x  -

# zfs get compressratio storage/fs-zle
NAME            PROPERTY       VALUE  SOURCE
storage/fs-zle  compressratio  1.01x  -

# zfs get compressratio storage/fs-lz4
NAME            PROPERTY       VALUE  SOURCE
storage/fs-lz4  compressratio  1.60x  -
```
Если рассмотреть значение столбца USED можно убедиться, что наиболее высокая степень сжатия у алгоритмов gzip, gzip-9:
```
# zfs get compressratio storage
NAME     PROPERTY       VALUE  SOURCE
storage  compressratio  1.69x  -
[root@localhost ~]# zfs list
NAME               USED  AVAIL     REFER  MOUNTPOINT
storage           9.52M   822M     29.5K  /storage
storage/fs-gzip   1.21M   822M     1.21M  /storage/fs-gzip
storage/fs-gzip1  1.41M   822M     1.41M  /storage/fs-gzip1
storage/fs-gzip9  1.21M   822M     1.21M  /storage/fs-gzip9
storage/fs-lzjb   2.34M   822M     2.34M  /storage/fs-lzjb
storage/fs-zle    3.11M   822M     3.11M  /storage/fs-zle
```

***Результат***

```
Наилучший алгоритм сжатия gzip9 - 2.63x
```

*** 2. Определить настройки pool’a***

Загрузим архив с файлами локально https://drive.google.com/open?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg. 
Распакуем его.
Определим пул для импорта:
```
# zpool import -d ${PWD}/zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
 action: The pool can be imported using its name or numeric identifier.
 config:

        otus                                 ONLINE
          mirror-0                           ONLINE
            /home/vagrant/zpoolexport/filea  ONLINE
            /home/vagrant/zpoolexport/fileb  ONLINE
```
Импортируем пул (т.к. это файл необходим полный путь ${PWD}):
```
zpool import -d ${PWD}/zpoolexport/ otus
```
Проверим результат (тип пула - зеркало mirror-0):
```
# zfs list
NAME             USED  AVAIL     REFER  MOUNTPOINT
otus            2.04M   350M       24K  /otus
otus/hometask2  1.88M   350M     1.88M  /otus/hometask2
[root@server vagrant]# zpool status
  pool: otus
 state: ONLINE
  scan: none requested
config:

        NAME                                 STATE     READ WRITE CKSUM
        otus                                 ONLINE       0     0     0
          mirror-0                           ONLINE       0     0     0
            /home/vagrant/zpoolexport/filea  ONLINE       0     0     0
            /home/vagrant/zpoolexport/fileb  ONLINE       0     0     0
```
Основные команды с помощью которых можно посмотреть настройки данного пула:
- просмотр базовой информации пула устройств хранения (размер хранилища 480М):
```
# zpool list
NAME   SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus   480M  2.09M   478M        -         -     0%     0%  1.00x    ONLINE  -
```
- запрос свойств ZFS (checksum - используемая контрольная сумма sha256):
```
# zfs get checksum
   NAME            PROPERTY  VALUE      SOURCE
   otus            checksum  sha256     local
   otus/hometask2  checksum  sha256     inherited from otus
```
- запрос свойств ZFS (recordsize - рекомендуемый размер блока для файлов в файловой системе 128К)
```
# zfs get recordsize
NAME            PROPERTY    VALUE    SOURCE
otus            recordsize  128K     local
otus/hometask2  recordsize  128K     inherited from otus
```
- запрос свойств ZFS (compression - сжатие, используемый алгоритм zle)
```
# zfs get compression,compressratio
NAME            PROPERTY       VALUE     SOURCE
otus            compression    zle       local
otus            compressratio  1.00x     -
otus/hometask2  compression    zle       inherited from otus
otus/hometask2  compressratio  1.00x     -
```
***Результат***

```
pool: otus
тип - mirror-0
размер - 480M
recordsize - 128K
checksum - sha256
compression - zle
```

*** 3. Найти сообщение от преподавателей***

Скопируем файл из удаленной директории https://drive.google.com/file/d/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG/view?usp=sharing. 
Файл был получен командой:
```
zfs send otus/storage@task2 > otus_task2.file
```
Следовательно, чтобы восстановить его локально, необходимо:
```
# zfs receive -F otus/hometask2 < otus_task2.file
```
Ищем файл с именем secret_message:
```
# find -name secret_message
./hometask2/task1/file_mess/secret_message
```
Просматриваем его содержимое:
```
# cat ./hometask2/task1/file_mess/secret_message
https://github.com/sindresorhus/awesome
```

***Результат***

Сообщение от преподавателей:
```
https://github.com/sindresorhus/awesome
```
