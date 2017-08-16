#!/bin/bash
#updatemaildirsize.sh username@domain.com
#手动更新maildirsize文件
#
#

if [ $1 ] 
 then 
  echo Process USER $1 
else 
  echo INPUT ERROR  
  exit 1
fi

USERNAME=`echo $1 | cut -d "@" -f 1`
DOMAIN=`echo $1 | cut -d "@" -f 2` 
MDIR=/home/domains/$DOMAIN/$USERNAME/Maildir

if [ ! -f $MDIR/maildirsize ]
 then 
  echo maildirsize do not existence
  exit 2
fi

SIZE_Dnew=`du -cb $MDIR/new | grep total | cut -f 1`
SIZE_Dcur=`du -cb $MDIR/cur | grep total |cut -f 1`
SIZE_DSent=`du -cb $MDIR/.Sent | grep total | cut -f 1`
SIZE_DTrash=`du -cb $MDIR/.Trash | grep total | cut -f 1`

COUNT_Dnew=`ls -R $MDIR/new | grep -v home | wc -l`
COUNT_Dcur=`ls -R $MDIR/cur | grep -v home | wc -l`
COUNT_DSent=`ls -R $MDIR/.Sent | grep -v home | wc -l`
COUNT_DTrash=`ls -R $MDIR/.Trash | grep -v home | wc -l`

T_SIZE=$[ $SIZE_Dnew + $SIZE_Dcur + $SIZE_DSent + $SIZE_DTrash ]
T_COUNT=$[ $COUNT_Dnew + $COUNT_Dcur + $COUNT_DSent + $COUNT_DTrash ]

head -1 $MDIR/maildirsize > /tmp/maildirsize.tmp
printf "%12s%12s\n" $T_SIZE $T_COUNT >>/tmp/maildirsize.tmp
cat /tmp/maildirsize.tmp
mv -f /tmp/maildirsize.tmp $MDIR/maildirsize 
