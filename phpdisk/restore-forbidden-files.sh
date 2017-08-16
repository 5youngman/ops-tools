#!/bin/bash/
#本脚本目的在于恢复删除操作，给后悔的机会。

FILE_FULL_NAME=$1
FILE_NAME=`echo $FILE_FULL_NAME | cut -d '.' -f 1 `
FILE_INFO=`grep $FILE_NAME /srv/tmp/restore_deleted_file.sql | uniq `
ORG_DIR=`echo $FILE_INFO| cut -d "," -f 9 | cut -d "'" -f 2`

echo $FILE_FULL_NAME
echo $FILE_NAME
echo $FILE_INFO
echo $ORG_DIR

mysql -u root -phonlivwlyw phpdisk_honlivhp -e "INSERT INTO pd_files VALUES $FILE_INFO ;"
mv /srv/forbidden_files/`date +%Y/%m/%d`/$FILE_FULL_NAME /srv/www/filestores/$ORG_DIR
