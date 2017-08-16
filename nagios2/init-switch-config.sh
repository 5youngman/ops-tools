#!/bin/bash
# 从交换机模板文件初始化生成nagios使用的交换机配置文件。
# 批量生成整个汇聚园区的所有交换机配置。
# 
# 需要事先获取，并在HostFile中逐一列出。并且在SwitchModFile
# 文件中包含其硬件配置对应信息。
#
# 脚本接受一个参数，没有参数控制。合法参数为园区缩写例如XXJSL
# 其交换机明明方式为 园区缩写-型号代码-位置代码
# 例如
#   名字为XXJSL-S3426V2SI-4-4的交换机
# 其HostFile对应为
#    10.1.34.44 XXJSL-S3126V2SI-4-4
#
# 此脚本生成交换机配置文件，替换文件中交换机IP地址、交换机名、交换机描述 3个选项。

if !([ ! -z $1 ] && [ -z $2 ])
then
  { echo -en "Usage:$0 NetCode \n E.g.:$0 XSGS\n"
    exit 127
  }
fi

TemplateFile=my-switch.cfg.sample
HostsFile=my-switch-hosts.txt

if [ ! -r `pwd`/$TemplateFile ] || [ ! -r `pwd`/$HostsFile ]
then 
echo File $TemplateFile or $HostsFile do NOT EXIST or Can NOT BE READ!
exit 1
elif [ ! -d `pwd`/$1 ]
then
echo Directory $1 do NOT EXIST in `pwd`!
exit 2
fi

SWITCHNAME=( `sed -n -e "/$1-BEGIN/,/$1-END/p" $HostsFile | sed '/^#/d' | cut -d " " -f 2 | xargs` )
SWITCHADDR=( `sed -n -e "/$1-BEGIN/,/$1-END/p" $HostsFile | sed '/^#/d' | cut -d " " -f 1 | xargs` )

sw_len=${#SWITCHNAME[@]}
sw_i=0
while [ $sw_i -lt $sw_len ]

do
cp -f $TemplateFile $1/${SWITCHNAME[$sw_i]}.cfg

echo ${SWITCHNAME[$sw_i]} --- ${SWITCHADDR[$sw_i]}
sed -i -e "s/Host_my-Switch/${SWITCHNAME[$sw_i]}/g" $1/${SWITCHNAME[$sw_i]}.cfg
sed -i -e "s/Addr_my-Switch/${SWITCHADDR[$sw_i]}/g" $1/${SWITCHNAME[$sw_i]}.cfg

let sw_i++

done

