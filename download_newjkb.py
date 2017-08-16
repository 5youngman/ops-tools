#!/usr/bin/python
import urllib 
import httplib2 
import time
import os
import sys 
from datetime import datetime,date

# usage: download_jkb.py year mouth day
# sample : download_jkb.py 2015 09 28
# http://szb.jkb.com.cn/jkbpaper/images/1/2015-09/28/01/2015092801_pdf.pdf

dayofweek = datetime.now().weekday()
if dayofweek == 6 : 
  exit("today is not workday!")
print dayofweek
  
YEAR=sys.argv[1]
MOUTH=sys.argv[2]
DAY=sys.argv[3]

IMAGEURL_DATE=YEAR+'-'+MOUTH+'/'+DAY
WGET_DATE=YEAR+MOUTH+DAY

http= httplib2.Http() 
LOGIN_URL='http://passport.jkb.com.cn/http/formlogin.aspx'
FIRST_URL='http://szb.jkb.com.cn/jkbpaper/html/'+IMAGEURL_DATE+'/node_2.htm'

params_login = urllib.urlencode({'url': FIRST_URL,
			  'name': 'user',
			  'password':'111111',
			  'submit':'%E7%99%BB%E5%BD%95' 
			})
headers_login = {
	'Content-type':'application/x-www-form-urlencoded',
	'User-Agent':'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; WOW64; Trident/6.0)'
}

response_login,content_login = http.request(LOGIN_URL,'POST',params_login,headers=headers_login)
cookie=response_login['set-cookie']
CNSTOCK_PASSPORT=cookie[cookie.find('CNSTOCK_PASSPORT'):cookie.find('domain')]
CNSTOCK_SSO=cookie[cookie.find('CNSTOCK_SSO'):cookie.rfind('domain')]
headers_download = {
	'Cookie': CNSTOCK_PASSPORT + CNSTOCK_SSO,
        'User-Agent':'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; WOW64; Trident/6.0)'
}

def get_pdf(n):	
	IMAGE_URL='http://szb.jkb.com.cn/jkbpaper/html/'+IMAGEURL_DATE+'/node_'+str(n)+'.htm' 
	response_download,content_download = http.request(IMAGE_URL,'GET',headers=headers_download)
	pdf=content_download[content_download.find('.pdf')-50:content_download.find('.pdf')+4]
	CMD_URL='http://szb.jkb.com.cn/jkbpaper/'+pdf[pdf.find('images'):]
	CMD_PATH='/var/script/jkb/'+WGET_DATE+str(0)+str(i-1)+'.pdf'
	cmd='wget '+CMD_URL+' --header="Cookie' + ':' + CNSTOCK_PASSPORT + CNSTOCK_SSO +'" -O '+ CMD_PATH
	os.system(cmd)

for i in range(2,10):
	get_pdf(i)
