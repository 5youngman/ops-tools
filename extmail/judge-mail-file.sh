#!/bin/bash

if !([ ! -z $1 ] && [ -z $2 ]) 
then
  { echo -en "Usage:$0 MailFullPath \n" 
   exit 1
  }
fi


[ !-f $1 ] && echo 'Mail body file does't existence!' && exit 2

Judge_Result=`sed '/X-DSPAM-Result/,/Received/d' $1 | /usr/bin/dspam --client --mode=teft --user extmail --classify | cut -d ';' -f 2 | cut -d '"' -f 2`

[ "$Judge_Result" == "Spam" ] && echo "this Mail is Spam" || echo "this Mail is Innocent"

exit 0
