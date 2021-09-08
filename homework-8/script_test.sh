#!/bin/bash

# файл с результатами поиска
mailfile=mail.txt

function mailtxt
{
    file=$1  # log-файл
    numX=$2  # количество IP адресов (с наибольшим кол-вом запросов)
    numY=$3  # количество запрашиваемых адресов (с наибольшим кол-вом запросов)

    # удалим пустые строки в log-файле
    sed '/^$/d' $file > out.txt && mv -f out.txt $file

    echo "Временной диапазон": > $mailfile
    # дата первой строки (поле 4)
    echo $(awk '{print $4}' "$file" | sed 's/\[//; s/\]//' | sed -n 1p) >> $mailfile
    NL=$(wc "$file" | awk '{print $1}')
    if [ "$NL" -ne 0 ]; then
    # дата последней строки (поле 4)
    echo $(awk '{print $4}' "$file" | sed 's/\[//; s/\]//' | sed -n "$NL"p) >> $mailfile
    fi

    echo "------------------------------------------------------" >> $mailfile
    # URL, которые запрашивали чаще всего (поле 7)
    echo "${numY} запрашиваемых адресов (с наибольшим кол-вом запросов)" >> $mailfile
    less "$file" | awk '{print $7}' | sort | uniq -c | sort -rn | head -n "$numY" >> $mailfile
    echo "------------------------------------------------------" >> $mailfile
    # IP адреса, с которых прилетело больше всего запросов ( поле 1)
    echo "${numX} IP адресов (с наибольшим кол-вом запросов)" >> $mailfile
    less "$file" | awk '{print $1}' | sort | uniq -c | sort -rn | head -n "$numX" >> $mailfile
    echo "------------------------------------------------------" >> $mailfile
    # ошибки 4xx и 5хх (поле 9)
    echo "Все коды состояния 4xx и 5xx " >> $mailfile
    less "$file" | awk '{print $9}' | grep ^4 | uniq -d -c | sort -rn >> $mailfile
    less "$file" | awk '{print $9}' | grep ^5 | uniq -d -c | sort -rn >> $mailfile
    echo "------------------------------------------------------" >> $mailfile
    # все возможные коды (поле 9)
    echo "Все коды состояния HTTP и их количество" >> $mailfile
    less "$file" | awk '{print $9}'| grep -v "-" | sort | uniq -c | sort -rn >> $mailfile

}

# проверяем количество переданных параметров, должен быть хотя бы 1 - log-файл
if [ -z $1 ]; then
      echo "1 argument required, $# provided"
else
      # 1 параметр log-файл
      file=$1

      # 2 параметр количество IP адресов, с которых прилетело больше всего запросов
      # если не задан, то выбираем 10
      if [ -z $2 ]; then numX=10
                    else numX=$2
      fi

      # 3 количество URL, которые запрашивали чаще всего
      # если не задан, то выбираем 10
      if [ -z $3 ]; then numY=10
                    else numY=$3
      fi

      # 4 параметр, если не задан, выбираем только последний час в log-файле
      # иначе запрос по всему файлу
      if [ -z $4 ]; then
          grep "$(date -d '1 hour ago' +'%d/%b/%Y:%H:')" "$file" >> logfile.log
          mailtxt logfile.log "$numX" "$numY"
          rm -f logfile.log
      else
          mailtxt $file "$numX" "$numY"
      fi

      # если настроена почта, сформированный выше файл можно отправить по адресу name@address.ext
      #mail -s "cron mail" name@address.ext < $mailfile
fi