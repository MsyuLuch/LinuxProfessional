# **Домашнее задание №13**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **Docker, docker-compose, dockerfile**
 
- Создайте свой кастомный образ nginx. После запуска nginx должен отдавать кастомную страницу (достаточно изменить дефолтную страницу nginx)
- Определите разницу между контейнером и образом. Вывод опишите в домашнем задании.
- Ответьте на вопрос: Можно ли в контейнере собрать ядро?
- Собранный образ необходимо запушить в docker hub и дать ссылку на ваш репозиторий.
- Создайте кастомные образы nginx и php, объедините их в docker-compose

# **Исходные данные** 

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `dockerfile` - файл для сборки кастомного NGINX
- `default.conf` - конфигурационный файл NGINX
- `index.html` - кастомная страничка для NGINX (используется при сборке из dockerfile)
- `docker-compose.yml` -  файл для сборки NGINX и php-fpm
- `index.php` - кастомная страничка для NGINX (используется при сборке из docker-compose)

# **Описание процесса выполнения домашнего задания №13**

# ***Создание кастомного образа NGINX***

Опишем Dockerfile для будущего образа NGINX:
```
# Указываем, какой базовый образ нужно использовать
FROM ubuntu:latest
 
# Выполняем команды в новом слое при построении образа
# Обновляем ОС
RUN apt-get update && apt-get upgrade -y
 
# Устанавливаем NGINX
RUN apt-get install nginx -y
 
# Указываем порт, который будет использоваться приложением внутри контейнера
EXPOSE 80

#Копируем файлы в контейнер 
COPY index.html /var/www/html/index.html

# Последняя команда, запускаемая каждый раз при запуске контейнера
CMD ["nginx", "-g", "daemon off;"]
```
Собираем образ
```
docker build -t mashkinasu/my-nginx:v1 .
```
Подключаемся к DockerHub и загружаем на него только что собранный образ:
```
docker login
....
docker push mashkinasu/my-nginx:v1
```
Запустим контейнер, скачивая образ из репозитория, на порту 8080:
```
docker run -d -p 8080:80 mashkinasu/my-nginx:v1
```
Проверяем работоспособность в браузере `localhost:8080` - должна загрузиться кастомная страница `inde.html`
Теперь данный образ можно использовать для следующего задания.

# ***Объединяем образы NGINX и PHP в docker-compose***
Опишем `docker-compose.yml`
```
# Версия docker-compose 
version: "3.7"
# Список наших сервисов (контейнеров)
services:
  web:
    # используем кастомный образ nginx
    image: mashkinasu/my-nginx:v1
    container_name: web
    # nginx должен загружаться после php контейнера
    depends_on:
      - php
    # монтируем директории, слева директории на основной машине, справа - куда они монтируются в контейнере
    volumes:
      - ./default.conf:/etc/nginx/sites-available/default
      - ./default.conf:/etc/nginx/sites-enabled/default
      - ./index.php:/var/www/index.php
    # мапим порты
    ports:
      - "8080:80"
    # используем сеть front_net и добавляем алиас
    networks:
      front_net:
        aliases:
          - web

  php:
    # образ php-fpm из репозитория DockerHub
    image: bitnami/php-fpm:7.4.24
    container_name: php
    # монтируем файл index.php
    volumes:
      - ./index.php:/var/www/index.php
    # используем сеть front_net и добавляем алиас
    networks:
      front_net:
        aliases:
          - php

# Сеть Docker
networks:
  front_net:
    ipam:
      driver: default

```
Запускаем контейнеры и проверяем результат в браузере `localhost:8080` - должна отразиться информация `phpinfo()`
```
docker-compose up -d
```
Просмотреть запущенные контейнеры можно командой:
```
user@user-VirtualBox:~/LinuxProfessional/homework-13$ docker ps -a
CONTAINER ID   IMAGE                    COMMAND                  CREATED          STATUS                      PORTS      NAMES
def279444507   mashkinasu/my-nginx:v1   "nginx -g 'daemon of…"   10 minutes ago   Exited (1) 10 minutes ago              web
5b5cec287189   bitnami/php-fpm:7.4.24   "php-fpm -F --pid /o…"   10 minutes ago   Up 10 minutes               9000/tcp   php
```
# ***Определите разницу между контейнером и образом***
![Docker](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-13/images/image.png)

# ****Определение образа (Image)****

Образ Docker — это набор файлов, соединенный с настройками, с помощью которого можно создать экземпляры, которые запускаются в отдельных контейнерах в виде изолированных процессов. 
Образ строится с использованием инструкций для получения полной исполняемой версии приложения, зависящей от версии ядра сервера. 
Команда Docker run используется для создания таких экземпляров, называемых контейнерами, запускаемыми с использованием образов Docker. 
При запуске из одного образа пользователь может создать несколько контейнеров. 

Образ можно определить как «сущность» или «общий вид» (union view) стека слоев только для чтения.

# ****Определение контейнера (Container)****

Контейнер — базовая единица программного обеспечения, покрывающая код и все его зависимости для обеспечения запуска приложения прозрачно, быстро и надежно независимо от окружения. 
Контейнер Docker может быть создан с использованием образа Docker. 
Это исполняемый пакет программного обеспечения, содержащий все необходимое для запуска приложения. 

Контейнер можно назвать «сущностью» стека слоев с верхним слоем для записи. 

# ***Можно ли в контейнере собрать ядро?***

Docker использует ядро ​​операционной системы, в контейнере нет собственного или дополнительного ядра. Все контейнеры, которые запускаются на машине, совместно используют это «главное» ядро.
Контейнер Docker Engine включает в себя только приложение и его зависимости. Он работает как изолированный процесс в пространстве пользователя в операционной системе хоста, разделяя ядро ​​с другими контейнерами. 