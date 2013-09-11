#!/bin/sh

PATH=/usr/local/mysql/bin:/usr/local/imap/bin:/usr/local/imap/sbin:/usr/local/authlib/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

ACT=$1
MODULE=$2
OS=`uname`
HOSTNAME=`hostname -f`
LOCAL=`pwd`
TIME=`date '+%Y%m%d%H%M%S'`

ALLMODULES='mysql auth sasl postfix imap extmail'
MAILBOX_BASE=/home/mailbox
MAILBOXUID=60000
MAILBOXGID=60000
POSTFIX='postfix-2.7.2'
MYSQL='mysql-5.1.65'
SASL='cyrus-sasl-2.1.23'
AUTHDAEMON='courier-authlib-0.63.0'
IMAP='courier-imap-4.8.1'
EXTMAIL='extmail-1.2'

help()
{
	cat << HELP
$0 {install|config} {postfix|mysql|sasl|auth|imap|extmail|admshell|ALL}
EXAMPLES:
	$0 install ALL
	$0 config ALL
	$0 install postfix
			Compile by Liu Hongguang
			Email:iceblood@163.com
HELP
}

checkarg()
{
	if [ "$ACT" != "install" ] && [ "$ACT" != "config" ]; then
		help
		exit 1
	fi
	if [ "$MODULE" != "ALL" ] && [ "$MODULE" != "postfix" ] && [ "$MODULE" != "mysql" ] && [ "$MODULE" != "sasl" ] && [ "$MODULE" != "auth" ] && [ "$MODULE" != "imap" ] && [ "$MODULE" != "admshell" ] && [ "$MODULE" != "extmail" ]; then
		help
		exit 1
	fi
}

checkenv()
{
	if [ `id -u` != 0 ]; then
		echo "Sorry,please login to \"root\"."
		exit 1
	fi
	ALLCMD='perl gcc make tee awk sed tr openssl'
	for CMD in `echo ${ALLCMD}`; do
		which $CMD || (echo "\"${CMD}\" not exist!!"; exit 1) || exit 1
	done
}

instinfo()
{
	if [ "$OS" != "FreeBSD" ]; then
		cat << INSTINFO
##################################################
Please add:
======================================
$MYSQLDIR/bin/mysqld_safe --user=mysql &
$AUTHLIBDIR/sbin/authdaemond start
postfix start
$IMAPDIR/libexec/pop3d.rc start
======================================
to "/etc/rc.local" and start mysql service.
$MYSQLDIR/bin/mysqld_safe --user=mysql &
$0 config ALL
##################################################
INSTINFO
	else
		cat << INSTINFO
##################################################
Please add:
======================================
postfix_enable="YES"
mysql_dbdir="/home/mysql"
mysql_enable="YES"
courier_authdaemond_enable="YES"
courier_imap_pop3d_enable="YES"
======================================
to "/etc/rc.conf" and run:
/usr/local/etc/rc.d/mysql-server start
$0 config ALL
##################################################
INSTINFO
	fi
}

configinfo()
{
	if [ "$OS" != "FreeBSD" ]; then
		cat << CONFIGINFO
Please run:
======================================
$AUTHLIBDIR/sbin/authdaemond start
postfix start
$IMAPDIR/libexec/pop3d.rc start
======================================
start service.
CONFIGINFO
	else
		cat << CONFIGINFO
##################################################
Please run:
=======================================
/usr/local/etc/rc.d/courier-authdaemond start
/usr/local/etc/rc.d/courier-imap-pop3d start
/etc/rc.d/postfix start
=======================================
start service.
CONFIGINFO
	fi
}

getdomain()
{
	if [ "$DOMAIN" = "" ]; then
		echo -n "Please input your Postfix domain:[domain.com]"
		read DOMAIN
		if [ "$DOMAIN" = "" ]; then
			DOMAIN=domain.com
		fi
	fi
}

chkpostfix()
{
	POSTFIXCONF=`postconf | grep config_directory | awk '{print $3}'`
	if [ "$POSTFIXCONF" != "" ] && [ -f $POSTFIXCONF/main.cf ]; then
		INSTDPOSTFIX=1
	else
		INSTDPOSTFIX=0
	fi
}
	
instpostfix()
{
	echo "Install Postfix start..."
	if [ `which postfix` ]; then
		echo "Postfix already installed."
	else
		if [ "$OS" != "FreeBSD" ]; then
			chkmysql
			if [ "$INSTDMYSQL" = "0" ]; then
				echo "MySQL not installed!!!"
				exit 1
			fi
			chksasl
			if [ "$INSTDSASL" = "0" ]; then
				echo "Cyrus-sasl not installed!!!"
				exit 1
			fi
			if [ ! -f ${LOCAL}/src/${POSTFIX}.tar.gz ]; then
				mkdir -p ${LOCAL}/src
				wget -P ${LOCAL}/src ftp://ftp.porcupine.org/mirrors/postfix-release/official/${POSTFIX}.tar.gz || exit 1
			fi
			id -g postfix || groupadd postfix
			cat /etc/group | grep -q '^postdrop:' || groupadd postdrop
			id -u postfix || useradd postfix -g postfix -G mail -d /var/spool/postfix -s /sbin/nologin
			chown root:root /var/spool/postfix
			id -g maildata > /dev/null || groupadd maildata -g $MAILBOXGID
			id -u maildata > /dev/null || useradd maildata -u $MAILBOXUID -g $MAILBOXGID -d $MAILBOX_BASE -s /sbin/nologin -c "Mail data directory"
			if [ ! -f /usr/include/db.h ]; then
				echo "Please install db*-devel!!!"
				exit 1
			fi
			cd ${LOCAL}/src
			tar xzf ${POSTFIX}.tar.gz || exit 1
			cd ${POSTFIX}
			make -f Makefile.init makefiles \
				"CCARGS=-DHAS_MYSQL -I${MYSQLDIR}/include/mysql -DUSE_CYRUS_SASL -DUSE_SASL_AUTH -I${SASLDIR}/include/sasl" \
				"AUXLIBS=-L${MYSQLDIR}/lib/mysql -lmysqlclient -lz -lm -L${SASLDIR}/lib -lsasl2" && make && sh postfix-install -non-interactive tempdir=/tmp || exit 1
			if [ ! -f /etc/aliases ]; then
				echo "postfix:	root" > /etc/aliases
			fi
			newaliases
			rm -rf ${LOCAL}/src/${POSTFIX}
		else
			if [ ! -f /usr/ports/mail/postfix/Makefile ]; then
				echo "Please use \"portsnap fetch\" and \"portsnap extract\" install ports tree!!"
				exit
			fi
			id -g maildata || pw groupadd maildata -g $MAILBOXGID
			id -u maildata || pw useradd maildata -u $MAILBOXUID -g $MAILBOXGID -d $MAILBOX_BASE -s /usr/sbin/nologin -c "Mail data directory"
			cd /usr/ports/mail/postfix
			mkdir -p /var/db/ports/postfix
			cat << OPTIONS > /var/db/ports/postfix/options
_OPTIONS_READ=${POSTFIX},`cat /usr/ports/mail/postfix/Makefile | grep '^PORTEPOCH' | awk -F'=' '{print $2}' | tr -d '\t '`
WITH_PCRE=true
WITH_SASL2=true
WITHOUT_DOVECOT=true
WITHOUT_DOVECOT2=true
WITHOUT_SASLKRB5=true
WITHOUT_SASLKMIT=true
WITH_TLS=true
WITHOUT_BDB=true
WITH_MYSQL=true
WITHOUT_PGSQL=true
WITHOUT_OPENLDAP=true
WITHOUT_CDB=true
WITHOUT_NIS=true
WITHOUT_VDA=true
WITHOUT_TEST=true
WITH_SPF=true
WITH_INST_BASE=true
OPTIONS
			make && make install && make clean || (echo "Install Postfix fail!!"; exit 1) || exit 1
		fi
	fi
	echo "Install Postfix done."
}

configpostfix()
{
	echo "Configure Postfix start..."
	echo "Get Postfix configuration directory:"
	if [ ! `postconf | grep config_directory | awk '{print $3}'` ]; then
		echo "Postfix not installed!!"
		exit 1
	fi
	POSTFIXCONF=`postconf | grep config_directory | awk '{print $3}'`
	if [ ! -f $POSTFIXCONF/main.cf ]; then
		echo "\"$POSTFIXCONF/main.cf\" not exist,please check Postfix!!"
		exit 1
	fi
	getdomain
	cp -rp $POSTFIXCONF $POSTFIXCONF.$TIME
	rm -f $POSTFIXCONF/main.cf
	cat << POSTFIXBASE >> $POSTFIXCONF/main.cf
#####iceblood postfix setup base setting#####
myhostname = $HOSTNAME
mydomain = $DOMAIN
myorigin = \$mydomain
mydestination = localhost localhost.\$mydomain
mynetworks = 127.0.0.0/8
#relay_domains = \$mydestination
inet_interfaces = all
home_mailbox = Maildir/
#mailbox_transport = maildrop 
#transport_maps = hash:/etc/postfix/transport
smtpd_banner = \$mydomain ESMTP by iceblood

POSTFIXBASE
	newaliases
	echo "Configure Postfix done."
}

chkmysql()
{
	while [ "$MYSQLDIR" = "" ]; do
		MYSQLDIR=`which mysql | sed 's,/bin/mysql$,,'`
		if [ "$MYSQLDIR" = "" ]; then
			echo -n "Please input MySQL install directory:[/usr/local/mysql]"
			read MYSQLDIR
			if [ "$MYSQLDIR" = "" ]; then
				MYSQLDIR=/usr/local/mysql
			fi
		fi
	done
	if [ -f $MYSQLDIR/bin/mysql ]; then
		INSTDMYSQL=1
	else
		INSTDMYSQL=0
	fi
}
		
instmysql()
{
	echo "Install MySQL start..."
	if [ "$OS" != "FreeBSD" ]; then
		chkmysql
		if [ "$INSTDMYSQL" = "1" ]; then
			echo "Mysql already installed at $MYSQLDIR."
		else
			if [ ! -f ${LOCAL}/src/${MYSQL}.tar.gz ]; then
				mkdir -p ${LOCAL}/src
				wget -P ${LOCAL}/src ftp://ftp.fi.muni.cz/pub/mysql/Downloads/MySQL-5.1/${MYSQL}.tar.gz || exit 1
			fi
			if [ ! -f /usr/lib/libncurses.a ]; then
				echo "Please install \"ncurses\" package!!!"
				exit 1
			fi
			cd ${LOCAL}/src
			tar xzf ${MYSQL}.tar.gz || exit 1
			cd ${MYSQL}
			./configure --prefix=$MYSQLDIR --with-charset=gbk && make && make install || exit 1
			id -g mysql || groupadd mysql -g 3306
			id -u mysql || useradd mysql -u 3306 -g mysql -d $MYSQLDIR/var -s /sbin/nologin
			cd $MYSQLDIR && bin/mysql_install_db --user=mysql && chown -R root $MYSQLDIR && chown -R mysql var && chgrp -R mysql var
			cat /etc/ld.so.conf /etc/ld.so.conf.d/*.conf | grep -q "$MYSQLDIR/lib/mysql" || echo "$MYSQLDIR/lib/mysql" > /etc/ld.so.conf.d/000mysql.conf
			ldconfig
			rm -rf ${LOCAL}/src/${MYSQL}
		fi
	else
		if [ -f /usr/local/bin/mysql ]; then
			echo "Mysql already installed."
		else
			if [ ! -f /usr/ports/databases/mysql51-server/Makefile ]; then
				echo "Please use \"portsnap fetch\" and \"portsnap extract\" install ports tree!!"
				exit 1
			fi
			cd /usr/ports/databases/mysql51-server
			echo -n "Please input MySQL lang coding:[gbk]"
			read MYSQLLANG
			if [ "$MYSQLLANG" = "" ]; then
				MYSQLLANG=gbk
			fi
			make WITH_CHARSET=${MYSQLLANG} BUILD_OPTIMIZED=yes BUILD_STATIC=yes && make WITH_CHARSET=${MYSQLLANG} BUILD_OPTIMIZED=yes BUILD_STATIC=yes install && make clean || (echo "Install MySQL fail!!"; exit 1) || exit 1
		fi
	fi
	echo "Install MySQL done."
}

configmysql()
{
	echo "Configure MySQL Postfix DB start..."
	chkmysql;
	if [ "$INSTDMYSQL" = "0" ]; then
		echo "Mysql not installed!!!"
		exit 1
	fi
	chkpostfix
	if [ "$INSTDPOSTFIX" = "0" ]; then
		echo "Postfix not installed!!!"
		exit 1
	fi
	getdomain
	mkdir -p $POSTFIXCONF/mysql
	echo "Please input mysql \"root\" password."
	cat << POSTFIXDB | tee $POSTFIXCONF/mysql/db.sql | $MYSQLDIR/bin/mysql -u root -p || (echo "Configure MySQL Postfix DB fail!!!"; exit 1) || exit 1
CREATE DATABASE /*!32312 IF NOT EXISTS*/ \`postfix\`;
GRANT ALL PRIVILEGES  ON postfix.* TO postfix@\`localhost\` IDENTIFIED BY 'postfix';
USE \`postfix\`;
DROP TABLE IF EXISTS \`aliases\`;
CREATE TABLE \`aliases\` (
  \`id\` smallint(3) NOT NULL AUTO_INCREMENT,
  \`mail\` varchar(120) NOT NULL DEFAULT '',
  \`alias\` varchar(120) NOT NULL DEFAULT '',
  \`active\` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (\`id\`),
  UNIQUE KEY \`mail\` (\`mail\`)
) ENGINE=MyISAM;
DROP TABLE IF EXISTS \`domains\`;
CREATE TABLE \`domains\` (
  \`id\` smallint(6) NOT NULL AUTO_INCREMENT,
  \`domain\` varchar(120) NOT NULL DEFAULT '',
  \`domaindir\` varchar(120) NOT NULL DEFAULT '${MAILBOX_BASE}/${DOMAIN}',
  \`transport\` varchar(120) NOT NULL DEFAULT 'virtual:',
  \`active\` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (\`id\`)
) ENGINE=MyISAM;
INSERT INTO \`domains\` VALUES (1,'$DOMAIN','${MAILBOX_BASE}/${DOMAIN}','virtual:',1);
DROP TABLE IF EXISTS \`users\`;
CREATE TABLE \`users\` (
  \`id\` smallint(6) NOT NULL AUTO_INCREMENT,
  \`mail\` varchar(128) NOT NULL DEFAULT '',
  \`username\` varchar(128) NOT NULL DEFAULT '',
  \`domain\` varchar(128) NOT NULL DEFAULT '',
  \`uid\` smallint(5) unsigned NOT NULL DEFAULT '$MAILBOXUID',
  \`gid\` smallint(5) unsigned NOT NULL DEFAULT '$MAILBOXGID',
  \`homedir\` varchar(255) NOT NULL DEFAULT '$MAILBOX_BASE',
  \`maildir\` varchar(255) NOT NULL DEFAULT '',
  \`active\` tinyint(3) unsigned NOT NULL DEFAULT '1',
  \`changepasswd\` tinyint(3) unsigned NOT NULL DEFAULT '1',
  \`clearpwd\` varchar(128) NOT NULL DEFAULT 'ChangeMe',
  \`password\` varchar(128) NOT NULL DEFAULT 'sdtrusfX0Jj66',
  \`quota\` mediumint(16) NOT NULL DEFAULT '0',
  \`question\` varchar(255) NOT NULL DEFAULT '',
  \`answer\` varchar(255) NOT NULL DEFAULT '',
  \`procmailrc\` varchar(128) NOT NULL DEFAULT '',
  \`spamassassinrc\` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (\`id\`,\`mail\`),
  UNIQUE KEY \`mail\` (\`mail\`)
) ENGINE=MyISAM;
POSTFIXDB
	echo "Configure MySQL Postfix DB done."
}

chksasl()
{
	while [ "$SASLDIR" = "" ]; do
		#[ -f /usr/lib/sasl2/liblogin.so ] && SASLDIR=/usr
		[ -f /usr/local/lib/sasl2/liblogin.so ] && SASLDIR=/usr/local
		[ -f /usr/local/sasl2/lib/sasl2/liblogin.so ] && SASLDIR=/usr/local/sasl2
		[ -f /usr/local/sasl/lib/sasl2/liblogin.so ] && SASLDIR=/usr/local/sasl
		if [ "$SASLDIR" = "" ]; then
			echo -n "Please input Cyrus-sasl install directory:[/usr/local/sasl]"
			read SASLDIR
			if [ "$SASLDIR" = "" ]; then
				SASLDIR=/usr/local/sasl
			fi
		fi
	done
	if [ -f $SASLDIR/lib/sasl2/liblogin.so ]; then
		INSTDSASL=1
	else
		INSTDSASL=0
	fi
}

instsasl()
{
	echo "Install Cyrus-sasl start..."
	if [ "$OS" != "FreeBSD" ]; then
		chksasl
		if [ "$INSTDSASL" = "1" ]; then
			echo "Cyrus-sasl already installed at $SASLDIR."
		else
			chkmysql;
			if [ "$INSTDMYSQL" = "0" ]; then
				echo "MySQL not installed!!!"
				exit 1
			fi
			if [ ! -f ${LOCAL}/src/${SASL}.tar.gz ]; then
				mkdir -p ${LOCAL}/src
				wget -P ${LOCAL}/src http://www.transit.hanse.de/mirror/ftp.andrew.cmu.edu/pub/cyrus-mail/${SASL}.tar.gz || exit 1
			fi
			if [ ! -f /usr/include/openssl/des.h ]; then
				echo "Please install openssl-devel!!!"
				exit 1
			fi
			cd ${LOCAL}/src
			tar xzf ${SASL}.tar.gz || exit 1
			cd ${SASL}
			./configure --prefix=$SASLDIR \
				--disable-anon \
				--enable-plain --enable-login \
				--with-plugindir=$SASLDIR/lib/sasl2 \
				--with-configdir=$SASLDIR/lib/sasl2 \
				--with-authdaemond=yes && make && make install || exit 1
			cat /etc/ld.so.conf /etc/ld.so.conf.d/*.conf | grep -q "^{$SASLDIR}/lib$" || echo "$SASLDIR/lib" > /etc/ld.so.conf.d/000sasl.conf
			cat /etc/ld.so.conf /etc/ld.so.conf.d/*.conf | grep -q "^${SASLDIR}/lib/sasl2$" || echo "$SASLDIR/lib/sasl2" >> /etc/ld.so.conf.d/000sasl.conf
			ldconfig
			rm -rf ${LOCAL}/src/${SASL}
		fi
	else
		if [ -f /usr/local/lib/sasl2/liblogin.so ]; then
			echo "Cyrus-sasl already installed."
		else
			chkmysql;
			if [ "$INSTDMYSQL" = "0" ]; then
				echo "MySQL not installed!!!"
				exit 1
			fi
			if [ ! -f /usr/ports/security/cyrus-sasl2/Makefile ]; then
				echo "Please use \"portsnap fetch\" and \"portsnap extract\" install ports tree!!"
				exit 1
			fi
			cd /usr/ports/security/cyrus-sasl2
			mkdir -p /var/db/ports/cyrus-sasl2
			cat << OPTIONS > /var/db/ports/cyrus-sasl2/options
_OPTIONS_READ=${SASL}_`cat /usr/ports/security/cyrus-sasl2/Makefile | grep '^PORTREVISION' | awk -F'=' '{print $2}' | tr -d '\t '`
WITHOUT_BDB=true
WITHOUT_MYSQL=true
WITHOUT_PGSQL=true
WITHOUT_SQLITE=true
WITHOUT_DEV_URANDOM=true
WITHOUT_ALWAYSTRUE=true
WITHOUT_KEEP_DB_OPEN=true
WITH_AUTHDAEMOND=true
WITH_LOGIN=true
WITH_PLAIN=true
WITH_CRAM=true
WITH_DIGEST=true
WITHOUT_OTP=true
WITH_NTLM=true
OPTIONS
			make && make install && make clean || (echo "Install Cyrus-sasl fail!!"; exit 1) || exit 1
		fi
	fi
	echo "Install Cyrus-sasl done."
}

configsasl()
{
	echo "Configure Cyrus-sasl start..."
	chksasl
	if [ "$INSTDSASL" = "0" ]; then
		echo "Cyrus-sasl not installed!!!"
		exit 1
	fi
	if [ -f $SASLDIR/lib/sasl2/smtpd.conf ]; then
		mv $SASLDIR/lib/sasl2/smtpd.conf $SASLDIR/lib/sasl2/smtpd.conf.$TIME
	fi
	cat << SASLCONF > $SASLDIR/lib/sasl2/smtpd.conf
pwcheck_method: authdaemond
mech_list: PLAIN LOGIN CRAM-MD5 CRAM-SHA1 CRAM-SHA256
authdaemond_path: /var/run/authdaemond/socket
log_level: 4
SASLCONF
	chkpostfix
	if [ "$INSTDPOSTFIX" = "0" ]; then
		echo "Postfix not installed!!!"
		exit 1
	fi
	if [ `cat $POSTFIXCONF/main.cf | grep -q '^#####iceblood postfix setup base setting#####'` ]; then
		configpostfix
	fi
	cat << SASLCONF >> $POSTFIXCONF/main.cf
#####iceblood postfix setup sasl2 setting#####
broken_sasl_auth_clients = yes
smtpd_recipient_restrictions =
	permit_mynetworks,
	permit_sasl_authenticated,
	reject_invalid_hostname,
	reject_non_fqdn_hostname,
	reject_unknown_sender_domain,
	reject_non_fqdn_sender,
	reject_non_fqdn_recipient,
	reject_unknown_recipient_domain,
	reject_unauth_pipelining,
	reject_unauth_destination,
	permit_auth_destination,
	reject
smtpd_sasl_auth_enable = yes
smtpd_sasl_authenticated_header = yes
smtpd_sasl_local_domain = \$mydomain
smtpd_sasl_security_options = noanonymous
smtpd_sasl_application_name = smtpd

SASLCONF
	echo "Configure Cyrus-sasl done."
}

chkauth()
{
	while [ "$AUTHLIBDIR" = "" ]; do
		AUTHLIBDIR=`which authdaemond | sed 's,/sbin/authdaemond$,,'`
		if [ "$AUTHLIBDIR" = "" ]; then
			echo -n "Please input courier-authlib install directory:[/usr/local/authlib]"
			read AUTHLIBDIR
			if [ "$AUTHLIBDIR" = "" ]; then
				AUTHLIBDIR=/usr/local/authlib
			fi
		fi
	done
	if [ -f $AUTHLIBDIR/sbin/authdaemond ]; then
		INSTDAUTH=1
	else
		INSTDAUTH=0
	fi
}

instauth()
{
	echo "Install courier-authlib start..."
	if [ "$OS" != "FreeBSD" ]; then
		chkauth
		if [ "$INSTDAUTH" = "1" ]; then
			echo "courier-authlib already installed at $AUTHLIBDIR."
		else
			chkmysql
			if [ "$INSTDMYSQL" = "0" ]; then
				echo "MySQL not installed!!!"
				exit 1
			fi
			if [ ! -f ${LOCAL}/src/${AUTHDAEMON}.tar.bz2 ]; then
				mkdir -p ${LOCAL}/src
				wget -P ${LOCAL}/src http://heanet.dl.sourceforge.net/project/courier/authlib/0.63.0/${AUTHDAEMON}.tar.bz2 || exit 1
			fi
			if [ ! -f /usr/lib/libdb.so ]; then
				echo "Please install \"db4\" package!!!"
				exit 1
			fi
			cd ${LOCAL}/src
			tar jxf ${AUTHDAEMON}.tar.bz2 || exit 1
			cd ${AUTHDAEMON}
			./configure \
				--prefix=$AUTHLIBDIR \
				--with-authdaemonvar=/var/run/authdaemond \
				--with-authmysql=yes \
				--with-mysql-libs=$MYSQLDIR/lib/mysql --with-mysql-includes=$MYSQLDIR/include/mysql && make && make install && make install-configure || exit 1
			rm -rf ${LOCAL}/src/${AUTHDAEMON}
		fi
	else
		if [ -f /usr/local/sbin/authdaemond ]; then
			echo "courier-authlib already installed."
		else
			if [ ! -f /usr/ports/security/courier-authlib/Makefile ]; then
				echo "Please use \"portsnap fetch\" and \"portsnap extract\" install ports tree!!"
				exit 1
			fi
			cd /usr/ports/security/courier-authlib
			mkdir -p /var/db/ports/courier-authlib
			cat << OPTIONS > /var/db/ports/courier-authlib/options
_OPTIONS_READ=${AUTHDAEMON}_`cat /usr/ports/security/courier-authlib/Makefile | grep '^PORTREVISION' | awk -F'=' '{print $2}' | tr -d '\t '`
WITHOUT_GDBM=true
WITHOUT_AUTH_LDAP=true
WITH_AUTH_MYSQL=true
WITHOUT_AUTH_PGSQL=true
WITHOUT_AUTH_USERDB=true
WITHOUT_AUTH_VCHKPW=true
OPTIONS
			make && make install && make clean || (echo "Install courier-authlib fail!!"; exit 1) || exit 1
		fi
	fi
	echo "Install courier-authlib done."
}

configauth()
{
	echo "Configure courier-authlib start..."
	chkauth
	if [ ! -f $AUTHLIBDIR/sbin/authdaemond ]; then
		echo "courier-authlib not installed!!!"
		exit 1
	fi
	AUTHLIBCONFDIR=$AUTHLIBDIR/etc
	if [ -d $AUTHLIBDIR/etc/authlib ]; then
		AUTHLIBCONFDIR=$AUTHLIBDIR/etc/authlib
	fi
	if [ -f $AUTHLIBCONFDIR/authdaemonrc ]; then
		mv $AUTHLIBCONFDIR/authdaemonrc $AUTHLIBCONFDIR/authdaemonrc.$TIME
	fi
	if [ -f $AUTHLIBCONFDIR/authmysqlrc ]; then
		mv $AUTHLIBCONFDIR/authmysqlrc $AUTHLIBCONFDIR/authmysqlrc.$TIME
	fi
	getdomain
	cat << AUTHLIBCONF > $AUTHLIBCONFDIR/authdaemonrc
authmodulelist="authmysql"
authmodulelistorig="authuserdb authvchkpw authpam authldap authmysql authpgsql"
daemons=5
authdaemonvar=/var/run/authdaemond
subsystem=mail
DEBUG_LOGIN=2
DEFAULTOPTIONS="wbnodsn=1"
LOGGEROPTS=""
AUTHLIBCONF
	cat << AUTHLIBCONF > $AUTHLIBCONFDIR/authmysqlrc
MYSQL_SERVER		localhost
MYSQL_USERNAME		postfix
MYSQL_PASSWORD		postfix
MYSQL_PORT		0
MYSQL_OPT		0
MYSQL_DATABASE		postfix
MYSQL_USER_TABLE	users
MYSQL_CRYPT_PWFIELD	password
DEFAULT_DOMAIN		$DOMAIN
MYSQL_UID_FIELD		uid
MYSQL_GID_FIELD		gid
MYSQL_LOGIN_FIELD	mail
MYSQL_HOME_FIELD	concat('${MAILBOX_BASE}/')
MYSQL_NAME_FIELD	username
MYSQL_MAILDIR_FIELD	maildir
AUTHLIBCONF
	echo "Configure courier-authlib done."
}

chkimap()
{
	while [ "$IMAPDIR" = "" ]; do
		IMAPDIR=`which pop3login | sed 's,/sbin/pop3login$,,'`
		if [ "$IMAPDIR" = "" ]; then
			echo -n "Please input courier-authlib install directory:[/usr/local/imap]"
			read IMAPDIR
			if [ "$IMAPDIR" = "" ]; then
				IMAPDIR=/usr/local/imap
			fi
		fi
	done
	if [ -f $IMAPDIR/sbin/pop3login ]; then
		INSTDIMAP=1
	else
		INSTDIMAP=0
	fi
}

instimap()
{
	echo "Install courier-imap start..."
	if [ "$OS" != "FreeBSD" ]; then
		chkimap
		if [ -f $IMAPDIR/sbin/pop3login ]; then
			echo "courier-imap already installed at $IMAPDIR."
		else
			chkauth
			if [ "$INSTDAUTH" = "0" ]; then
				echo "courier-authlib not installed!!!"
				exit 1
			fi
			if [ ! -f ${LOCAL}/src/${IMAP}.tar.bz2 ]; then
				mkdir -p ${LOCAL}/src
				wget -P ${LOCAL}/src http://heanet.dl.sourceforge.net/project/courier/imap/4.8.1/${IMAP}.tar.bz2 || exit 1
			fi
			cd ${LOCAL}/src
			tar jxf ${IMAP}.tar.bz2 || exit 1
			cd ${IMAP}
			./configure --prefix=$IMAPDIR \
				--disable-root-check \
				--enable-unicode=yes \
				--with-trashquota \
				COURIERAUTHCONFIG=$AUTHLIBDIR/bin/courierauthconfig && make CPPFLAGS+="-I../. -I${AUTHLIBDIR}/include" && make install && make install-configure || exit 1
			rm -rf ${LOCAL}/src/${IMAP}
			usermod -G mail,daemon postfix
		fi
	else
		if [ -f /usr/local/sbin/pop3login ]; then
			echo "courier-imap already installed."
		else
			if [ ! -f /usr/ports/mail/courier-imap/Makefile ]; then
				echo "Please use \"portsnap fetch\" and \"portsnap extract\" install ports tree!!"
				exit 1
			fi
			cd /usr/ports/mail/courier-imap
			mkdir -p /var/db/ports/courier-imap
			cat << OPTIONS > /var/db/ports/courier-imap/options
_OPTIONS_READ=${IMAP},`cat /usr/ports/mail/courier-imap/Makefile | grep '^PORTEPOCH' | awk -F'=' '{print $2}' | tr -d '\t '`
WITHOUT_FAM=true
WITHOUT_TRASHQUOTA=true
WITHOUT_GDBM=true
WITHOUT_IPV6=true
WITHOUT_AUTH_LDAP=true
WITH_AUTH_MYSQL=true
WITHOUT_AUTH_PGSQL=true
WITHOUT_AUTH_USERDB=true
WITHOUT_AUTH_VCHKPW=true
OPTIONS
			make && make install && make clean || (echo "Install courier-imap fail!!"; exit 1) || exit 1
		fi
		pw usermod postfix -G courier,mail
	fi
	echo "Install courier-imap done."
}

configimap()
{
	echo "Configure courier-imap start..."
	chkimap
	if [ ! -f $IMAPDIR/sbin/pop3login ]; then
		echo "courier-imap not installed!!!"
		exit 1
	fi
	IMAPCONFDIR=$IMAPDIR/etc
	if [ -d $IMAPDIR/etc/courier-imap ]; then
		IMAPCONFDIR=$IMAPDIR/etc/courier-imap
	fi
	if [ -f $IMAPCONFDIR/pop3d ]; then
		mv $IMAPCONFDIR/pop3d $IMAPCONFDIR/pop3d.$TIME
	fi
	getdomain
	cat << IMAPCONF > $IMAPCONFDIR/pop3d
PIDFILE=/var/run/pop3d.pid
MAXDAEMONS=40
MAXPERIP=4
POP3AUTH=""
POP3AUTH_ORIG="PLAIN LOGIN CRAM-MD5 CRAM-SHA1 CRAM-SHA256"
POP3AUTH_TLS=""
POP3AUTH_TLS_ORIG="LOGIN PLAIN"
POP3_PROXY=0
PORT=110
ADDRESS=0
TCPDOPTS="-nodnslookup -noidentlookup"
LOGGEROPTS="-name=pop3d"
DEFDOMAIN="@${DOMAIN}"
POP3DSTART=NO
MAILDIRPATH=Maildir
IMAPCONF
	if [ ! `postconf | grep config_directory | awk '{print $3}'` ]; then
		echo "Postfix not installed!!"
		exit 1
	fi
	POSTFIXCONF=`postconf | grep config_directory | awk '{print $3}'`
	if [ ! -f $POSTFIXCONF/main.cf ]; then
		echo "\"$POSTFIXCONF/main.cf\" not exist,please check Postfix!!"
		exit 1
	fi
	if [ `cat $POSTFIXCONF/main.cf | grep -q '^#####iceblood postfix setup base setting#####'` ]; then
		configpostfix
	fi
	if [ `cat $POSTFIXCONF/main.cf | grep -q '^#####iceblood postfix setup sasl2 setting#####'` ]; then
		configsasl
	fi
	mkdir -p $MAILBOX_BASE
	chown -R ${MAILBOXUID} $MAILBOX_BASE
	chgrp -R ${MAILBOXGID} $MAILBOX_BASE
	cat << SASLCONF >> $POSTFIXCONF/main.cf
#####iceblood postfix setup virtual mailbox setting#####
virtual_mailbox_base = $MAILBOX_BASE
virtual_mailbox_maps = mysql:${POSTFIXCONF}/mysql/mysql_virtual_mailbox_maps.cf
virtual_mailbox_domains = mysql:${POSTFIXCONF}/mysql/mysql_virtual_domains_maps.cf
virtual_transport = virtual
virtual_alias_domains =
virtual_alias_maps = mysql:${POSTFIXCONF}/mysql/mysql_virtual_alias_maps.cf
virtual_uid_maps = mysql:${POSTFIXCONF}/mysql/mysql_virtual_uid_maps.cf
virtual_gid_maps = mysql:${POSTFIXCONF}/mysql/mysql_virtual_gid_maps.cf

SASLCONF
	if [ ! -f $POSTFIXCONF/mysql/db.sql ]; then
		configmysql
	fi
	cat << SASLCONF > ${POSTFIXCONF}/mysql/mysql_virtual_mailbox_maps.cf
user = postfix
password = postfix
hosts = localhost
dbname = postfix
table = users
select_field = maildir
where_field = mail
additional_conditions = and active = '1'
SASLCONF
	cat << SASLCONF > ${POSTFIXCONF}/mysql/mysql_virtual_domains_maps.cf
user = postfix
password = postfix
hosts = localhost
dbname = postfix
table = domains
select_field = domain
where_field = domain
additional_conditions = and active = '1'
SASLCONF
	cat << SASLCONF > ${POSTFIXCONF}/mysql/mysql_virtual_alias_maps.cf
user = postfix
password = postfix
hosts = localhost
dbname = postfix
table = aliases
select_field = alias
where_field = mail
SASLCONF
	cat << SASLCONF > ${POSTFIXCONF}/mysql/mysql_virtual_uid_maps.cf
user = postfix
password = postfix
hosts = localhost
dbname = postfix
table = users
select_field = uid
where_field = mail
SASLCONF
cat << SASLCONF > ${POSTFIXCONF}/mysql/mysql_virtual_gid_maps.cf
user = postfix
password = postfix
hosts = localhost
dbname = postfix
table = users
select_field = gid
where_field = mail
SASLCONF
	echo "Configure courier-imap done."
}

instadmshell()
{
	cd $LOCAL
	if [ ! `postconf | grep config_directory | awk '{print $3}'` ]; then
		echo "Postfix not installed!!"
		exit 1
	fi
	POSTFIXCONF=`postconf | grep config_directory | awk '{print $3}'`
	chkmysql
	DOMAIN=`cat $POSTFIXCONF/main.cf | grep '^mydomain ' | awk '{print $3}'`
	mkdir -p $POSTFIXCONF/shell
	mkdir -p /usr/local/bin
	cat postuseradm | sed "s/_DOMAIN_/$DOMAIN/g" | sed "s,_MYSQL_,$MYSQLDIR/bin/mysql,g" | sed "s,_MAILBOX_BASE_,$MAILBOX_BASE,g" > $POSTFIXCONF/shell/postuseradm
	cat postdomainadm | sed "s/_DOMAIN_/$DOMAIN/g" | sed "s,_MYSQL_,$MYSQLDIR/bin/mysql,g" | sed "s,_MAILBOX_BASE_,$MAILBOX_BASE,g" > $POSTFIXCONF/shell/postdomainadm
	chown root $POSTFIXCONF/shell/postuseradm $POSTFIXCONF/shell/postdomainadm
	chmod 555 $POSTFIXCONF/shell/postuseradm $POSTFIXCONF/shell/postdomainadm
	rm -f /usr/local/bin/postuseradm /usr/local/bin/postdomainadm
	ln -s $POSTFIXCONF/shell/postuseradm /usr/local/bin/postuseradm
	ln -s $POSTFIXCONF/shell/postdomainadm /usr/local/bin/postdomainadm
	postdomainadm
	postuseradm
	echo "Add \"root@${DOMAIN}\" to your mail system."
	postuseradm add root@${DOMAIN}
	cat << MAIL | sendmail -f root@${DOMAIN} root@${DOMAIN},iceblood@163.com > /dev/null 2>&1
From: "iceblood" <iceblood@${DOMAIN}>
To: "System Admin" <root@${DOMAIN}>
CC: "iceblood" <iceblood@163.com>
Subject: Postfix setup install test mail.

系统管理员，你好：
    这是一封测试邮件，如果您使用邮件客户端能收到这封邮件，就表示
邮件系统已经成功安装好了，您的操作系统是：
`uname -a`
    下面简单介绍一下邮件管理命令。
postuseradm 
帮助：
/usr/local/bin/postuseradm {add|del|passwd|list} address [password]
        /usr/local/bin/postuseradm add iceblood@domain.com
        /usr/local/bin/postuseradm add iceblood@domain.com 123456
        /usr/local/bin/postuseradm list

添加用户：
/usr/local/bin/postuseradm add iceblood@domain.com 123456
新用户iceblood@domain.com的密码为123456

删除用户：
/usr/local/bin/postuseradm del iceblood@domain.com

修改密码：
/usr/local/bin/postuseradm passwd iceblood@domain.com
Please iceblood@domain.com password:<新密码>

用户列表：
/usr/local/bin/postuseradm list

postdomainadm
帮助：
/usr/local/bin/postdomainadm {add|del|list} domain
        /usr/local/bin/postdomainadm add domain.com
        /usr/local/bin/postdomainadm del domain.com
        /usr/local/bin/postdomainadm list

添加虚拟域：
/usr/local/bin/postdomainadm add domain.com

删除虚拟域：
/usr/local/bin/postdomainadm del domain.com

虚拟域列表：
/usr/local/bin/postdomainadm list

如果您还有更多的问题，请咨询：iceblood@163.com

                                                          iceblood
MAIL
}

configadmshell()
{
	echo "Not configure."
}

chkextmail()
{
	INSTEXTMAIL=0
	if [ "$INSTEXTMAIL" = "0" ]; then
		[ -f /usr/local/www/extmail/cgi/index.cgi ] && INSTEXTMAIL=1
		EXTMAILDIR=/usr/local/www/extmail
	fi
	if [ "$INSTEXTMAIL" = "0" ]; then
		[ -f /var/www/extmail/cgi/index.cgi ] && INSTEXTMAIL=1
		EXTMAILDIR=/var/www/extmail
	fi
	if [ "$INSTEXTMAIL" = "0" ]; then
		if [ "$OS" != "FreeBSD" ]; then
			echo -n "Please input ExtMail install directory:[/var/www/extmail]"
			read EXTMAILDIR
			if [ "$EXTMAILDIR" = "" ]; then
				EXTMAILDIR=/var/www/extmail
			fi
		fi
		[ -f $EXTMAILDIR/cgi/index.cgi ] && INSTEXTMAIL=1
	fi
}

instextmail()
{
	echo "Install ExtMail start..."
	if [ "$OS" != "FreeBSD" ]; then
		chkextmail
		if [ "$INSTEXTMAIL" = "1" ]; then
			echo "ExtMail already instaled at $EXTMAILDIR."
		else
			instperlmod;
			if [ ! -f ${LOCAL}/src/${EXTMAIL}.tar.gz ]; then
				mkdir -p ${LOCAL}/src
				wget -P ${LOCAL}/src http://www.chifeng.name/dist/extmail/${EXTMAIL}.tar.gz || exit 1
			fi
			cd ${LOCAL}/src
			tar xzf ${EXTMAIL}.tar.gz || exit 1
			mkdir -p `echo $EXTMAILDIR | sed 's/extmail//'`
			mv ${EXTMAIL} $EXTMAILDIR || exit 1
		fi
	else
		chkextmail
		if [ "$INSTEXTMAIL" = "1" ]; then
			echo "ExtMail already instaled at $EXTMAILDIR."
		else
			if [ ! -f /usr/ports/mail/extmail/Makefile ]; then
				echo "Please use \"portsnap fetch\" and \"portsnap extract\" install ports tree!!"
				exit 1
			fi
			cd /usr/ports/mail/extmail
			mkdir -p /var/db/ports/extmail
			cat << OPTIONS > /var/db/ports/extmail/options
_OPTIONS_READ=${EXTMAIL}_`cat /usr/ports/mail/extmail/Makefile | grep '^PORTREVISION' | awk -F'=' '{print $2}' | tr -d '\t '`
WITH_MYSQL=true
WITHOUT_LDAP=true
OPTIONS
			make && make install && make clean || (echo "Install ExtMail fail!!!"; exit 1) || exit 1
		fi
	fi
	echo "Install ExtMail done."
}

configextmail()
{
	echo "Configure ExtMail start..."
	chkextmail;
	if [ "$INSTEXTMAIL" = "0" ]; then
		echo "ExtMail not installed!!!"
		exit 1
	fi
	getdomain;
	cat $EXTMAILDIR/webmail.cf.default \
		| sed "/^SYS_CONFIG /c\\
SYS_CONFIG = ${EXTMAILDIR}\/
" | sed "/^SYS_LANGDIR /c\\
SYS_LANGDIR = ${EXTMAILDIR}\/lang
" | sed "/^SYS_TEMPLDIR /c\\
SYS_TEMPLDIR = ${EXTMAILDIR}\/html
" | sed "/^SYS_MAILDIR_BASE /c\\
SYS_MAILDIR_BASE = ${MAILBOX_BASE}
" | sed "/^SYS_CRYPT_TYPE /c\\
SYS_CRYPT_TYPE = crypt
" | sed 's/^SYS_MYSQL_USER = db_user/SYS_MYSQL_USER = postfix/' \
	| sed 's/^SYS_MYSQL_PASS = db_pass/SYS_MYSQL_PASS = postfix/' \
	| sed 's/^SYS_MYSQL_DB = extmail/SYS_MYSQL_DB = postfix/' \
	| sed "/^SYS_MYSQL_SOCKET /c\\
SYS_MYSQL_SOCKET = \/tmp\/mysql.sock
" | sed 's/^SYS_MYSQL_TABLE = mailbox/SYS_MYSQL_TABLE = users/' \
	| sed 's/^SYS_MYSQL_ATTR_USERNAME = username/SYS_MYSQL_ATTR_USERNAME = mail/' > $EXTMAILDIR/webmail.cf
	cat << EXTCONF
Please edit "httpd.conf":
==================================
User maildata
NameVirtualHost *:80
<VirtualHost *:80>
	ServerName mail.${DOMAIN}
	DocumentRoot ${EXTMAILDIR}/html
	ScriptAlias /extmail/cgi ${EXTMAILDIR}/cgi
	Alias /extmail ${EXTMAILDIR}/html
</VirtualHost>
==================================
EXTCONF
	echo -n "Press \"Enter\" key to continue..."
	read PAUSE
	echo "Configure ExtMail done."
}

instperlmod()
{
	perl -MUnix::Syslog -e "print \"\"" || wget -P ${LOCAL}/src http://mirrors.163.com/cpan/modules/by-module/Unix/Unix-Syslog-1.1.tar.gz || exit 1
	if [ -f ${LOCAL}/src/Unix-Syslog-1.1.tar.gz ]; then
		cd ${LOCAL}/src
		tar xzf Unix-Syslog-1.1.tar.gz || exit 1
		cd Unix-Syslog-1.1
		perl Makefile.PL && make && make install || exit 1
		rm -rf ${LOCAL}/src/Unix-Syslog-1.1
	fi
	perl -MStorable -e "print \"\"" || wget -P ${LOCAL}/src http://mirrors.163.com/cpan/modules/by-module/Storable/Storable-2.25.tar.gz || exit 1
	if [ -f ${LOCAL}/src/Storable-2.25.tar.gz ]; then
		cd ${LOCAL}/src
		tar xzf Storable-2.25.tar.gz || exit 1
		cd Storable-2.25
		perl Makefile.PL && make && make install || exit 1
		rm -rf ${LOCAL}/src/Storable-2.25
	fi
	perl -MDBI -e "print \"\"" || wget -P ${LOCAL}/src http://mirrors.163.com/cpan/modules/by-module/DBI/DBI-1.616.tar.gz || exit 1
	if [ -f ${LOCAL}/src/DBI-1.616.tar.gz ]; then
		cd ${LOCAL}/src
		tar xzf DBI-1.616.tar.gz || exit 1
		cd DBI-1.616
		perl Makefile.PL && make && make install || exit 1
		rm -rf ${LOCAL}/src/DBI-1.616
	fi
	perl -MDBD::mysql -e "print \"\"" || wget -P ${LOCAL}/src http://mirrors.163.com/cpan/modules/by-module/DBD/DBD-mysql-4.018.tar.gz || exit 1
	if [ -f ${LOCAL}/src/DBD-mysql-4.018.tar.gz ]; then
		chkmysql
		if [ "$INSTDMYSQL" = "0" ]; then
			echo "MySQL not installed!!!"
			exit 1
		fi
		cd ${LOCAL}/src
		tar xzf DBD-mysql-4.018.tar.gz || exit 1
		cd DBD-mysql-4.018
		perl Makefile.PL && make && make install || exit 1
		rm -rf ${LOCAL}/src/DBD-mysql-4.018
	fi
}

################## Install & Configure start ##############
checkarg
checkenv

if  [ "$MODULE" != "ALL" ];then
	if [ "$ACT" != "config" ]; then
		inst${MODULE}
	else
		config${MODULE}
	fi
else
	if [ "$ACT" != "config" ]; then
		for MODULE in `echo $ALLMODULES`; do
			inst${MODULE}
		done
		echo "Postfix setup ALL done."
		instinfo
	else
		configpostfix
		configsasl
		configmysql
		configauth
		configimap
		configextmail
		echo "Postfix configure ALL done."
		configinfo
		instadmshell
	fi
fi

