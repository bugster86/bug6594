#!/bin/bash
#Autore: Giuseppe Guglielmetti
#Manutentore: Martino Viganò
#Versione: 1.1
# release notes
# 1.1 --> Aggiunta la possibilità di lanciare il comando con -P


OP_SYSTEM=`uname -s`
HOME=/home/reicom

OWN_CTH=reicom
GRP_CTH=contact
CFGDIR=/etc/opt/reitek/ct6
BINDIR=/opt/reitek/ct6/bin

procdb="${CFGDIR}/db.proc"

LCFDIR=${CFGDIR}/LOG

PATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/usr/lib/jre/bin:/root/bin:$BINDIR
LD_LIBRARY_PATH=/opt/reitek/ct6/lib:/usr/local/lib

export HOME PATH LD_LIBRARY_PATH

# df output
# $1                          $2        $3        $4   $5 $6
# Filesystem           1K-blocks      Used Available Use% Mounted on
# /dev/sda2              4127108   2027432   1890028  52% /
# /dev/sda1                77750     18653     55083  26% /boot
# /dev/sda6              9313552   4184744   4655696  48% /home
# /dev/sda3              3099292   1124644   1817212  39% /log
# none                    449988         0    449988   0% /dev/shm

######################################################################
# Defaults
######################################################################

email="commandcenter@reitek.com"
fs="/var/log/ct6"
internet="n"
machine=`uname -n`.clienti
SendEmail="y"

######################################################################

home=`grep reicom /etc/passwd | awk -F: '{print $6}'`
lastemail=$BINDIR/.checkdf.last
debug=""
emails=""
message="/tmp/checkdf.txt"
HOMECRITUSE=98;           # Critical threshold for old core.* files
HOMEMAXUSE=90;            # Warning threshold for old core.* files
COREMAXAGE=7;             # Max age (in days) of old core.* files
COREDIR="/home/reicom/";

CleanUp()
{
	rm -f $message
	exit 0
}

SendMail()
{
	now=`date '+%s'`
	if [ -f $lastemail ]
	then
		last=`cat $lastemail`
		delta=$(($now - $last))

		if [ $delta -lt 3600 ]
		then
			return
		fi
	fi

	echo -e "$machine - checkdf report\n" >> $message
	printf "%-16.16s: %8d KB free (%8d KB minfree required)\n" $fs $avail $minfree >> $message
	echo -e "\nDisabling log files and moving LCF files\ninto $LCFDIR/Disabled" >> $message

	echo -e "\nManual system update required" >> $message

	if [ "$SendEmail" = "y" ]
	then
		if [ "$internet" = "y" ]
		then
			cat $message | mail -s "[checkdf] $machine" $email
		else
			for i in $email
			do
				$BINDIR/netdial $BINDIR/checkdf.nd $machine $i ${message}
			done
		fi

		echo "$now" > $lastemail
	else
		cat $message
	fi
}


> $message

set -- `getopt "NM:e:f:m:i:xH:C:A:P:" "$@"`
while [ ! -z "$1" ]
do
	case "$1" in
    -N) SendEmail="n";;
    -e) emails="$emails $2"; shift;;
    -f) fs=$2; shift;;
    -m) minfree=$(($2 + 0)); shift;;
    -i) internet=$2; shift;;
    -x) debug="y";;
    -M) machine=$2; shift;;
    -H) HOMEMAXUSE=$2; shift;;
    -C) HOMECRITUSE=$2; shift;;
    -A) COREMAXAGE=$2; shift;;
    -P) PERCENTAGELOG=$2; shift;;
	esac

	shift
done

[ "$emails" ] && email=$emails
avail="n"

# Clean old core.* files if running out of freespace:
HOMENOWUSE=`df ${COREDIR} | egrep -o '[0-9]+%' | cut -d\% -f1`;
if [[ ${HOMENOWUSE} -ge ${HOMEMAXUSE} ]]; then
  if [[ ${HOMENOWUSE} -ge ${HOMECRITUSE} ]]; then
    find ${COREDIR} -name 'core.*' -exec rm -f {} \;
  else
    find ${COREDIR} -name 'core.*' -mtime +${COREMAXAGE} -exec rm -f {} \;
  fi
fi

# local file system check (NFS)
x=`df -kl $fs | grep -v Filesystem`
if [ "$x" ]
then
	set $x
	avail=$4
fi

# if the FS is not mounted then exit without touching .lcf files
if [ "$avail" = "n" ]
then
	echo	"Filesystem $fs is not mounted" > $message
	SendMail
	CleanUp
fi

[ "$debug" ] && printf "%-16.16s: %8d KB free\n" $fs $avail

# if everything is OK, just quit
monitor1=$(df -kl $fs | egrep -o '[0-9]+%' | cut -d\% -f1 )
if [ ! -z $PERCENTAGELOG ] && [ $monitor1 -lt $PERCENTAGELOG ]
then
        CleanUp
fi


if [ ! -z $minfree ] && [ $avail -gt $minfree ]
then
	CleanUp
fi

echo "$(date +%Y-%m-%d_%H:%M:%S)  Azzero il livello degli LCF"

i=0

cd $LCFDIR
mkdir Disabled > /dev/null 2>&1

lcf=`ls -1 | grep \.lcf$`

# let's make a backup copy of current .lcf files and set to 0 the debug level of all of them
for i in $lcf
do
	:
	# Remove security to activate
	. ./$i
	if [ ! -f Disabled/$i -o ${DEBUG:-0} -ne 0 ]
	then
		cp -p $i Disabled/
	fi
	perl -pi -e 's/^DEBUG=.*/DEBUG=0/' $i
done

# Now all lcf file have DEBUG zeroed, so standard LOG command can be used to set log level to zero
# this is not the best solution, a better solution has to be made in the future, perhaps adding some 
# fields to db.proc file and adding a log/no_log function in service shell
$BINDIR/LOG

SendMail
CleanUp

