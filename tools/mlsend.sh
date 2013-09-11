#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

MLDATADIR=/home/postfix/mldata
MLNAME=$1
DOMAIN=$2
# 限制邮件列表大小
# 5M
#LIMIT_SIZE=5242880
# 10M
LIMIT_SIZE=10485760
# 20M
#LIMIT_SIZE=20967520
#解锁等待时间，单位：秒
LOCKWAIT=300

#检查文件该列表是否为锁定状态
#如果锁定则返回一个错误信号
#让qmail把邮件存为队列以后再处理
if [ -f $MLDATADIR/$DOMAIN/$MLNAME/lock ]; then
	ERRINFO="$0 said: $MLNAME@$DOMAIN is lock,retry"
	LOCKTIME=1
	while [ -f $MLDATADIR/$DOMAIN/$MLNAME/lock ]; do
		#ERRINFO=$ERRINFO"."
		sleep 1
		if [ $LOCKTIME -gt "$LOCKWAIT" ]; then
			#将邮件重新定向到一个临时文件里
			TMPMAIL="$MLDATADIR/$DOMAIN/$MLNAME/tmp/$HOSTNAME.$MLNAME.$DOMAIN.$SUBTIME.$NUM."`head -c32 /dev/urandom | sha1`
			sed '/^Return-Path:/Id' > $TMPMAIL
			#将邮件分割成邮件头(header)和邮件体(body)两个部分
			sed '/^$/q' $TMPMAIL > $TMPMAIL.header
			BAKTO=`grep '^From: ' $TMPMAIL.header | sed 's/From:/To:/I'`
			cat << BAKMAIL | sendmail -i -t -f $MLNAME@$DOMAIN
From: $MLNAME@$DOMAIN
$BAKTO
Subject: 邮件列表${MLNAME}@${DOMAIN}繁忙通知！
Content-Type: multipart/mixed;
 boundary="020806040501030605070803"

--020806040501030605070803
Content-Type: text/plain; charset=gb2312
Content-Transfer-Encoding: 8bit

尊敬的发件人，您好：
    您所发的邮件列表${MLNAME}@${DOMAIN}过于繁忙，请稍后重试。
您的原始邮件请看附件。谢谢！


--020806040501030605070803
Content-Type: message/rfc822;
 name="$MLNAME@$DOMAIN.eml"
Content-Transfer-Encoding: 8bit
Content-Disposition: attachment;
 filename="$MLNAME@$DOMAIN.eml"

`cat $TMPMAIL`


--020806040501030605070803--
BAKMAIL
			ERRINFO=$ERRINFO" $LOCKTIME times,retry is fail!bak to from."
			logger -p mail.info -t MailList "$ERRINFO"
			rm $TMPMAIL $TMPMAIL.header
			exit 0
		fi
		LOCKTIME=`expr $LOCKTIME + 1`
	done
	ERRINFO=$ERRINFO" $LOCKTIME times,unlock."
	logger -p mail.info -t MailList "$ERRINFO"
fi
#程序开始，锁定列表防止其他列表同时操作
echo 1 > $MLDATADIR/$DOMAIN/$MLNAME/lock || (logger -p mail.info -t MailList "Write lock file fail!!!" ; exit 1) || exit 1
#检查文件序列号是否是今天的第一封
#如果今天的日期和保存的日期不符合就复位为第一封
#并将今天的日期写如日期文件
OLDYTIME=`cat $MLDATADIR/$DOMAIN/$MLNAME/year`
YTIME=`date '+%Y'`
if [ "$YTIME" != "$OLDYTIME" ]; then
	echo $YTIME > $MLDATADIR/$DOMAIN/$MLNAME/year
fi
OLDSUBTIME=`cat $MLDATADIR/$DOMAIN/$MLNAME/today`
SUBTIME=`date '+%m%d'`
if [ "$SUBTIME" != "$OLDSUBTIME" ]; then
	echo $SUBTIME > $MLDATADIR/$DOMAIN/$MLNAME/today
	echo 1 > $MLDATADIR/$DOMAIN/$MLNAME/number
fi
#读取邮件序列号
#将新的序列号保存到文件
NUM=`cat $MLDATADIR/$DOMAIN/$MLNAME/number`
if [ "$NUM" = "" ]; then
	NUM=1
fi
TIME=`date '+%Y/%m/%d %H:%M:%S'`
#定义return-path的邮件
USER=$MLNAME
HOST=$DOMAIN
#读取列表里的所有用户并存如TO的变量
#如果列表为空则直接退出该程序
#同时解锁该邮件列表
TO=`cat $MLDATADIR/$DOMAIN/$MLNAME/mluser`
if [ "$TO" = "" ]; then
	rm -f $MLDATADIR/$DOMAIN/$MLNAME/lock || (logger -p mail.info -t MailList "Delete lock file fail!!!" ; exit 1) || exit 1
	logger -p mail.info -t MailList "$0 said: no mail address at $MLNAME@$DOMAIN[$NUM]."
	exit 0
fi
HOSTNAME=`hostname`
#将邮件重新定向到一个临时文件里
TMPMAIL="$MLDATADIR/$DOMAIN/$MLNAME/tmp/$HOSTNAME.$MLNAME.$DOMAIN.$SUBTIME.$NUM."`head -c32 /dev/urandom | sha1`
sed '/^Return-Path:/Id' > $TMPMAIL
#将邮件分割成邮件头(header)和邮件体(body)两个部分
sed '/^$/q' $TMPMAIL > $TMPMAIL.header
# 限制邮件列表大小
MAIL_SIZE=$(ls -l $TMPMAIL | awk '{print $5}')
if [ "$MAIL_SIZE" -gt "$LIMIT_SIZE" ]; then
	BAKTO=`grep '^From: ' $TMPMAIL.header | sed 's/From:/To:/I'`
	rm -f $MLDATADIR/$DOMAIN/$MLNAME/lock || (logger -p mail.info -t MailList "$MID: Delete lock file fail!!!" ; exit 1) || exit
	logger -p mail.info -t MailList "$0 said: This mail size $MAIL_SIZE,is large."
	TU=B
	if [ "$LIMIT_SIZE" -gt "1023" ]; then
		LIMIT_SIZE="$(expr $LIMIT_SIZE / 1024)"
		TU=K
	fi
	if [ "$LIMIT_SIZE" -gt "1023" ]; then
		LIMIT_SIZE="$(expr $LIMIT_SIZE / 1024)"
		TU=M
	fi
	LIMIT_SIZE=${LIMIT_SIZE}$TU
	cat << BAKMAIL | sendmail -i -t -f $MLNAME@$DOMAIN
From: $MLNAME@$DOMAIN
$BAKTO
Subject: 对不起，您刚发的邮件太大！
Content-Type: multipart/mixed;
 boundary="020806040501030605070803"

--020806040501030605070803
Content-Type: text/plain; charset=gb2312
Content-Transfer-Encoding: 8bit

尊敬的发件人，您好：
    您发到${MLNAME}@${DOMAIN}邮件列表的邮件大小超过了${LIMIT_SIZE}，请
修改后重新发送。
    您的原始邮件请看附件！谢谢！

--020806040501030605070803
Content-Type: message/rfc822;
 name="$MLNAME@$DOMAIN.eml"
Content-Transfer-Encoding: 8bit
Content-Disposition: attachment;
 filename="$MLNAME@$DOMAIN.eml"

`cat $TMPMAIL`


--020806040501030605070803--
BAKMAIL
	rm -f $TMPMAIL $TMPMAIL.header
	exit 0
fi
#将邮件分割成邮件头(header)和邮件体(body)两个部分
sed '1,/^$/d' $TMPMAIL > $TMPMAIL.body
MID=`cat $TMPMAIL.header | grep ' id ' | head -1 | awk -F' id ' '{print $2}' | tr -d ';'`
#防止邮件死循环，当发现邮件体中有两个maillist标记
#则认为是循环，自动跳出
#同时解锁该邮件列表
NOLOOP=`grep -c "^Maillist: $MLNAME@$DOMAIN Serial" $TMPMAIL.body`
#NOLOOP=`grep -c "^From: MAILER-DAEMON@" $TMPMAIL.body`
if [ "$NOLOOP" -gt "1" ]; then
	rm -f $MLDATADIR/$DOMAIN/$MLNAME/lock || (logger -p mail.info -t MailList "$MID: Delete lock file fail!!!" ; exit 1) || exit 1
	rm -f $TMPMAIL $TMPMAIL.header $TMPMAIL.body
	logger -p mail.info -t MailList "$MID: $0 said: drop loop mail at $MLNAME@$DOMAIN[$NUM]."
	exit 0
fi
#读取邮件是否接收非本域发来的邮件
PUB=`cat $MLDATADIR/$DOMAIN/$MLNAME/public`
#检查邮件是否是本地域发来的
#判断如果接收非本地域邮件的标志为0则直接跳出程序
#同时解锁该邮件列表
FROM=`grep '^From: ' $TMPMAIL.header`
ALLOWDOMAIN=`cat $MLDATADIR/$DOMAIN/$MLNAME/allowdomain $MLDATADIR/$DOMAIN/ml_conf/allowdomain | tr -s "\n" "|" | sed 's/\|$//'`
PUBOK=`echo $FROM | egrep -o $ALLOWDOMAIN`
if [ "$PUBOK" = "" ] && [ "$PUB" = "0" ]; then
	logger -p mail.info -t MailList "$MID: Target domain not match $PUBOK"
	rm -f $MLDATADIR/$DOMAIN/$MLNAME/lock || (logger -p mail.info -t MailList "$MID: Delete lock file fail!!!" ; exit 1) || exit 1
	mv $TMPMAIL $MLDATADIR/$DOMAIN/$MLNAME/dropmail/
	rm -f $TMPMAIL.header $TMPMAIL.body
	logger -p mail.info -t MailList "$MID: $0 said: drop Internet mail at $MLNAME@$DOMAIN[$NUM]."
	exit 0
fi
echo `expr $NUM + 1` > $MLDATADIR/$DOMAIN/$MLNAME/number
#解锁邮件列表
rm -f $MLDATADIR/$DOMAIN/$MLNAME/lock || (logger -p mail.info -t MailList "$MID: Delete lock file fail!!!" ; exit 1) || exit 1
#读取是否给邮件主题加上邮件序号
CHSUB=`cat $MLDATADIR/$DOMAIN/$MLNAME/chsub`
#如果标记打开切邮件头里没标记这是邮件列表发出则替换邮件主题
NOCHSUB=`grep -c "^Maillist: " $TMPMAIL.header`
if [ "$CHSUB" = "1" ] && [ "$NOCHSUB" -lt "1" ]; then
	sed -i '' "s/: \[${MLNAME}:\(.*\)\] /: /" $TMPMAIL.header
	sed -i '' "s/^Subject: /&\[$MLNAME:$SUBTIME-$NUM\] /" $TMPMAIL.header
fi
#给邮件打上邮件列表标记
sed -i '' "/^Message-ID:/Ii\\
Maillist: $MLNAME@$DOMAIN Serial\[$SUBTIME-$NUM\] $TIME\\
" $TMPMAIL.header
#重新组合邮件并删除拆开了的邮件
cat $TMPMAIL.header $TMPMAIL.body > $TMPMAIL
rm -f $TMPMAIL.header $TMPMAIL.body
#发送邮件
cat $TMPMAIL | sendmail -f $MLNAME@$DOMAIN $TO
#读取邮件是否需要备份的状态
ARCHIVE=`cat $MLDATADIR/$DOMAIN/$MLNAME/archive`
#如果备份标志打开则备份邮件            
if [ "$ARCHIVE" = "1" ]; then
	mv $TMPMAIL $MLDATADIR/$DOMAIN/$MLNAME/archived/
else
	#删除临时邮件
	rm -f $TMPMAIL
fi
logger -p mail.info -t MailList "$MID: $0 said: ok at $MLNAME@$DOMAIN[$NUM]."

