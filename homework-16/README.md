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
- конфигурационные файлы для настройки ELK Stack

# **Описание процесса выполнения домашнего задания №16**

Централизованный сбор логов будем реализовывать с помощью ELK Stack:

- Elasticsearch используется для хранения, анализа, поиска по логам.
- Kibana представляет удобную и красивую web панель для работы с логами.
- Logstash сервис для сбора логов и отправки их в Elasticsearch. 
- Filebeat - агент для отправки логов в Logstash или Elasticsearch.

Запускаем Vagrantfile, в результате будет поднято 2 виртуальных машины: 
 - web - с установленным NGINX и Filebeat
 - elastic - ELK Stack (Elasticsearch, Logstash, Kibana)
 
 Проверить работу ELK стека можно в веб-интерфейсе Kibana по адресу `http://10.0.0.100:5601`. 
 Необходимо добавить индексы:
 - nginx*
 - audit*
 - syslog*
 Данные собираются с `web` с помощью сервиса filebeat, который в свою очередь отправляет их в `logstash`, 
 где они обрабатываются и пересылаются в базу Elasticsearch. 
 
 Дополнительно настроено слежение за изменением конфигурационных файлов NGINX. Проверить работу NGINX можно по адресу `http://10.0.0.110`
 
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
Ядро системы по сбору логов - Elasticsearch, конфигурационный файл оставим с настройками по-умолчанию:
```
path.data: /var/lib/elasticsearch # директория для хранения данных
network.host: 127.0.0.1 # слушаем только локальный интерфейс
```
Kibana - панель для визуализации данных, полученных из Elasticsearch, настроим слушать на внешнем интерфейсе на порту 5601:
```
server.host: "10.0.0.100:5601"
``` 
Logstash принимает данные на порту 5044 `input.conf`:
```
input {
  beats {
    port => 5044
  }
}
```
Далее логи будут парситься (добавляются префиксы `nginx-`, `audit-`, `syslog-`) и перенаправляться в Elastic - `localhost:9200`.
```
output {
    if [type] == "nginx_access" {
        elasticsearch {
            hosts    => "localhost:9200"
            index    => "nginx-%{+YYYY.MM.dd}"
        }
    }
    if [type] == "nginx_error" {
        elasticsearch {
            hosts    => "localhost:9200"
            index    => "nginx-%{+YYYY.MM.dd}"
        }
    }
    if [type] == "syslog" {
        elasticsearch {
            hosts    => "localhost:9200"
            index    => "syslog-%{+YYYY.MM.dd}"
        }
    }
    if [type] == "audit" {
        elasticsearch {
            hosts    => "localhost:9200"
            index    => "audit-%{+YYYY.MM.dd}"
        }
    }
}
```
При старте виртуальной машины web, устанавливается NGINX и агент Filebeat:
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
Изменим конфигурационный файл Filebeat:
```
filebeat.inputs:
- type: log
  enabled: true
  paths:
      - /var/log/nginx/access.log
  fields:
    type: nginx_access
  fields_under_root: true
  scan_frequency: 5s

- type: log
  enabled: true
  paths:
      - /var/log/nginx/error.log
  fields:
    type: nginx_error
  fields_under_root: true
  scan_frequency: 5s

- type: log
  enabled: true
  paths:
      - /var/log/messages
  fields:
    type: syslog
  fields_under_root: true
  scan_frequency: 5s

- type: log
  enabled: true
  paths:
      - /var/log/audit/audit.log
  fields:
    type: audit
  fields_under_root: true
  scan_frequency: 5s

output.logstash:
  hosts: ["10.0.0.100:5044"]
```
Агент будет собирать логи NGINX, auditd, messages, пути к логам прописаны в конфиге, 
а также добавлено дополнительное поле `type` для парсинга в Logstash. 

Дополнительно настроим auditd.
Auditd регистрирует любые изменения, внесенные в файлы конфигурации аудита, 
или любые попытки доступа к файлам журнала аудита, а также любые попытки 
импортировать или экспортировать информацию в систему или из системы, 
а также множество другой информации, связанной с безопасностью.
```
auditctl - утилита для управления системой аудита ядра.
ausearch - утилита для поиска в файлах журнала аудита определенных событий.
aureport - утилита для создания отчетов о записанных событиях.
```
Просмотреть существующие правила:
```
auditctl -l
```
Настроить слежение за изменением конфигурационных файлов NGINX можно командой:
```
auditctl -w /etc/nginx/nginx.conf -p wa -k web_config_changed
```