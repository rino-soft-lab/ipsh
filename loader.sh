
#!/bin/sh

VERSION="24.6.12"
TABLE_TEMP='/tmp/ipspeed.tmp'

function tableLoader	#1 - тестовый режим
	{
	TABLE=""
	local NUM=1
	while [ "$NUM" -lt "5" ];do
		local URL="https://ipspeed.info/freevpn_sstp.php?language=en&page=$NUM"
		local RAW=`elinks -source $URL`
		local PAGE=`echo -e "$RAW" | sed $'s/[^[:print:]\t]//g' | sed ':a;N;$!ba;s/\n//g' | sed 's/<\/span>/@@/g; s/<[^>]*>\|    //g; s/@@/\\t/g; s/\. /\\n/g' | grep " ms" | awk -F"\t" '{print $1"\t"$2"\t"$3"\t"$4}'`
		TABLE="$TABLE\n$PAGE"
		local NUM=`expr $NUM + 1`
	done
	TABLE=`echo -e "$TABLE" | grep -v '^$\|Russian Federation\|Ukraine'`
	if [ -z "$1" ];then
		if [ "`echo "$TABLE" | grep -c $`" -gt "1" ];then
			echo "$TABLE" > $TABLE_TEMP
		fi
	else
		local COUNTER=24
		while [ "$COUNTER" -gt "0" ];do
			echo -e "\033[30m█\033[39m"
			local COUNTER=`expr $COUNTER - 1`
		done
		clear
		echo "$TABLE"
	fi
	}

echo;while [ -n "$1" ];do
case "$1" in

-t)	tableLoader "test"
	exit
	;;

esac;shift;done
tableLoader
