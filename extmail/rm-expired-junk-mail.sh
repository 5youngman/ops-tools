#!/bin/bash
#删除已经过期（超过30天）的垃圾邮件

DB_HOSTNAME="localhost"
DB_PORT="3306"
DB_USERNAME="root"
DB_PASSWORD="password"
DB_NAME="extmail"

declare domains=( `mysql -sN -h $DB_HOSTNAME -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME -e "select domain from domain;" | xargs` )

dlen=${#domains[@]}
di=0

while [ $di -lt "$dlen" ]
do
  declare users=( `mysql -sN -h $DB_HOSTNAME -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME -e "select uid from mailbox where domain='${domains[$di]}'; 
" | xargs` )

  ulen=${#users[@]}
  ui=0

  while [ $ui -lt "$ulen" ]
    do
    JMDIR=/home/domains/${domains[$di]}/${users[$ui]}/Maildir/.Junk
    BMDIR=/home/SpamMail/${domains[$di]}/${users[$ui]}/`date +%Y-%m-%d`/
    MDIR=/home/domains/${domains[$di]}/${users[$ui]}/Maildir
    if [ ! -d $JMDIR/ ] || [ "`ls -A $JMDIR`" == "" ]
    then
     let ui++ 
     continue
    fi
    echo "" >/tmp/jmail_list-`date +%Y-%m-%d`.txt
    ls $JMDIR/cur/ | sed -e "s#^#cur/#g" >>/tmp/jmail_list-`date +%Y-%m-%d`.txt
    echo " " >>/tmp/jmail_list-`date +%Y-%m-%d`.txt
    ls $JMDIR/new/ | sed -e "s#^#new/#g" >>/tmp/jmail_list-`date +%Y-%m-%d`.txt

    cat /tmp/jmail_list-`date +%Y-%m-%d`.txt | while read FILENAME
    do
    Format_Date=`grep '^Date:' $JMDIR/$FILENAME | head -n 1 | cut -c6-`
    Int_Now=`/bin/date +%s`
    ( /bin/date -d "$Format_Date" +%s >/dev/null 2>&1 ) && Int_Date=`/bin/date -d "$Format_Date" +%s` || Int_Date=`/bin/date +%s`

    expire_time=$[ $Int_Now - $Int_Date ]
    range_time=$[ 30*24*60*60 ]

    if [ $expire_time -gt $range_time ] 
     then 
       [ ! -d $BMDIR ] && mkdir -p $BMDIR/cur/ $BMDIR/new/
       mv $JMDIR/$FILENAME $BMDIR/$FILENAME
       echo "mail $JMDIR/$FILENAME backup finished!"
    fi
    done

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

    head -1 $MDIR/maildirsize > /tmp/maildirsize-rm-expire-`date +%Y-%m-%d`.tmp
    printf "%12s%12s\n" $T_SIZE $T_COUNT >>/tmp/maildirsize-rm-expire-`date +%Y-%m-%d`.tmp
    mv -f /tmp/maildirsize-rm-expire-`date +%Y-%m-%d`.tmp $MDIR/maildirsize 
  let ui++
  done
let di++
done
rm -f /tmp/jmail_list-`date +%Y-%m-%d`.txt

