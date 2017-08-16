#!/bin/bash
# 自动完成交换机硬件更换后一切配置的更新
# 接受3个参数 园区代码 原始名称 新名称，例如
# change-switch-mode.sh XXJSL XXJSL-E026SI-4-2 XXJSL-S3126V2SI-4-2 
# 涉及到如下3个文件的变更
#    my-switch-hosts.txt
#    /etc/hosts
#    $1/$2.cfg --> $1/$3.cfg

if !([ ! -z $1 ] && [ ! -z $2 ] && [ ! -z $3 ] && [ -z $4 ])                             
then  
  { echo -en "Usage:$0 NetCode SwitchOldName SwitchNewName \n E.g.:$0 XXJSL XXJSL-E026SI-4-2 XXJSL-S3126V2SI-4-2\n"
    exit 127
  }
fi

HostsFile=my-switch-hosts.txt
SNMPInfoFile=my-switch-oid.txt

if [ ! -r `pwd`/$HostsFile ] 
then 
	echo File $TemplateFile do NOT EXIST or Can NOT BE READ!
	exit 1
elif [ ! -w `pwd`/$1/$2.cfg ]
then
	echo File $2 in `pwd`/$1 can not be write !
	exit 2
elif [ $2 == $3 ]
then 
	echo New Name $3 is same with old name $2
	exit 3
fi

sed -i -e "s/$2/$3/g" `pwd`/$HostsFile
sed -i -e "s/$2/$3/g" /etc/hosts
sed -i -e "s/$2/$3/g" /etc/nagios/objects/host-groups.cfg
sed -e "s/$2/$3/g" `pwd`/$1/$2.cfg > `pwd`/$1/$3.cfg

SWITCHADDRA=`grep $3 `pwd`/$HostsFile | cut -d " " -f 1`
SWITCHADDRB=`grep address $1/$3.cfg | awk '{print $2}'`
SWITCHADDR=$SWITCHADDRA

if [ "$SWITCHADDRA " != "$SWITCHADDRB " ]
then
  SWITCHADDR=$SWITCHADDRB
  echo WARNING: "hostfile don\'t have $2 item"
fi
FOID_OLD=( `awk  '/check_switch_/{print $3}' $1/$2.cfg | xargs` )
OID_OLD=( `awk  '/check_switch_/{print $3}' $1/$2.cfg | cut -d . -f 1 | xargs` )

oid_count=${#OID_OLD[@]}
oid_i=0
while [ $oid_i -lt $oid_count ]
do
FUNCCODE=`grep ${OID_OLD[$oid_i]} $SNMPInfoFile | cut -d : -f 1`

FUNCMIB=( `awk -F : '$1~/'"$FUNCCODE"'/ && $2~/MIB/ {print $3}' $SNMPInfoFile` )
FUNCOID=( `awk -F : '$1~/'"$FUNCCODE"'/ && $2~/OID/ {print $3}' $SNMPInfoFile` )

SWOID_NEW=`snmpwalk -m ${FUNCMIB[0]} -v 2c -c snmppassword $SWITCHADDR ${FUNCOID[0]} | awk -F [=:] '$4!~/No Such/ && $5!~/0/ {print $3}'`
SWOID_OLD=`snmpwalk -m ${FUNCMIB[1]} -v 2c -c snmppassword $SWITCHADDR ${FUNCOID[1]} | awk -F [=:] '$4!~/No Such/ && $5!~/0/ {print $3}'`
SWOID_HW=`snmpwalk -m ${FUNCMIB[2]} -v 2c -c snmppassword $SWITCHADDR ${FUNCOID[2]} | awk -F [=:] '$4!~/No Such/ && $5!~/0/ {print $3}'`

if [ -z $SWOID_OLD ] && [ -z $SWOID_NEW ] && [ -z $SWOID_HW ]
   then
	echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR --- can not find mib style "

elif [ -n $SWOID_OLD ] && [ -z $SWOID_NEW ] && [ -z $SWOID_HW ]
   then
   	#switch has a h3c old style mib
        sed -i -e "s/${FOID_OLD[$oid_i]}/$SWOID_OLD/g" $1/$3.cfg
        echo "$3 --- $SWITCHADDR --- | $SWOID_OLD | H3C OLD STYLE!"
elif [ -z $SWOID_OLD ] && [ -n $SWOID_NEW ] && [ -z $SWOID_HW ]
  then
        #switch has a h3c new style mib
        sed -i -e "s/${FOID_OLD[$oid_i]}/$SWOID_NEW/g" $1/$3.cfg
        echo "$3 --- $SWITCHADDR --- | $SWOID_NEW | H3C NEW STYLE!"
elif [ -z $SWOID_OLD ] && [ -z $SWOID_NEW ] && [ -n $SWOID_HW ]
  then
        #switch has a huawei style mib
        sed -i -e "s/${FOID_OLD[$oid_i]}/$SWOID_HW/g" $1/$3.cfg
        echo "$3 --- $SWITCHADDR --- | $SWOID_HW | Huawei STYLE!"

elif  [ -z $SWOID_NEW ] && ( [ -n $SWOID_OLD ] || [ -n $SWOID_HW ] )
  then
        #switch has both huawei and h3c old style mib
        sed -i -e "s/${FOID_OLD[$oid_i]}/$SWOID_HW/g" $1/$3.cfg
        echo "$3 --- $SWITCHADDR --- | $SWOID_HW | $SWOID_OLD | Huawei and H3C OLD STYLE!"
else 
        echo "$3 --- $SWITCHADDR ---| $SWOID_OLD | $SWOID_NEW | $SWOID_HW | I Can Not Handle That !"
fi
let oid_i++
done

rm -f `pwd`/$1/$2.cfg
echo File `pwd`/$1/$2.cfg change to `pwd`/$1/$3.cfg
