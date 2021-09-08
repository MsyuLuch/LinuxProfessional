#!/bin/bash

mailfile=mail.txt # файл с результатами поиска
file=access.log   # log-файл
numX=10           # количество IP адресов (с наибольшим кол-вом запросов)
numY=10           # количество запрашиваемых адресов (с наибольшим кол-вом запросов)

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

      if [ -e $file ] ; then
            grep "$(date -d '1 hour ago' +'%d/%b/%Y:%H:')" "$file" >> logfile.log
            mailtxt logfile.log "$numX" "$numY"
            rm -f logfile.log
      else
            echo "log-файл не существует" > $mailfile
      fi

      # если настроена почта, сформированный выше файл можно отправить по адресу name@address.ext
      #mail -s "cron mail" name@address.ext < $mailfile