#!/bin/bash

HOSTFILE=switch-hosts.txt

declare IP=(`awk '!/^#/{print $1}' $HOSTFILE | xargs `)

ilen=${#IP[@]}  
##初始化users数组计数器
ii=0
while [ $ii -lt $ilen ]
do 
  ti=0
  tlen=100
  while  [ $ii -lt $ilen ] && [ $ti -lt $tlen ]
   do
    (
    echo ${IP[$ii]}
    nu=`ping -w 1 -c 1 ${IP[$ii]} | grep "100%" | wc -l `
    if [ $nu = 0 ]
    then
     echo -e "${IP[$ii]} \c" > version-${IP[$ii]}.txt
     (
      sleep 1 
      echo "password"
      sleep 1
      echo "su"
      sleep 1
      echo "password"
      sleep 1
      echo "dis version"
      sleep 1
      echo "quit"
     ) | telnet ${IP[$ii]} | grep uptime | head -1 | cut -d " " -f 2 >> version-${IP[$ii]}.txt
    fi
    )& 
    let ii++
    let ti++ 
   done
  wait
done
cat version-*.txt > switch-version.txt
rm version-*.txt -f
