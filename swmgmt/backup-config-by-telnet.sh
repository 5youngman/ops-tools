#!/bin/bash
#使用telnet自动输入命令的形式备份交换机配置文件
#通过crontab设定每天自动执行。
#
PWD=`dirname $0`
PROG=`basename $0 .sh`
HOSTFILE=$PWD/switch-hosts.txt
VERSIONFILE=$PWD/switch-version.txt
LOGFILE=$PWD/log/$PROG.log
ERRORFILE=$PWD/log/$PROG.err
SWPASS=password
TFTPSERVER=10.1.17.17
TFTPPATH=/var/lib/tftpboot

function huawei()
{
( sleep 2
  echo "$SWPASS"
  sleep 2
  echo "su"
  sleep 2
  echo "$SWPASS"
  sleep 2
  echo "sys"
  sleep 2
  echo "tftp put vrpcfg.txt //$TFTPSERVER/$1.txt"
  sleep 5
  echo "quit"
  ) | telnet $1 > $PWD/log/$PROG-$1.tmp 2>&1
}
function huawei3com()
{
( sleep 2
  echo "$SWPASS"
  sleep 2 
  echo "su"
  sleep 2
  echo "$SWPASS"
  sleep 2
  echo "tftp $TFTPSERVER put vrpcfg.cfg $1.txt"
  sleep 5
  echo "quit"
  ) | telnet $1 > $PWD/log/$PROG-$1.tmp 2>&1

}
function h3cconfig()
{
( sleep 2
  echo "$SWPASS"
  sleep 2
  echo "su"
  sleep 2
  echo "$SWPASS"
  sleep 2
  echo "tftp $TFTPSERVER put config.cfg $1.txt"
  sleep 5
  echo "quit"
  ) | telnet $1 > $PWD/log/$PORG-$1.tmp 2>&1

}
function h3cstartup()
{
( sleep 2
  echo "$SWPASS"
  sleep 2
  echo "su"
  sleep 2
  echo "$SWPASS"
  sleep 2
  echo "tftp $TFTPSERVER put startup.cfg $1.txt"
  sleep 5
  echo "quit"
 ) | telnet $1 > $PWD/log/$PROG-$1.tmp 2>&1
}

>$ERRORFILE

declare IP=(`awk '!/^#/{print $1}' $VERSIONFILE | xargs `)
declare VER=(`awk '!/^#/{print $2}' $VERSIONFILE | xargs `)

ilen=${#IP[@]}  
vlen=${#VER[@]}

[ $ilen -eq $vlen ] || exit 1

ii=0

while [ $ii -lt $ilen ]
do
  ti=0
  tlen=100
  while [ $ii -lt $ilen ] && [ $ti -lt $tlen ]
  do
    (  #echo ${IP[$ii]} ............ ${VER[$ii]}
       case ${VER[$ii]} in
           E026-SI|E050|S2008|S5516)
           huawei ${IP[$ii]}
           ;;
           S3100V2-26TP-SI|S5120-28P-LI|S3100V2-26TP-PWR-EI|S5500-20TP-SI|S5500-24P-SI|S5500-28C-EI|S5120-52P-SI|S5120-28P-SI)
           h3cstartup ${IP[$ii]}
           ;;
           S3100-26C-SI|S3600V2-52TP-SI|S3600-28TP-SI|S3100-26T-SI|S3100-52P|S3100-52TP-SI|S3100-26TP-SI|S2126-EI|S5800-32C)
           h3cconfig ${IP[$ii]}
           ;;
           S3126C|S6502|S3928TP-SI|S3928P-SI|S3928P-EI|S3116C|S6506R|S3952P-SI|S5624P)
           huawei3com ${IP[$ii]}
           ;;
       esac
       if [ ! -s $TFTPPATH/${IP[$ii]}.txt ] 
       then
           echo `grep "${IP[$ii]} " $HOSTFILE | cut -d " " -f 2` >>$ERRORFILE 
           echo "`date +%Y%m%d` Switch `grep "${IP[$ii]} "  $HOSTFILE` Config Backup By Telnet failed!" >> $LOGFILE 
       fi
    )&
    let ii++
    let ti++
  done
  wait
done


timenow=`date +%Y/%m/%d`
mkdir /var/switch-cfg/$timenow -p
mv -f $TFTPPATH/*.txt /var/switch-cfg/$timenow/
if [ -s $ERRORFILE ]
then
  echo  "下列交换机 `cat $ERRORFILE | xargs` 配置文件备份失败" | mailx -s 交换机配置文件备份不完整 sample@qq.com
fi

cat $PWD/log/$PROG-*.tmp >> $PWD/log/$PROG-`date +%Y%m%d`.out
rm -f $PWD/log/$PROG-*.tmp
exit 0
