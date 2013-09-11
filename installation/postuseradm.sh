#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

ACT=$1
MAIL=$2
if [ "$MAIL" != "" ]; then
	if [ `echo $MAIL | grep '@'` ]; then
		USER=`echo $MAIL | awk -F'@' '{print $1}'`
		DOMAIN=`echo $MAIL | awk -F'@' '{print $2}'`
		if [ "$USER" = "" ] || [ "$DOMAIN" = "" ]; then
			echo "Sorry,bad mail address for \"$MAIL\"!!!"
			exit 1
		fi
	else
		echo "Sorry,bad mail address for \"$MAIL\"!!!"
		exit 1
	fi
fi
PASSWD=$3
if [ "$PASSWD" = "" ]; then
	PASSWD=iceblood
fi
MYSQL=_MYSQL_
MAILBOX_BASE=_MAILBOX_BASE_

help()
{
	cat << HELP
$0 {add|del|passwd|list|info} address [password]
	$0 add iceblood@_DOMAIN_
	$0 add iceblood@_DOMAIN_ 123456
	$0 list
HELP
}

if [ "$ACT" != "list" ] && [ "$MAIL" = "" ]; then
	help
	exit 1
fi
DBMAIL=`$MYSQL -u postfix -ppostfix postfix -e "SELECT mail FROM users WHERE mail=\"${MAIL}\"" | grep -v '^mail$'`
DBDOMAIN=`$MYSQL -u postfix -ppostfix postfix -e "SELECT domain FROM domains WHERE domain=\"${DOMAIN}\"" | grep -v '^domain$'`
if [ "$DOMAIN" != "$DBDOMAIN" ]; then
	echo "No exists domain \"$DOMAIN\"!!!"
	exit 1
fi

case $ACT in
	add)
		if [ "$MAIL" = "$DBMAIL" ]; then
			echo "Exists \"$MAIL\"."
			exit 1
		fi
		$MYSQL -u postfix -ppostfix postfix -e "INSERT INTO users (mail,username,domain,homedir,maildir,password) VALUES (\"${MAIL}\",\"${USER}\",\"${DOMAIN}\",\"${DOMAIN}/${USER}\",\"${DOMAIN}/${USER}/Maildir/\", encrypt(\"${PASSWD}\"))"
		if [ "$PASSWD" = "iceblood" ]; then
			echo "$MAIL default password is \"${PASSWD}\""
		fi
		exit
		;;
	del)
		USERDIR=$($MYSQL -u postfix -ppostfix postfix -e "SELECT homedir,maildir FROM users WHERE mail = \"${MAIL}\"" | tail -n1 | awk '{print $1"/"$2}')
		$MYSQL -u postfix -ppostfix postfix -e "DELETE FROM users WHERE mail = \"${MAIL}\""
		if [ -d $USERDIR ]; then
			rm -rf $USERDIR
		fi
		exit
		;;
	passwd)
		echo -n "Please ${MAIL} password:"
		read NEWPASSWD
		if [ "$NEWPASSWD" != "" ]; then
			$MYSQL -u postfix -ppostfix postfix -e "UPDATE users SET password=encrypt(\"${NEWPASSWD}\") WHERE mail=\"${MAIL}\""
		else
			echo "Sorry,password is null!!!"
		fi
		exit
		;;
	list)
		$MYSQL -u postfix -ppostfix postfix -e "SELECT mail FROM users" | grep -v '^mail$'
		exit
		;;
	info)
		$MYSQL -u postfix -ppostfix postfix -e "SELECT * FROM users WHERE mail = \"${MAIL}\"\G"
		exit
		;;
	*)
		help
		exit
		;;
esac

