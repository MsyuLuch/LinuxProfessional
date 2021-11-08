# **Домашнее задание №16**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **Настраиваем центральный сервер для сбора логов**
 
Подготовить стенд на Vagrant с 2 серверами web и log. 
- на web поднимаем nginx;
- на log настраиваем центральный лог сервер на любой системе на выбор (journald, rsyslog, elk);
- настраиваем аудит, следящий за изменением конфигов nginx;
- все критичные логи с web должны собираться и локально и удаленно;
- логи аудита должны также уходить на удаленную систему.

Формат сдачи ДЗ - vagrant + ansible

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `VagrantFile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
- конфигурационные файлы для настройки ELK

# **Описание процесса выполнения домашнего задания №16**

Запускаем Vagrantfile, в результате будет поднято 2 виртуальных машины: 
 - web - с NGINX и filebeat
 - elastic - стек ELK (Elasticsearch, Logstash, Kibana)
 
 Проверить работу ELK стека можно в веб-интерфейсе Kibana по адресу `http://10.0.0.100:5601`. 
 Необходимо добавить индексы:
 - nginx*
 - audit*
 - syslog*
 Данные собираются с `web` с помощью сервиса filebeat, который в свою очередь отправляет их в `logstash`, 
 где они обрабатываются и пересылаются в базу Elasticsearch.
 
 Дополнительно настроено слежение за изменением конфигурационных файлов NGINX.
 
 При старте виртуальной машины `elastic`, выполняется следующий набор команд:
 ```
         # Копируем публичный ключ репозитория:
         rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
         # Подключаем репозиторий Elasticsearch:
         cp -f /vagrant/repos/* /etc/yum.repos.d/

         # скачиваем и устанавливаем Elasticsearch
         yum install --enablerepo=elasticsearch elasticsearch -y
         systemctl daemon-reload && systemctl enable elasticsearch.service && systemctl start elasticsearch.service && systemctl status elasticsearch.service

         # скачиваем и устанавливаем Kibana, копируем конфигурационные файлы, изменив только значение host на ip адрес виртуальной машины 
         yum install kibana -y
         cp -f /vagrant/kibana/* /etc/kibana/
         systemctl daemon-reload && systemctl enable kibana.service && systemctl start kibana.service && systemctl status kibana.service

         # скачиваем и устанавливаем Logstash 
         yum install logstash -y
         cp -rf /vagrant/logstash/* /etc/logstash/
         systemctl enable logstash.service && systemctl start logstash.service && systemctl status logstash.service
```
Logstash будет разбирать все логи, которые поступают от web, добавляя префиксы `nginx-`, `audit-`, `syslog-` согласно полю 
`type`, определенному в filebeat.

При старте виртуальной машины web, выполняются команды:
```
         # скачиваем и устанавливаем NGINX
	     yum install nginx -y
         cp -f /vagrant/nginx/* /etc/nginx/
	     systemctl enable nginx && systemctl start nginx && systemctl status nginx

         rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
         cp -f /vagrant/repos/* /etc/yum.repos.d/

         # скачиваем и устанавливаем filebeat
	     yum install filebeat -y
	     cp -f /vagrant/filebeat/* /etc/filebeat
	     systemctl start filebeat && systemctl enable filebeat && systemctl status filebeat

         # В Centos auditd уже установлен, поэтому остается только 
         # настроить слежение за конфигурационным файлом NGINX
         auditctl -w /etc/nginx/nginx.conf -p wa -k web_config_changed
```