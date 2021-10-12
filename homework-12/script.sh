#!/bin/bash

. /etc/sysconfig/checklog

DATE=`date`

if [[ ! "$STRING" ]]; then
    logger $DATE : "STRING param is FULL (/etc/sysconfig/checklog)"
    exit 0
fi

if [[ ! "$FILENAME" ]]; then
    logger $DATE : "FILENAME is FULL (/etc/sysconfig/checklog)"
    exit 0
fi


if grep -Fxq "$STRING" "$FILENAME"
then
    logger $DATE : $FILENAME - $STRING '(EXIST)'
else
    exit 0
fi