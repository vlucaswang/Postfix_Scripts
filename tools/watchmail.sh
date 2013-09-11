#!/bin/sh

PATH=/bin:/sbin/:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
LOGGER='logger -p mail.info -t watchmail'

if [ "$1" = "test" ]; then
	SENDMAIL='echo sendmail'
else
	SENDMAIL=sendmail
fi
FROMDOMAIN='@domain.com|@domain2.com'
WATCHMAIL='jiancha@domain.com'
#此列表发邮件不会被监控
SKIPFROM='xxx1@domainc.om|xxx2@domain.com'
#此列表作为独立收件人不会被监控
SKIPTO='liuhg@domain.com'
#此列表发邮件，作为收件人、抄送人都不会被监控
SKIPGOD='xx1@domain.com|xx2@domain.com'
ALLOWML='mlxxx1@domain.com|mlxxx2@domain.com'

WATCHDIR=/home/postfix/watchdata
MLDATADIR=/home/postfix/mldata
TIME=`date '+%Y%m%d.%H.%M.%S'`
TMPMAIL="$TIME.mail."`od -vAn -N4 -tu4 < /dev/urandom | tr -d ' ,\n'`

cleartmp()
{
	rm -f $WATCHDIR/tmp/$TMPMAIL $WATCHDIR/tmp/$TMPMAIL.header $WATCHDIR/tmp/$TMPMAIL.body
}

if [ ! -d $WATCHDIR ]; then
	mkdir -p $WATCHDIR/new $WATCHDIR/cur $WATCHDIR/tmp
	chown -R nobody:nobody $WATCHDIR
	chmod -R 700 $WATCHDIR
fi
cat > $WATCHDIR/tmp/$TMPMAIL
#将邮件分割成邮件头(header)和邮件体(body)两个部分
sed '/^$/q' $WATCHDIR/tmp/$TMPMAIL > $WATCHDIR/tmp/$TMPMAIL.header
sed '1,/^$/d' $WATCHDIR/tmp/$TMPMAIL > $WATCHDIR/tmp/$TMPMAIL.body

MID=`cat $WATCHDIR/tmp/$TMPMAIL.header | grep ' id ' | head -1 | awk -F' id ' '{print $2}' | tr -d ';'`
LOGGER="logger -p mail.info -t watchmail:$MID"
# skip loop
GO=`cat $WATCHDIR/tmp/$TMPMAIL.header | egrep -i '^Subject: \[WATCH\]'`
if [ "$GO" != "" ]; then
	cleartmp;
	echo "Skip loop mail at watchmail." | $LOGGER
	exit 0
fi

#如果发件人在跳过的列表里，则直接跳过
GO=`cat $WATCHDIR/tmp/$TMPMAIL.header | egrep -i '^From:|^Reply-To:' | egrep -i "${SKIPFROM}|${SKIPGOD}"`
if [ "$GO" != "" ]; then
	cleartmp;
	echo "Skip from mail address at watchmail." | $LOGGER
	exit 0
fi

#如果跳过列表的地址在收件人里就直接跳过，但如果仅仅在抄送里就不跳过
TOGO=`perl -ne 'if (/^Cc:|^To:/i..!/\w+@\w+\./) {print if /\w+@\w+\./}' $WATCHDIR/tmp/$TMPMAIL.header`
GO=`cat $WATCHDIR/tmp/$TMPMAIL.header | egrep -i '^To:' | awk -F, '{print $1}' | egrep -i "$SKIPTO"`
if [ "$TOGO" = "" ] && [ "$GO" != "" ]; then
	cleartmp;
	echo "Skip only to mail address at watchmail." | $LOGGER
	exit 0
fi
#如果发件人和回复地址不是来自本公司的则表示收进来的邮件，不做BCC
GO=`cat $WATCHDIR/tmp/$TMPMAIL.header | egrep -i '^From:|^Reply-To:' | egrep -i "$FROMDOMAIN"`
if [ "$GO" = "" ]; then
	cleartmp;
	echo "Skip internet mail address at watchmail." | $LOGGER
	exit 0
fi
#如果TO或者CC里包含邮件列表或者徐总则不做BCC
SKIPMAIL="${SKIPGOD}|${ALLOWML}"
for DOMAIN in `echo $FROMDOMAIN | tr -s '|' ' ' | tr -d '@'`; do
	if [ -d $MLDATADIR/$DOMAIN ]; then
		CHKMLLIST=`ls -d $MLDATADIR/$DOMAIN/*`
		CHKMLLIST=`basename $CHKMLLIST | awk '{print $1"@'$DOMAIN'"}'`
		if [ "$CHKMLLIST" != "" ]; then
			SKIPMAIL="${SKIPMAIL}|"`echo $CHKMLLIST | tr ' ' '|'`
		fi
	fi
done
GO=`perl -ne 'if (/^Cc:|^To:/i..!/\w+@\w+\./) {print if /\w+@\w+\./}' $WATCHDIR/tmp/$TMPMAIL.header | egrep -i "$SKIPMAIL"`
#GO=`perl -ne '/^Cc:|^To:/i../[\w\-]+@[\w\-]+\..*>$/ and print' $WATCHDIR/tmp/$TMPMAIL.header | egrep -i "$SKIPMAIL"`
if [ "$GO" != "" ]; then
	cleartmp;
	echo "Skip To and Cc have god,maillist,allowml mail at watchmail." | $LOGGER
	exit 0
fi
#如果所有的地址里全都是自己公司的地址，则只备份留作备案不做BCC
GO=`perl -ne 'if (/^Cc:|^To:|^From:|^Reply-To:/i..!/\w+@\w+\./) {print if /\w+@\w+\./}' $WATCHDIR/tmp/$TMPMAIL.header | egrep -v -i "$FROMDOMAIN"`
#GO=`perl -ne '/^Cc:|^To:|^From:|^Reply-To:/i../[\w\-]+@[\w\-]+\..*>$/ and print' $WATCHDIR/tmp/$TMPMAIL.header | egrep -v -i "$FROMDOMAIN"`
if [ "$GO" = "" ]; then
#	sed -i '' 's/^Subject: /Subject: [WATCH] /' $WATCHDIR/tmp/$TMPMAIL.header
	grep -i '^Subject: ' $WATCHDIR/tmp/$TMPMAIL.header > /dev/null && perl -i -pe 's/^Subject: /Subject: [WATCH] /i' $WATCHDIR/tmp/$TMPMAIL.header || perl -i -pe 's/^From: /Subject: [WATCH]\nFrom: /i' $WATCHDIR/tmp/$TMPMAIL.header
	cat $WATCHDIR/tmp/$TMPMAIL.header $WATCHDIR/tmp/$TMPMAIL.body > $WATCHDIR/new/$TMPMAIL
	#cat $WATCHDIR/new/$TMPMAIL | $SENDMAIL -f watch liuhg@ematchina.com
	cleartmp;
	echo "Skip to all EAT mail at watchmail." | $LOGGER
	exit 0
fi
#sed -i '' 's/^Subject: /Subject: [WATCH] /' $WATCHDIR/tmp/$TMPMAIL.header
grep -i '^Subject: ' $WATCHDIR/tmp/$TMPMAIL.header > /dev/null && perl -i -pe 's/^Subject: /Subject: [WATCH] /i' $WATCHDIR/tmp/$TMPMAIL.header || perl -i -pe 's/^From: /Subject: [WATCH]\nFrom: /i' $WATCHDIR/tmp/$TMPMAIL.header
cat $WATCHDIR/tmp/$TMPMAIL.header $WATCHDIR/tmp/$TMPMAIL.body | $SENDMAIL -f watch $WATCHMAIL
cleartmp;
echo "Send this mail to jiancha at watchmail." | $LOGGER
exit 0

