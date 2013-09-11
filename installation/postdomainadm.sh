#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

ACT=$1
DOMAIN=$2

MYSQL=_MYSQL_
MAILBOX_BASE=_MAILBOX_BASE_

help()
{
	cat << HELP
$0 {add|del|list} domain
	$0 add _DOMAIN_
	$0 del _DOMAIN_
	$0 list
HELP
}

if [ "$ACT" != "list" ] && [ "$DOMAIN" = "" ]; then
	help
	exit 1
fi
DBDOMAIN=`$MYSQL -u postfix -ppostfix postfix -e "SELECT domain FROM domains WHERE domain=\"${DOMAIN}\"" | grep -v '^domain$'`

case $ACT in
	add)
		if [ "$DBDOMAIN" != "" ]; then
			echo "Already exists domain \"$DOMAIN\"!!!"
			exit 1
		fi
		$MYSQL -u postfix -ppostfix postfix -e "INSERT INTO \`domains\` (domain,domaindir,transport,active) VALUES (\"$DOMAIN\",\"${MAILBOX_BASE}/${DOMAIN}\",\"virtual:\",1);"
		exit
		;;
	del)
		DOMAINDIR=$($MYSQL -u postfix -ppostfix postfix -e "SELECT domaindir FROM domains WHERE domain = \"${DOMAIN}\"" | tail -n1)
		$MYSQL -u postfix -ppostfix postfix -e "DELETE FROM domains WHERE domain = \"${DOMAIN}\""
		$MYSQL -u postfix -ppostfix postfix -e "DELETE FROM users WHERE domain = \"${DOMAIN}\""
		if [ -d $DOMAINDIR ]; then
			rm -rf $DOMAINDIR
		fi
		exit
		;;
	list)
		$MYSQL -u postfix -ppostfix postfix -e "SELECT domain FROM domains" | grep -v '^domain$'
		exit
		;;
	*)
		help
		exit
		;;
esac

