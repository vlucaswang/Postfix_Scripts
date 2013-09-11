#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Please set virtual_alias_maps = hash:/etc/postfix/hash_db/virtual_mail_alias
virtual_alias_maps_file=/etc/postfix/hash_db/virtual_mail_alias
# Please set alias_maps = hash:/etc/aliases,hash:/etc/postfix/hash_db/virtual_mail_list
virtual_mail_list_file=/etc/postfix/hash_db/virtual_mail_list

LOCALDOMAIN=`postconf | grep '^myhostname ' | awk '{print $3}'`
MLDATADIR=/home/postfix/mldata
MLSHELLDIR=/home/postfix/shell

DOMAIN=$2
ML=$3
EMAIL=$4

READ()
{
	while [ "$DOMAIN" = "" ] || [ "$EMAIL" = "" ] || [ "$ML" = "" ]; do
		read -p "Please input domain: " DOMAIN
		read -p "Please Mail list name: " ML
		read -p "Please input E-mail address: " EMAIL
	done
	if [ ! -d $MLDATADIR/$DOMAIN/$ML ]; then
		echo "Sorry,$ML not exist!!"
		exit 1
	fi
}
case $1 in

add)
	while [ "$DOMAIN" = "" ] || [ "$EMAIL" = "" ] || [ "$ML" = "" ]; do
		read -p "Please input domain: " DOMAIN
		read -p "Please Mail list name: " ML
		read -p "Please input E-mail address: " EMAIL
	done
	if [ ! -d $MLDATADIR/$DOMAIN/$ML ]; then
		echo "Sorry,$ML not exist!!"
		exit 1
	fi
	echo $EMAIL >> $MLDATADIR/$DOMAIN/$ML/mluser
	echo "Add $ML done."
	;;
del)
	READ;
	sed -i '' "/^$EMAIL$/d" $MLDATADIR/$DOMAIN/$ML/mluser
	echo "Delete $ML done."
	;;
list)
	cat $MLDATADIR/$DOMAIN/$ML/mluser
	;;
*)
	cat << HELP
$0 {add|del|list}
$0 add domain maillist username@domain.com
$0 del domain maillist username@domain.com
$0 list domain maillist
HELP
	;;
esac
exit 0
