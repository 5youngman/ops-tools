#!/bin/bash
#
#
# check-forbidden-files.sh - 一个检查用户上传文件格式的小脚本。每天5分钟
#执行一次。用于防止用户通过修改后缀名的形式上传非法文件。
#
# 作者: 刘西洋 66954
#              <locke@honliv.com> <xiyangliu1987@gmail.com>
#              http://www.xiyang-liu.com
#
# 软件自由，版权没有
# 创建时间：2013年2月26日一个阳光明媚的上午
#
#￥￥￥￥￥￥￥￥￥￥程序设计思路￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥#
#    phpdisk通过限制文件选择框的形式限制用户上传文件爱你的格式。然而,比较
#聪明的用户会想到通过修改文件后缀名上传被禁止的文件。
#linux的file命令通过分析文件内容，而不是只看后缀名来判断文件类型。通过
#file命令依次检查当日用户上传的文件。凡是不合规范的都会被移动到特定的文件夹
#并以日志的形式记录用户ID合Email地址。并且在数据库中删除相应文件记录。
#$$$$$$$$$$$$$$$$$$$$$结束$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$#
#

##设置全局变量
DB_HOSTNAME="localhost"
DB_PORT="3306"
DB_USERNAME="phpdisk_user"
DB_PASSWORD="password"
DB_NAME="phpdisk_db"
FILE_POOL_PATH=/srv/www/filestores/`date +%Y/%m/%d`
FILE_CMD_PATH=/srv/file/bin
TMP_DIR=/srv/tmp
LOG_FILE=/srv/forbidden.log
WHITE_LIST="(.cbm|.bak|index.htm|.mdb)"

##声明函数
function EchoRecursiveFile() {
ls -1 "$1" | sed -e "s#^#$1/&#g" | while read Ec_file
    do
        if [ -d "$Ec_file" ]
        then
            EchoRecursiveFile "$Ec_file"
        else
          echo "$Ec_file" 
        fi
    done
}


function RemovePermitFile() {
#
#从给定的文件中将符合条件的文件移除，使其不进入到
#JudgeForbiddenFile（）函数中，
#rar和zip压缩文件，由各自处理过程来进行处理。
#
#
declare Re_permit_file_type=("Composite Document File V2 Document" "Microsoft Word 2007+" "Microsoft PowerPoint 2007+" "Microsoft Excel 2007+" "PDF document" "JPEG image data" "PC bitmap" "PNG image data" "text")

Re_type_i=0
Re_type_len=${#Re_permit_file_type[@]}
while [ $Re_type_i -lt $Re_type_len ]
do  
  /bin/sed -i -e "/${Re_permit_file_type[$Re_type_i]}/d" "$1"
let Re_type_i++
done
}

function JudgeArchive() {
#
#处理违规的rar和zip解压缩后的文件，
#输出文件类型，用作调试.
#
Ju_FILE_CMD_PATH=/srv/file/bin

cat "$1" | grep "^/" | /bin/cut -d ":" -f 1 | while read Ju_File_Name
do 
   Ju_FILE_TYPE=`$Ju_FILE_CMD_PATH/file -b "$Ju_File_Name"`
   echo "`date +%Y-%m-%d\ %H:%M` "$Ju_File_Name"  "$Ju_FILE_TYPE" "
done

}


##输出所有文件的检测结果到临时文件中

[ ! -d $FILE_POOL_PATH  ] && exit 1

cd $FILE_POOL_PATH
$FILE_CMD_PATH/file `ls $FILE_POOL_PATH | grep -v -E "$WHITE_LIST" ` > $TMP_DIR/file_cmd_output.swap
##循环检测,删除在允许文件列表中的条目。
/bin/gawk 'BEGIN{FS="Os"} {print $1}' $TMP_DIR/file_cmd_output.swap > $TMP_DIR/file_cmd_output.txt
rm $TMP_DIR/file_cmd_output.swap

RemovePermitFile $TMP_DIR/file_cmd_output.txt


##处理RAR压缩文件

[ ! -d /tmp/unrar.tmp/ ] &&  mkdir /tmp/unrar.tmp/
grep "RAR archive data" $TMP_DIR/file_cmd_output.txt | cut -d ":" -f 1 | while read rarfile
do
if  `/usr/bin/unrar T -p- $FILE_POOL_PATH/$rarfile > /dev/null 2>&1` 
then

  /usr/bin/unrar x -y -p- $FILE_POOL_PATH/$rarfile /tmp/unrar.tmp/ > /dev/null
  >$TMP_DIR/file_cmd_output_unrar.txt
  EchoRecursiveFile /tmp/unrar.tmp/ | while read Ech_Out_unrar

  do
    $FILE_CMD_PATH/file "$Ech_Out_unrar" >> $TMP_DIR/file_cmd_output_unrar.txt
  done 

  RemovePermitFile $TMP_DIR/file_cmd_output_unrar.txt

  if [ ! -s $TMP_DIR/file_cmd_output_unrar.txt ]
  then 
   /bin/sed -i -e "/$rarfile/d" $TMP_DIR/file_cmd_output.txt
  else
  JudgeArchive $TMP_DIR/file_cmd_output_unrar.txt 
  fi


  rm -rf /tmp/unrar.tmp/
fi
done


##处理ZIP压缩文件

[ ! -d /tmp/unzip.tmp/ ] && mkdir /tmp/unzip.tmp/
grep "Zip archive data" $TMP_DIR/file_cmd_output.txt | cut -d ":" -f 1 | while read zipfile
do
if  `/usr/bin/unzip -t -P "" -q $FILE_POOL_PATH/$zipfile > /dev/null`
then

  /usr/bin/unzip -q -P "" $FILE_POOL_PATH/$zipfile -d /tmp/unzip.tmp/ > /dev/null

  > $TMP_DIR/file_cmd_output_unzip.txt  
  EchoRecursiveFile /tmp/unzip.tmp/ | while read Ech_Out_unzip

  do
    $FILE_CMD_PATH/file "$Ech_Out_unzip" >> $TMP_DIR/file_cmd_output_unzip.txt
  done

  RemovePermitFile $TMP_DIR/file_cmd_output_unzip.txt

  if [ ! -s $TMP_DIR/file_cmd_output_unzip.txt ]
  then 
    /bin/sed -i -e "/$zipfile/d" $TMP_DIR/file_cmd_output.txt 
  else
  JudgeArchive $TMP_DIR/file_cmd_output_unzip.txt
  fi 

  rm -rf /tmp/unzip.tmp/
fi
done

##输出过滤后剩余的文件条目，也就是非法文件类型的条目到 forbidden_file_name.txt

cat $TMP_DIR/file_cmd_output.txt | /bin/cut -d ":" -f 1  >> $TMP_DIR/forbidden_file_name.txt


declare forbidden_file_name=(`cat $TMP_DIR/forbidden_file_name.txt | cut -d "." -f 1 | xargs` )

name_i=0
name_len=${#forbidden_file_name[@]}
while [ $name_i -lt $name_len ]
do 
    SQL_GET_UID="select userid from pd_files where file_real_name='${forbidden_file_name[$name_i]}';"
    SQL_GET_USER_EMAIL="select email from pd_users where userid='$OWNER_ID';"
    SQL_DEL_FILE="delete from pd_files where file_real_name='${forbidden_file_name[$name_i]}';"

    OWNER_ID=`/usr/bin/mysql -sN -h $DB_HOSTNAME -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME -e "$SQL_GET_UID"`
    OWNER_EMAIL=`/usr/bin/mysql -sN -h $DB_HOSTNAME -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME -e "$SQL_GET_USER_EMAIL"`

    FULLNAME_FILE_NAME=`/bin/grep ${forbidden_file_name[$name_i]} $TMP_DIR/forbidden_file_name.txt`
    FULLNAME_FILE_TYPE=`$FILE_CMD_PATH/file -b $FULLNAME_FILE_NAME`

    [ ! -d /srv/forbidden_files/`date +%Y/%m/%d` ] && mkdir -p /srv/forbidden_files/`date +%Y/%m/%d`

    mv `grep ${forbidden_file_name[$name_i]} $TMP_DIR/forbidden_file_name.txt ` /srv/forbidden_files/`date +%Y/%m/%d`

    echo "`date +%Y-%m-%d\ %H:%M` $FULLNAME_FILE_NAME $OWNER_ID $OWNER_EMAIL $FULLNAME_FILE_TYPE " >> /srv/forbidden.log
   mysqldump -u root -phonlivwlyw  phpdisk_honlivhp pd_files | sed -e 's#),(#)\n(#g'  | grep ${forbidden_file_name[$name_i]} >> $TMP_DIR/restore_deleted_file.sql
   /usr/bin/mysql -sN -h $DB_HOSTNAME -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME -e "$SQL_DEL_FILE"

let name_i++
done
##移动记录文件列表，以备后查。
> $TMP_DIR/forbidden_file_name.txt
if [ -s $TMP_DIR/file_cmd_output.txt ]
then 
 mv $TMP_DIR/file_cmd_output.txt $TMP_DIR/`date +%Y%m%d%H%M`-file_cmd_output.txt
 echo "" > $TMP_DIR/file_cmd_output.txt
else
 echo "" > $TMP_DIR/file_cmd_output.txt
fi

