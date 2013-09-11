#!/bin/sh

MTA=postfix

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Please set virtual_alias_maps = hash:/etc/postfix/hash_db/virtual_mail_alias
virtual_alias_maps_file=/etc/postfix/hash_db/virtual_mail_alias
# Please set alias_maps = hash:/etc/aliases,hash:/etc/postfix/hash_db/virtual_mail_list
virtual_mail_list_file=/etc/postfix/hash_db/virtual_mail_list

LOCALDOMAIN=`postconf | grep '^myhostname ' | awk '{print $3}'`
MLDATADIR=/home/postfix/mldata
MLSHELLDIR=/home/postfix/shell
                                                                             
DOMAIN=
ML=
MLNAME=$2
ARCHIVE=
START=$1
DOMAINDIR=$MLDATADIR
MLPRO=$MLSHELLDIR/mlsend

READ()
{
	ML=`echo $MLNAME | awk -F'@' '{print $1}'`
	DOMAIN=`echo $MLNAME | awk -F'@' '{print $2}'`
	if [ "$ML" = "" ] || [ "$DOMAIN" = "" ]; then
		echo "Maillist error!!"
		exit 1
	fi
	if [ ! -d $DOMAINDIR/$DOMAIN ]; then
		echo "Sorry,not this domain!!"
		exit 1
	fi
}

case $1 in

add)
	READ;
	if [ -d $DOMAINDIR/$DOMAIN/$ML ]; then
		echo "Sorry,this maillist exist!!!"
		exit 1
	fi
	mkdir -p $DOMAINDIR/$DOMAIN/ml_conf
	if [ ! -f $DOMAINDIR/$DOMAIN/ml_conf/allowdomain ]; then
		echo $DOMAIN >> $DOMAINDIR/$DOMAIN/ml_conf/allowdomain
	fi
	mkdir -p $DOMAINDIR/$DOMAIN/$ML/archived
	mkdir -p $DOMAINDIR/$DOMAIN/$ML/dropmail
	mkdir -p $DOMAINDIR/$DOMAIN/$ML/tmp
	echo 0 > $DOMAINDIR/$DOMAIN/$ML/archive
	echo 1 > $DOMAINDIR/$DOMAIN/$ML/chsub
	echo $ML > $DOMAINDIR/$DOMAIN/$ML/mlname
	echo $DOMAIN > $DOMAINDIR/$DOMAIN/$ML/domain
	touch $DOMAINDIR/$DOMAIN/$ML/mluser
	echo 1 > $DOMAINDIR/$DOMAIN/$ML/number
	echo 1 > $DOMAINDIR/$DOMAIN/$ML/public
	echo 1 > $DOMAINDIR/$DOMAIN/$ML/today
	echo 1 > $DOMAINDIR/$DOMAIN/$ML/year
	touch $DOMAINDIR/$DOMAIN/$ML/allowdomain
	chmod 600 $DOMAINDIR/$DOMAIN/$ML/*
	chmod 700 $DOMAINDIR/$DOMAIN/$ML/archived $DOMAINDIR/$DOMAIN/$ML/tmp $DOMAINDIR/$DOMAIN/$ML $DOMAINDIR/$DOMAIN/$ML/dropmail
	chmod 700 $DOMAINDIR/$DOMAIN
	if [ "$MTA" = "qmail" ]; then
		chown vpopmail:vchkpw $DOMAINDIR/$DOMAIN
		echo "|${MLPRO} $ML" > $DOMAINDIR/$DOMAIN/.qmail-$ML
		chown -R vpopmail:vchkpw $DOMAINDIR/$DOMAIN/$ML $DOMAINDIR/$DOMAIN/.qmail-$ML
		chmod 600 $DOMAINDIR/$DOMAIN/.qmail-$ML
	fi
	if [ "$MTA" = "postfix" ]; then
		chown -R nobody:nobody $DOMAINDIR/$DOMAIN/$ML
		echo "$ML@$DOMAIN	$ML.$DOMAIN@$LOCALDOMAIN" >> $virtual_alias_maps_file
		postmap $virtual_alias_maps_file
		echo "$ML.$DOMAIN:	\"|${MLPRO} $ML $DOMAIN\"" >> $virtual_mail_list_file
		postalias $virtual_mail_list_file
	fi
	if [ "$MTA" = "postfix" ]; then
		postfix reload > /dev/null 2>&1 || echo "Postfix reload fail!!!"
	fi
	echo "Add $ML@$DOMAIN maillist done."
	exit 0
	;;
del)
	READ;
	if [ "$MTA" = "qmail" ]; then
		rm -f $DOMAINDIR/$DOMAIN/.qmail-$ML
		rm -rf $DOMAINDIR/$DOMAIN/$ML
	fi
	if [ "$MTA" = "postfix" ]; then
		sed -i '' "/	$ML.$DOMAIN@$LOCALDOMAIN$/d" $virtual_alias_maps_file
		postmap $virtual_alias_maps_file
		sed -i '' "/^$ML.${DOMAIN}:/d" $virtual_mail_list_file
		postalias $virtual_mail_list_file
		rm -rf $DOMAINDIR/$DOMAIN/$ML
	fi
	if [ "$MTA" = "postfix" ]; then
		postfix reload > /dev/null 2>&1 || echo "Postfix reload fail!!!"
	fi
	echo "Delete $ML@$DOMAIN maillist done."
	;;
list)
	if [ "$MLNAME" != "" ] && [ -d $DOMAINDIR/$2 ]; then
		ls $DOMAINDIR/$2 | grep -v '^ml_conf$'| awk '{print $1"@'$2'"}'
	else
		echo "Not exist \"$MLNAME\" domain!!"
	fi
	;;
status)
	READ;
	ARCHIVE=`cat $DOMAINDIR/$DOMAIN/$ML/archive`
	PUB=`cat $DOMAINDIR/$DOMAIN/$ML/public`
	YEAR=`cat $DOMAINDIR/$DOMAIN/$ML/year`
	DT=`cat $DOMAINDIR/$DOMAIN/$ML/today`
	NUM=`cat $DOMAINDIR/$DOMAIN/$ML/number`
	CHSUB=`cat $DOMAINDIR/$DOMAIN/$ML/chsub`
	echo "show $ML@$DOMAIN status"
	echo -n "mail number: "
	echo "$YEAR$DT-$NUM"
	echo -n "Archive mail: "
	if [ "$ARCHIVE" = "1" ]; then
		echo "Yes"
	else
		echo "No"
	fi
	echo -n "Change mail subject: "
	if [ "$CHSUB" = "1" ]; then
		echo "Yes"
	else
		echo "No"
	fi
	echo -n "Allow Internet mail: "
	if [ "$PUB" = "1" ]; then
		echo "Yes"
	else
		echo "No"
	fi
	echo "Allow domain: "
	echo "====== Public allow domain ======"
	cat $DOMAINDIR/$DOMAIN/ml_conf/allowdomain | awk '{print "       "$1}'
	echo "====== $ML@$DOMAIN allow domain ======"
	cat $DOMAINDIR/$DOMAIN/$ML/allowdomain | awk '{print "       "$1}'
	;;
*)
	cat << HELP
$0 {add|del|list|status}
EXAMPLES
$0 add mlname@domain
$0 list domain
HELP
	;;
esac
exit 0
