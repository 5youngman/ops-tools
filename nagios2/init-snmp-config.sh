#!/bin/bash
# 通过自动判断交换机型号，来判断需要初始化的snmp检测项目所需要的特定参数
# 作为初始化配置的第二步执行。
# 

if !([ ! -z $1 ] && [ -z $2 ])
then
  { echo -en "Usage:$0 NetCode \n E.g.:$0 XSGS\n"
    exit 127
  }
fi

TemplateFile=my-switch.cfg.sample
HostsFile=my-switch-hosts.txt
SNMPInfoFile=my-switch-oid.txt

echo "make sure you have run init-switch-config.sh first"
echo "make sure you have defined the command used by $TemplateFile"
echo "make sure your $HostsFile and /etc/hosts is same and up to date"
echo "make sure you have copy all need mib file to /usr/share/snmp/mibs/"

read -n 1 -p "Press any key to continue..."

if [ ! -r `pwd`/$TemplateFile ] || [ ! -r `pwd`/$HostsFile ] 
  then 
    echo File $TemplateFile or $HostsFile do NOT EXIST or Can NOT BE READ!
    exit 1
elif [ ! -d `pwd`/$1 ]
  then
    echo Directory $1 do NOT EXIST in `pwd`!
    exit 2
fi

SWITCHOIDCODE=( `awk '/SNMP_/{print $3}' $TemplateFile | xargs` )
SWITCHNAME=( `sed -n -e "/$1-BEGIN/,/$1-END/p" $HostsFile | sed '/^#/d' | cut -d " " -f 2 | xargs` )

oid_len=${#SWITCHOIDCODE[@]}
oid_i=0
while [ $oid_i -lt $oid_len ]
  do
    FUNCCODE=${SWITCHOIDCODE[$oid_i]}

    FUNCMIB=( `awk -F : '$1~/'"$FUNCCODE"'/ && $2~/MIB/ {print $3}' $SNMPInfoFile` )
    FUNCOID=( `awk -F : '$1~/'"$FUNCCODE"'/ && $2~/OID/ {print $3}' $SNMPInfoFile` )

    sw_len=${#SWITCHNAME[@]}
    sw_i=0
    while [ $sw_i -lt $sw_len ]
      do

        if [ ! -w $1/${SWITCHNAME[$sw_i]}.cfg ]
          then 
            echo file $1/${SWITCHNAME[$sw_i]}.cfg do NOT EXIST or Can NOT BE WRITE!
	    let sw_i++
	    continue
        fi

        SWITCHADDR=`grep ${SWITCHNAME[$sw_i]} $HostsFile | cut -d " " -f 1 | xargs`

        SWOID_NEW=`snmpwalk -m ${FUNCMIB[0]} -v 2c -c snmppassword $SWITCHADDR ${FUNCOID[0]} | awk -F [=:] '$4!~/No Such/ && $5!~/0/ {print $3}'`
        SWOID_OLD=`snmpwalk -m ${FUNCMIB[1]} -v 2c -c snmppassword $SWITCHADDR ${FUNCOID[1]} | awk -F [=:] '$4!~/No Such/ && $5!~/0/ {print $3}'`
        SWOID_HW=`snmpwalk -m ${FUNCMIB[2]} -v 2c -c snmppassword $SWITCHADDR ${FUNCOID[2]} | awk -F [=:] '$4!~/No Such/ && $5!~/0/ {print $3}'`

        if [ -z $SWOID_OLD ] && [ -z $SWOID_NEW ] && [ -z $SWOID_HW ]
          then
            echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR --- can not find mib style "

        elif [ -n $SWOID_OLD ] && [ -z $SWOID_NEW ] && [ -z $SWOID_HW ]
          then
            #switch has a h3c old style mib
            sed -i -e "s/$FUNCCODE/$SWOID_OLD/g" $1/${SWITCHNAME[$sw_i]}.cfg
            echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR --- | $SWOID_OLD | H3C OLD STYLE!"

	elif [ -z $SWOID_OLD ] && [ -n $SWOID_NEW ] && [ -z $SWOID_HW ]
	  then
	    #switch has a h3c new style mib
	    sed -i -e "s/$FUNCCODE/$SWOID_NEW/g" $1/${SWITCHNAME[$sw_i]}.cfg
            echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR --- | $SWOID_NEW | H3C NEW STYLE!"

	elif [ -z $SWOID_OLD ] && [ -z $SWOID_NEW ] && [ -n $SWOID_HW ]
	  then
	    #switch has a huawei style mib
	    sed -i -e "s/$FUNCCODE/$SWOID_HW/g" $1/${SWITCHNAME[$sw_i]}.cfg
	    echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR --- | $SWOID_HW | Huawei STYLE!"

	elif  [ -z $SWOID_NEW ] && ( [ -n $SWOID_OLD ] || [ -n $SWOID_HW ] )
	  then
	    #switch has both huawei and h3c old style mib
	    sed -i -e "s/$FUNCCODE/$SWOID_HW/g" $1/${SWITCHNAME[$sw_i]}.cfg
	    echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR --- | $SWOID_HW | $SWOID_OLD | Huawei and H3C OLD STYLE!"
	else 
	    echo "${SWITCHNAME[$sw_i]} --- $SWITCHADDR ---| $SWOID_OLD | $SWOID_NEW | $SWOID_HW | I Can Not Handle That !"
	fi

        let sw_i++
    done

    let oid_i++
done
