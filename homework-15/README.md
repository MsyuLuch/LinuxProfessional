# **Домашнее задание №15**

🔖Домашнее задание выполнено для курса [Administrator Linux.Professional](https://otus.ru/lessons/linux-professional/)

## **PAM**

1. Запретить всем пользователям, кроме группы admin логин в выходные (суббота и воскресенье), без учета праздников
2. Дать конкретному пользователю права работать с докером и возможность рестартить докер сервис

# **Исходные данные**

Здесь:
- `readme.md` - описание процесса выполнения домашнего задания
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`
- `pam_script.sh` - скрипт добавления пользователей и прав

# **Описание процесса выполнения домашнего задания №15**

Поднимаем виртуальную машину и проверяем выполнение условий
```
# пользователь может зайти в любой день, пароль 123
ssh can_user@192.168.10.10

# пользователь может зайти только в рабочие дни, пароль 123
ssh cant_user@192.168.10.10

# пользователь с возможностью перезагружать докер, пароль 123
ssh docker_user@192.168.10.10
sudo systemctl restart docker.service
```

# ***Запретить пользователям заходить по ssh в выходные***

Добавляем группу `admin` и двух пользователей. Пользователя `can_user` добавляем в группу `admin` 
```
groupadd admin
useradd -G admin can_user
useradd -G cant_user
```
Устанавливаем пароли для новых пользователей
```
echo "123" | sudo passwd --stdin can_user &&\
echo "123" | sudo passwd --stdin cant_user
```

```
sed -i "2i auth       required     pam_exec.so /usr/local/bin/pam_script.sh"  /etc/pam.d/sshd
```
Создаем скрипт, который будет при попытке залогиниться проверять принадлежит ли пользователь группе `admin`.
Если пользователь принадлежит группе, он сможет войти в любой день, иначе только в рабочие дни. Делаем скрипт исполняемым.
```
cat <<'EOF' > /usr/local/bin/pam_script.sh
#!/bin/bash
if [[ `grep $PAM_USER /etc/group | grep 'admin'` ]]
then
exit 0
fi
if [[ `date +%u` > 1 ]]
then
exit 1
fi
EOF

chmod +x /usr/local/bin/pam_script.sh
```
Правим конфигурационный файл `sshd_config`, предоставляя возможность входа по паролю и перезагружаем службу
```
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd
```

# ***Дать конкретному пользователю права на перезапуск докера***

Устанавливаем docker, добавляем в автозагрузку и запускаем
```
yum install yum-utils -y
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install docker-ce docker-ce-cli containerd.io -y
systemctl enable --now docker
```
Создаем пользователя `docker_user` и добавляем его в группу `docker`
```
useradd docker_user
echo "123" | sudo passwd --stdin docker_user
usermod -aG docker docker_user
```
Добавляем в файл `/etc/sudoers` права для пользователя `docker_user` на перезагрузку сервиса 
```
echo %docker_user ALL=NOPASSWD: /bin/systemctl restart docker.service>>/etc/sudoers
```