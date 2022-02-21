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



![MASTER](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-27/images/master.png)
![REPLICA](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-27/images/replica.png)

***Установка MYSQL***

Установите MySQL на основной сервер и реплику:
```
sudo yum install https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm 
sudo yum install mysql-community-server
```

<details><summary>A dropdown list for markdown</summary>

   1. First item must be preceeded with an empty line.
   1. Markdown renders **perfectly**.
   1. Extra item.

</details>

