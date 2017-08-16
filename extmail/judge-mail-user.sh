#!/bin/bash
# 判断用户所有邮件中，哪些是正常邮件，哪些是垃圾邮件，并自动归类到相应的文件夹
# 将用户所有邮件移动到特定的文件夹，使用dspam一个一个的处理。
# 根据处理结果，将邮件移回用户相应的文件夹中。
# dspam必须有经过训练的数据库，能正确识别垃圾邮件才可以。
# 执行完脚本后，需要登陆一下用户的webmail，以保证，邮件数量显示正确。
#                                       by xiyang liu
#                                        xiyangliu1987@163.com 66954

if !([ ! -z $1 ] && ([ -z $2 ] || [ "$2" == "--recovery" ]) && [ -z $3 ]) 
then
  { echo -en "Usage:$0 username@domainname.com [--recovery] \n E.g.:$0 manager@honliv.com\n" 
   exit 1
  }
fi

User_Name=`echo $1 | cut -d '@' -f 1`
Domain_Name=`echo $1 | cut -d '@' -f 2`
Judge_Folder=/home/Judge_Spam
MDIR=/home/domains/$Domain_Name/$User_Name/Maildir

[ ! -d $Judge_Folder ] && echo 'Judge Folder is not existence!' && exit 2


if [ -f /tmp/judge-mail-user.lock ]
then
 [ "`cat /tmp/judge-mail-user.lock`" != "$1" ] && echo "you must process recovery Judge of user `cat /tmp/judge-mail-user.lock` first !"

 echo "Process recovery Judge of user `cat /tmp/judge-mail-user.lock` ..."
 User_Name=`cat /tmp/judge-mail-user.lock | cut -d '@' -f 1`
 Domain_Name=`cat /tmp/judge-mail-user.lock | cut -d '@' -f 2`

 ls $Judge_Folder/cur/ > /tmp/cur_mail_list-`date +%Y-%m-%d`.txt
 ls $Judge_Folder/new/ > /tmp/new_mail_list-`date +%Y-%m-%d`.txt

elif [ "$2" == "--recovery" ]
then
 echo "Process recovery Judge of user $1 ..."
 User_Name=`echo $1 | cut -d '@' -f 1`
 Domain_Name=`echo $1 | cut -d '@' -f 2`

 ls $Judge_Folder/cur/ > /tmp/cur_mail_list-`date +%Y-%m-%d`.txt
 ls $Judge_Folder/new/ > /tmp/new_mail_list-`date +%Y-%m-%d`.txt
else
  echo $User_Name@$Domain_Name > /tmp/judge-mail-user.lock
  echo "Judge Mail for user `cat /tmp/judge-mail-user.lock` ..."
  rm -rf $Judge_Folder/*
  mkdir $Judge_Folder/new
  mkdir $Judge_Folder/cur

  [ "`ls -A $MDIR/cur/`" != "" ] && mv $MDIR/cur/* $Judge_Folder/cur/
  [ "`ls -A $MDIR/new/`" != "" ] && mv $MDIR/new/* $Judge_Folder/new/

  [ "`ls -A $MDIR/.Junk/cur/`" != "" ] && mv $MDIR/.Junk/cur/* $Judge_Folder/cur/
  [ "`ls -A $MDIR/.Junk/new/`" != "" ] && mv $MDIR/.Junk/new/* $Judge_Folder/new/

  ls $Judge_Folder/cur/ > /tmp/cur_mail_list-`date +%Y-%m-%d`.txt
  ls $Judge_Folder/new/ > /tmp/new_mail_list-`date +%Y-%m-%d`.txt

fi


function Judge_Mail()
{

  FILENAME=$1
  TYPE=$2

  Judge_Result=`sed '/X-DSPAM-Result/,/Received/d' $Judge_Folder/$TYPE/$FILENAME | /usr/bin/dspam --client --mode=teft --user extmail --classify | cut -d ';' -f 2 | cut -d '"' -f 2`

  if [ "$Judge_Result" == "Spam" ]
  then
    {
     echo -en "$FILENAME is Spam\n    move to $MDIR/.Junk/$TYPE/\n"
     [ ! -d $MDIR/.Junk/$TYPE/ ] && ( mkdir -p $MDIR/.Junk/$TYPE/ ; chown vuser.vgroup $MDIR/.Junk/$TYPE/ )
     mv $Judge_Folder/$TYPE/$FILENAME  $MDIR/.Junk/$TYPE/$FILENAME
    }
  else
    {
     echo -en "$FILENAME is Innocent\n   move to $MDIR/$TYPE/\n"
     [ ! -d $MDIR/$TYPE/ ] && ( mkdir -p $MDIR/$TYPE/ ; chown vuser.vgroup $MDIR/$TYPE/ )
     mv $Judge_Folder/$TYPE/$FILENAME  $MDIR/$TYPE/$FILENAME
    }
  fi
}



cat /tmp/cur_mail_list-`date +%Y-%m-%d`.txt | while read CUR_MAIL_FILE
do
 Judge_Mail $CUR_MAIL_FILE cur
done

cat /tmp/new_mail_list-`date +%Y-%m-%d`.txt | while read NEW_MAIL_FILE
do
 Judge_Mail $NEW_MAIL_FILE new
done

if [ ! -f $MDIR/maildirsize ]
 then 
  echo $MDIR/maildirsize do not existance
  exit 3 
fi

SIZE_Dnew=`du -cb $MDIR/new | grep total | cut -f 1`
SIZE_Dcur=`du -cb $MDIR/cur | grep total | cut -f 1`
SIZE_DSent=`du -cb $MDIR/.Sent | grep total | cut -f 1`
SIZE_DTrash=`du -cb $MDIR/.Trash | grep total | cut -f 1`

COUNT_Dnew=`ls -R $MDIR/new | grep -v home | wc -l`
COUNT_Dcur=`ls -R $MDIR/cur | grep -v home | wc -l`
COUNT_DSent=`ls -R $MDIR/.Sent | grep -v home | wc -l`
COUNT_DTrash=`ls -R $MDIR/.Trash | grep -v home | wc -l`

T_SIZE=$[ $SIZE_Dnew + $SIZE_Dcur + $SIZE_DSent + $SIZE_DTrash ]
T_COUNT=$[ $COUNT_Dnew + $COUNT_Dcur + $COUNT_DSent + $COUNT_DTrash ]

head -1 $MDIR/maildirsize > /tmp/maildirsize-`date +%Y-%m-%d`.tmp
printf "%12s%12s\n" $T_SIZE $T_COUNT >>/tmp/maildirsize-`date +%Y-%m-%d`.tmp
mv -f /tmp/maildirsize-`date +%Y-%m-%d`.tmp $MDIR/maildirsize

rm -f $MDIR/extmail-curcnt
rm -f $MDIR/extmail-curcache.db
rm -f $MDIR/.Junk/extmail-curcnt
rm -f $MDIR/.Junk/extmail-curcache.db

rm -f /tmp/cur_mail_list-`date +%Y-%m-%d`.txt
rm -f /tmp/new_mail_list-`date +%Y-%m-%d`.txt
rm -f /tmp/judge-mail-user.lock
