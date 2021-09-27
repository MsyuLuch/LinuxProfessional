# **Домашнее задание №10**

## **Первые шаги с Ansible**
 
Подготовить стенд на Vagrant как минимум с одним сервером. На этом сервере используя Ansible необходимо развернуть nginx со следующими условиями:

- необходимо использовать модуль yum/apt;
- конфигурационные файлы должны быть взяты из шаблона jinja2 с перемененными;
- после установки nginx должен быть в режиме enabled в systemd;
- должен быть использован notify для старта nginx после установки;
- сайт должен слушать на нестандартном порту - 8080, для этого использовать переменные в Ansible.

# **Исходные данные**

Ссылка на проект https://github.com/MsyuLuch/LinuxProfessional/tree/main/homework-10

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `VagrantFile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
- `ansible.cfg` - conf-файл для Ansible
- `playbook-web-nginx.yml` -  playbook для установки NGINX
- `roles` - файлы роли для установки NGINX
- `inventories` - файлы описывающие хосты

# **Описание процесса выполнения домашнего задания №10**

Создадим дерево папок для новой роли:
```
ansible-galaxy init roles/web-nginx
```
Опишем переменные для роли:
```
# vars file for web-nginx
# Порт, на котором будет слушать NGINX
nginx_listen_port: 8080

# Переменные для инициализации страницы index.html
page_title: "My site"
page_description: "..."
```
В папке `templates` лежат 2 шаблона в формате j2 ():
```
# nginx.conf
server {
        listen {{ nginx_listen_port }} default_server;
        listen [::]:{{ nginx_listen_port }} default_server;

        root /usr/share/nginx/html;

        server_name _;

        location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                try_files $uri $uri/ =404;
        }

}
```

```
# index.html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{{ page_title }}</title>
  <meta name="description" content="Created with Ansible">
</head>
<body>
    <h1>{{ page_title }}</h1>
    <p>{{ page_description }}</p>
</body>
</html>
```
Опишем `tasks` для роли:
```
---
# Установливаем NGINX
  - name: Install nginx 
    apt:
      name: nginx
      state: present
    # добавляем обработчик события
    notify: Restart nginx

# Добавляем NGINX в автозагрузку
  - name: Enable nginx
    systemd:
      name: nginx
      state: restarted
      enabled: yes

# Копируем index.html из шаблонов в папку NGINX в директорию `/usr/share/nginx/html/index.html`
  - name: HTML
    template:
      src: page.html.j2
      dest: /usr/share/nginx/html/index.html

# Копируем conf-файл в директорию `/etc/nginx/sites-enabled/default` и перезагружаем NGINX
  - name: Nginx conf
    template:
      src: nginx.default.conf.j2
      dest: /etc/nginx/sites-enabled/default
    # добавляем обработчик события
    notify: Reload nginx 
```
Добавим обработчики событий. Независимо от того, сколько задач уведомляет обработчик, он запускается только один раз, после того как все задачи завершены:
```
# Обработчик для события Restart NGINX
 - name: Restart nginx
   systemd:
     name: nginx
     state: restarted
     enabled: yes

# Обработчик для события Reload NGINX
 - name: Reload nginx
   systemd:
     name: nginx
     state: reloaded
```
Playbook будет запускать ранее созданную роль для всех хостов с `sudo` правами:
```
- name: Install nginx
  hosts: all
  become: true

  roles:
    - web-nginx
```
Редактируем файл `ansible.cfg`, в котором прописаны все основные параметры запуска Ansible 
```
[defaults]
# файл inventory
inventory = ./inventories/all.yml
# пользователь, от имени которого всё выполняется
remote_user = vagrant
host_key_cheking = False
roles = ./roles
# путь до роли
roles_path = ./roles
# 
callback_whitelist = profile_tasks
```
В файл `Vagrantfile` добавим вызов playbook:
```
     server.vm.provision "ansible" do |ansible|
        ansible.playbook = "playbook-web-nginx.yml"
        ansible.become = "true"
     end
```


