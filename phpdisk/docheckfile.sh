#!/bin/bash
#
#
# check-forbidden-files.sh - 一个检查用户上传文件格式的小脚本。每天5分钟
#执行一次。用于防止用户通过修改后缀名的形式上传非法文件。
#
#              <xiyangliu1987@gmail.com>
#              http://www.xiyang-liu.com
#
# 创建时间：2013年2月26日一个阳光明媚的上午
#

##设置全局变量

FILE_POOL_PATH=$1
FILE_CMD_PATH=/srv/file/bin
TMP_DIR=/tmp
WHITE_LIST="(.cbm|.bak|index.htm|.mdb)"


#声明函数

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
declare Re_permit_file_type=("Composite Document File V2 Document" "Microsoft Word 2007+" "Microsoft PowerPoint 2007+" "Microsoft Excel 2007+" "PDF document" "JPEG image data" "PC bitmap" "PNG image data" "text")

Re_type_i=0
Re_type_len=${#Re_permit_file_type[@]}
while [ $Re_type_i -lt $Re_type_len ]
do  
   /bin/sed -i -e "/${Re_permit_file_type[$Re_type_i]}/d" "$1"
let Re_type_i++
done
}

function JudgeForbiddenFile() {
Ju_FILE_CMD_PATH=/srv/file/bin
cat "$1" | while read Ju_File_Name
do 
   Ju_FILE_TYPE=`$Ju_FILE_CMD_PATH/file -b "$Ju_File_Name"`
   echo "`date +%Y-%m-%d\ %H:%M` "$Ju_File_Name"  $Ju_FILE_TYPE "
done

}


##输出所有文件的检测结果到临时文件中

cd $FILE_POOL_PATH
$FILE_CMD_PATH/file `ls | grep -v -E "$WHITE_LIST" ` > $TMP_DIR/file_cmd_output.txt

RemovePermitFile $TMP_DIR/file_cmd_output.txt 


##处理RAR压缩文件


[ ! -d /tmp/unrar.tmp/ ] && mkdir /tmp/unrar.tmp/

grep "RAR archive data" $TMP_DIR/file_cmd_output.txt | cut -d ":" -f 1 | while read rarfile
do
if  `/usr/bin/unrar T -p- $FILE_POOL_PATH/$rarfile > /dev/null 2>&1` 
then
  echo $rarfile
  /usr/bin/unrar x -y -p- $FILE_POOL_PATH/$rarfile /tmp/unrar.tmp/ > /dev/null
  >$TMP_DIR/file_cmd_output_unrar.txt
  EchoRecursiveFile /tmp/unrar.tmp/ | while read Ech_Out_unrar
  do
    $FILE_CMD_PATH/file "$Ech_Out_unrar" >> $TMP_DIR/file_cmd_output_unrar.txt
  done
echo ========RAR BEFORE BEGIN===========
cat $TMP_DIR/file_cmd_output_unrar.txt
echo ========RAR BEFORE END===========  
RemovePermitFile $TMP_DIR/file_cmd_output_unrar.txt
echo ========RAR AFTER BEGIN===========
  cat $TMP_DIR/file_cmd_output_unrar.txt
echo ========RAR AFTER END===========

  if [ ! -s $TMP_DIR/file_cmd_output_unrar.txt ]
  then
   /bin/sed -i -e "/$rarfile/d" $TMP_DIR/file_cmd_output.txt
  else
  cat $TMP_DIR/file_cmd_output_unrar.txt | /bin/cut -d ":" -f 1  > $TMP_DIR/forbidden_file_name_unrar.txt
   JudgeForbiddenFile $TMP_DIR/forbidden_file_name_unrar.txt
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
  >$TMP_DIR/file_cmd_output_unzip.txt
  EchoRecursiveFile /tmp/unzip.tmp/ | while read Ech_Out_unzip
  do
    $FILE_CMD_PATH/file "$Ech_Out_unzip" >> $TMP_DIR/file_cmd_output_unzip.txt
  done

echo ========ZIP BEFORE BEGIN===========
cat $TMP_DIR/file_cmd_output_unzip.txt
echo ========ZIP BEFORE END===========

  RemovePermitFile $TMP_DIR/file_cmd_output_unzip.txt
echo ========ZIP AFTER BEGIN===========
  cat $TMP_DIR/file_cmd_output_unzip.txt
echo ========ZIP AFTER END===========

  if [ ! -s $TMP_DIR/file_cmd_output_unzip.txt ]
  then
  /bin/sed -i -e "/$zipfile/d" $TMP_DIR/file_cmd_output.txt
  else  
  cat $TMP_DIR/file_cmd_output_unzip.txt | /bin/cut -d ":" -f 1  > $TMP_DIR/forbidden_file_name_unzip.txt
  JudgeForbiddenFile $TMP_DIR/forbidden_file_name_unzip.txt
  fi

  rm -rf /tmp/unzip.tmp/
fi
done


##输出过滤后剩余的文件条目，也就是非法文件类型的条目到 forbidden_file_name.txt

cat $TMP_DIR/file_cmd_output.txt | /bin/cut -d ":" -f 1  >> $TMP_DIR/forbidden_file_name.txt

#JudgeForbiddenFile $TMP_DIR/forbidden_file_name.txt

>$TMP_DIR/forbidden_file_name.txt
>$TMP_DIR/file_cmd_output.txt
