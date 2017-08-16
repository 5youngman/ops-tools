#!/bin/bash
# 添加新的snmp检测项目，并自动生成其特定参数
# 最大化的辅助用户批量添加配置。
# 需要预先准备好OID对应关系，并按格式生成在文件my-switch-oid.txt
#
# 脚本操作步骤和思路如下：
#  1 读取my-switch-oid.txt内容
#  2 第一次添加时，补充command.cfg文件相关命令配置
#  3 第一次添加时，补充my-switch.cfg.sample模板文件相关项目配置
#  4 按园区生成交换机配置文件
#
# 脚本接受两个参数，园区代码 功能代码 例如
#  append-snmp-config.sh XSGS SNMP_MEMUSAGE
# 功能代码必须在my-switch-oid.txt文件中定义好

if !([ ! -z $1 ] && [ ! -z $2 ] && [ -z $3 ]) 
then
  { echo -en "Usage:$0 NetCode FunctionCode \n E.g.:$0 XSGS SNMP_MEMUSAGE\n"
    exit 127
  }
fi

TemplateFile=my-switch.cfg.sample
HostsFile=my-switch-hosts.txt
SNMPInfoFile=my-switch-oid.txt
CMDFILE=/etc/nagios/objects/commands.cfg

FUNCCODE=$2

if [ ! -r `pwd`/$TemplateFile ] || [ ! -r `pwd`/$HostsFile ] || [ ! -r `pwd`/$SNMPInfoFile ] 
then 
	echo File $TemplateFile $HostsFile  or $SNMPInfoFile do NOT EXIST or Can NOT BE READ!
	exit 1
elif [ ! -d `pwd`/$1 ]
then
	echo Directory $1 do NOT EXIST in `pwd`!
	exit 2
elif [ -z "`grep $FUNCCODE $SNMPInfoFile`" ]
then
	echo you should define this $FUNCCODE function in $SNMPInfoFile first!
	exit 3
fi

FUNCMIB=( `awk -F : '$1~/'"$FUNCCODE"'/ && $2~/MIB/ {print $3}' $SNMPInfoFile` )
FUNCOID=( `awk -F : '$1~/'"$FUNCCODE"'/ && $2~/OID/ {print $3}' $SNMPInfoFile` )
CHK_CMD=( `awk -F : '$1~/'"$FUNCCODE"'/ && $2~/OID/ {print $4}' $SNMPInfoFile` )
FUNCDESC=( `awk -F : '$1~/'"$FUNCCODE"'/ && $2~/OID/ {print $5}' $SNMPInfoFile` )

if [ -z "`grep $CHK_CMD $CMDFILE`" ]
then
cat << !CMDDEFINE! >> $CMDFILE 

define command{
        command_name    $CHK_CMD
        command_line    \$USER1\$/check_snmp -H \$HOSTADDRESS\$ -C passwd -P 2c \$ARG1\$ -w \$ARG2\$ -c \$ARG3\$
        }

!CMDDEFINE!

fi


if [ -z "`grep $CHK_CMD $TemplateFile`" ]
then

cat << !TEMPLATEDEFINE! >> $1/${SWITCHNAME[$sw_i]}.cfg

# Monitor $FUNCDESC via SNMP

define service{
        use                     generic-service
        host_name               Host_my-Switch
        service_description     $FUNCDESC
        check_command           $CHK_CMD!-o $FUNCCODE!60!80
        }

!TEMPLATEDEFINE!

fi

SWITCHNAME=( `sed -n -e "/$1-BEGIN/,/$1-END/p" $HostsFile | sed '/^#/d' | cut -d " " -f 2 | xargs` )

sw_len=${#SWITCHNAME[@]}
sw_i=0
while [ $sw_i -lt $sw_len ]

do

if [ ! -w $1/${SWITCHNAME[$sw_i]}.cfg ]
then 
	echo file $1/${SWITCHNAME[$sw_i]}.cfg do NOT EXIST or Can NOT BE WRITE!
	let sw_i++
	continue
elif [ -n "`grep $CHK_CMD $1/${SWITCHNAME[$sw_i]}.cfg `" ]
then 
	echo file $1/${SWITCHNAME[$sw_i]}.cfg has configured $CHK_CMD!
	let sw_i++
	continue
fi

SWITCHADDR=`awk '/'"${SWITCHNAME[$sw_i]}"'/{print $1}' $HostsFile`

SWOID_NEW=`snmpwalk -m ${FUNCMIB[0]} -v 2c -c snmppassword $SWITCHADDR ${FUNCOID[0]} | awk -F [=:] '$4!~/No Such/ && $5!~/0/ {print $3}'`
SWOID_OLD=`snmpwalk -m ${FUNCMIB[1]} -v 2c -c snmppassword $SWITCHADDR ${FUNCOID[1]} | awk -F [=:] '$4!~/No Such/ && $5!~/0/ {print $3}'`
SWOID_HW=`snmpwalk -m ${FUNCMIB[2]} -v 2c -c snmppassword $SWITCHADDR ${FUNCOID[2]} | awk -F [=:] '$4!~/No Such/ && $5!~/0/ {print $3}'`

if [ -z $SWOID_OLD ] && [ -z $SWOID_NEW ] && [ -z $SWOID_HW ]
then
echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR --- can not find mib style "

elif [ -n $SWOID_OLD ] && [ -z $SWOID_NEW ] && [ -z $SWOID_HW ]
then
#switch has a h3c old style mib

cat << !OLDMIBSTYLE! >> $1/${SWITCHNAME[$sw_i]}.cfg 

# Monitor $FUNCDESC via SNMP

define service{
        use                     generic-service
        host_name               ${SWITCHNAME[$sw_i]}
        service_description     $FUNCDESC
        check_command           $CHK_CMD!-o $SWOID_OLD!60!80
        }

!OLDMIBSTYLE!

echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR --- | $SWOID_OLD | H3C OLD STYLE!"

elif [ -z $SWOID_OLD ] && [ -n $SWOID_NEW ] && [ -z $SWOID_HW ]
then
#switch has a h3c new style mib

cat <<!NEWMIBSTYLE! >> $1/${SWITCHNAME[$sw_i]}.cfg

# Monitor $FUNCDESC via SNMP
 
define service{
        use                     generic-service
        host_name               ${SWITCHNAME[$sw_i]}
        service_description     $FUNCDESC
        check_command           $CHK_CMD!-o $SWOID_NEW!60!80
        }

!NEWMIBSTYLE!

echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR --- | $SWOID_NEW | H3C NEW STYLE!"

elif [ -z $SWOID_OLD ] && [ -z $SWOID_NEW ] && [ -n $SWOID_HW ]
then

#switch has a huawei style mib

cat <<!HWMIBSTYLE! >> $1/${SWITCHNAME[$sw_i]}.cfg

# Monitor $FUNCDESC via SNMP

define service{
        use                     generic-service
        host_name               ${SWITCHNAME[$sw_i]}
        service_description     $FUNCDESC
        check_command           $CHK_CMD!-o $SWOID_HW!60!80
        }

!HWMIBSTYLE!

echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR --- | $SWOID_HW | Huawei STYLE!"

elif  [ -z $SWOID_NEW ] && ( [ -n $SWOID_OLD ] || [ -n $SWOID_HW ] )
then

#switch has both huawei and h3c old style mib

cat <<!HWMIBSTYLE! >> core-conv/${SWITCHNAME[$sw_i]}.cfg

# Monitor $FUNCDESC via SNMP

define service{
        use                     generic-service
        host_name               ${SWITCHNAME[$sw_i]}
        service_description     $FUNCDESC
        check_command           $CHK_CMD!-o $SWOID_HW!60!80
        }

!HWMIBSTYLE!

echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR --- | $SWOID_HW | Huawei and H3C OLD STYLE!"

else 
echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR ---| $SWOID_OLD | $SWOID_NEW | $SWOID_HW | I Can Not Handle That !"
fi

let sw_i++

done
