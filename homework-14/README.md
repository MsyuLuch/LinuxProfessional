# **Домашнее задание №14**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **Настройка мониторинга (prometheus - grafana)**
 
Настроить дашборд с графиками 
  
  - память;
  - процессор;
  - диск;
  - сеть.

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
--------------------------------------------------

- `/roles/node-exporter/` - роль для установки Prometheus
- `/roles/prometheus/` - роль для установки Node-Exporter

# **Описание процесса выполнения домашнего задания №14**

Vagrantfile поднимает 2 виртуальных машины: server, client.
На `server` устнавливается Prometheus (роль Ansible) и Grafana (скрипт при старте VM).
На `client` устанавливается Node-exporter (роль Ansible).

Для проверки сервисов в браузере
```
http://10.0.0.100:9090/targets  # Prometheus

http://10.0.0.101:9100/metrics  # Node-Exporter 

http://10.0.0.100:3000/         # Grafana
```


# ***Установка Prometheus***

Все переменные, которые используются при установке можно изменить в файле `/roles/prometheus/defaults/main.yml`

Создадим пользователя группу `prometheus` и пользователя `prometheus`
```
---
- name: create prometheus system group
  group:
    name: prometheus
    system: true
    state: present

- name: create prometheus system user
  user:
    name: prometheus
    system: true
    shell: "/usr/sbin/nologin"
    group: prometheus
    createhome: false
```
Создадим директорию `/var/lib/prometheus` и назначим на нее права для пользователя `prometheus`
```
- name: create prometheus data directory
  file:
    path: "{{ prometheus_db_dir }}"
    state: directory
    owner: prometheus
    group: prometheus
    mode: 0755
```
Создадим директорию `/etc/prometheus` для конфигурационных файлов и назначим на нее права
```
- name: create prometheus configuration directories
  file:
    path: "{{ item }}"
    state: directory
    owner: root
    group: prometheus
    mode: 0770
  with_items:
    - "{{ prometheus_config_dir }}"
    - "{{ prometheus_config_dir }}/rules"
    - "{{ prometheus_config_dir }}/file_sd"    
```

Чтобы установить `Prometheus` скачаем архив `Prometheus` последней версии
```
    - name: download prometheus binary to local folder
      become: false
      get_url:
        url: "https://github.com/prometheus/prometheus/releases/download/v{{ prometheus_version }}/prometheus-{{ prometheus_version }}.linux-{{ go_arch }}.tar.gz"
        dest: "/tmp/prometheus-{{ prometheus_version }}.linux-{{ go_arch }}.tar.gz"
      register: _download_archive
      until: _download_archive is succeeded
      retries: 5
      delay: 2
      # run_once: true # <-- this cannot be set due to multi-arch support
      delegate_to: localhost
      check_mode: false
```
Распакуем скачанный архив и скопируем файлы в созданную ранее конфигурационную директорию
Не забываем назначить права на файлы.
```
    - name: unpack prometheus binaries
      become: false
      unarchive:
        src: "/tmp/prometheus-{{ prometheus_version }}.linux-{{ go_arch }}.tar.gz"
        dest: "/tmp"
        creates: "/tmp/prometheus-{{ prometheus_version }}.linux-{{ go_arch }}/prometheus"
      delegate_to: localhost
      check_mode: false

    - name: propagate official prometheus and promtool binaries
      copy:
        src: "/tmp/prometheus-{{ prometheus_version }}.linux-{{ go_arch }}/{{ item }}"
        dest: "{{ _prometheus_binary_install_dir }}/{{ item }}"
        mode: 0755
        owner: root
        group: root
      with_items:
        - prometheus
        - promtool        
      notify:
        - restart prometheus

    - name: propagate official console templates
      copy:
        src: "/tmp/prometheus-{{ prometheus_version }}.linux-{{ go_arch }}/{{ item }}/"
        dest: "{{ prometheus_config_dir }}/{{ item }}/"
        mode: 0644
        owner: root
        group: root
      with_items:
        - console_libraries
        - consoles
      notify:
        - restart prometheus
  when:
    - prometheus_binary_local_dir | length == 0

- name: propagate locally distributed prometheus binaries
  copy:
    src: "{{ prometheus_binary_local_dir }}/{{ item }}"
    dest: "{{ _prometheus_binary_install_dir }}/{{ item }}"
    mode: 0755
    owner: root
    group: root
  with_items:
    - prometheus
    - promtool
  when:
    - prometheus_binary_local_dir | length > 0
  notify:
    - restart prometheus
```
Создадим модуль сервиса для `Prometheus` и конфигурационный файл.
Перезагрузим `Prometheus`.
```
- name: create systemd service unit
  template:
    src: prometheus.service.j2
    dest: /etc/systemd/system/prometheus.service
    owner: root
    group: root
    mode: 0644
  notify:
    - restart prometheus

- name: configure prometheus
  template:
    src: "{{ prometheus_config_file }}"
    dest: "{{ prometheus_config_dir }}/prometheus.yml"
    force: true
    owner: root
    group: prometheus
    mode: 0640
  notify:
    - reload prometheus    
``` 

# ***Установка Node-Exporter***

Все переменные, которые используются при установке можно изменить в файле `/roles/node-exporter/defaults/main.yml`

Создадим пользователя группу `node_exporter` и пользователя `node_exporter`
```
---
- name: Create the node_exporter group
  group:
    name: "{{ _node_exporter_system_group }}"
    state: present
    system: true
  when: _node_exporter_system_group != "root"

- name: Create the node_exporter user
  user:
    name: "{{ _node_exporter_system_user }}"
    append: true
    shell: /usr/sbin/nologin
    system: true
    create_home: false
    home: /
  when: _node_exporter_system_user != "root"
```
Создадим модуль для сервиса `node_exporter`, скопировав его из шаблонов
```
- name: Copy the node_exporter systemd service file
  template:
    src: node_exporter.service.j2
    dest: /etc/systemd/system/node_exporter.service
    owner: root
    group: root
    mode: 0644
  notify: restart node_exporter  
```
Загрузим архив с установочными файлами для `node_exporter`
```
    - name: Download node_exporter binary to local folder
      become: false
      get_url:
        url: "https://github.com/prometheus/node_exporter/releases/download/v{{ node_exporter_version }}/node_exporter-{{ node_exporter_version }}.linux-{{ go_arch }}.tar.gz"
        dest: "/tmp/node_exporter-{{ node_exporter_version }}.linux-{{ go_arch }}.tar.gz"
        mode: '0644'
      register: _download_binary
      until: _download_binary is succeeded
      retries: 5
      delay: 2
      delegate_to: localhost
      check_mode: false
```
Разархивируем файлы и перенесем в папку `/usr/local/bin`.
Перезагрузим сервис.
```
    - name: Unpack node_exporter binary
      become: false
      unarchive:
        src: "/tmp/node_exporter-{{ node_exporter_version }}.linux-{{ go_arch }}.tar.gz"
        dest: "/tmp"
        creates: "/tmp/node_exporter-{{ node_exporter_version }}.linux-{{ go_arch }}/node_exporter"
      delegate_to: localhost
      check_mode: false

    - name: Propagate node_exporter binaries
      copy:
        src: "/tmp/node_exporter-{{ node_exporter_version }}.linux-{{ go_arch }}/node_exporter"
        dest: "{{ _node_exporter_binary_install_dir }}/node_exporter"
        mode: 0755
        owner: root
        group: root
      notify: restart node_exporter
      when: not ansible_check_mode
  when: node_exporter_binary_local_dir | length == 0

- name: propagate locally distributed node_exporter binary
  copy:
    src: "{{ node_exporter_binary_local_dir }}/node_exporter"
    dest: "{{ _node_exporter_binary_install_dir }}/node_exporter"
    mode: 0755
    owner: root
    group: root
  when: node_exporter_binary_local_dir | length > 0
  notify: restart node_exporter
```
Теперь можно проверить работу Node-Exporter и Prometheus
```
На клиенте, где установлен node_exporter:
curl 'localhost:9100/metrics'

На сервере, где установлен Prometheus:
curl 'localhost:9090/metrics'
```
Страничка Prometheus доступна в браузере:
```
http://10.0.0.100:9090/targets
```
Страничка Node-Exporter доступна в браузере:
```
http://10.0.0.101:9100/metrics
```
# ***Установка Grafana***

Установим `grafana` с официально сайта согласно инструкциям
```
sudo apt-get install -y adduser libfontconfig1
wget https://dl.grafana.com/enterprise/release/grafana-enterprise_8.2.1_amd64.deb
sudo dpkg -i grafana-enterprise_8.2.1_amd64.deb
```
Запустим и проверим работу
```
sudo systemctl start grafana-server
sudo systemctl status grafana-server
```
Теперь страница `grafana` доступна в браузере.
Логинимся (логин `admin`, пароль `admin`), добавим DataSource - Prometheus и установим стандартный 
дашбоард для Node-Exporter с сайта (https://grafana.com/grafana/dashboards/12486)
```
http://10.0.0.100:3000/
```
![Prometheus](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-14/images/image-3.jpg)
![Node-Exporter](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-14/images/image-1.jpg)
![Grafana](https://github.com/MsyuLuch/LinuxProfessional/blob/main/homework-14/images/image-2.jpg)

