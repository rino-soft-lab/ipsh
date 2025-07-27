#!/bin/sh

VERSION="beta 2"
BUILD="0727.1"
PROFILE_PATH="/opt/etc/ipsh/ipsh.conf"
TABLE_FILE='/tmp/ipspeed.tbl'
TABLE_TEMP='/tmp/ipspeed.tmp'
LIST_FILE='/tmp/ipspeed.lst'
LOG_FILE='/tmp/ipspeed.log'
FLAG_FILE='/tmp/ipspeed.flg'
BUTTON_FILE='/opt/etc/ndm/button.d/ipsh.sh'
CRON_FILE='/opt/var/spool/cron/crontabs/root'
PROXY_FILE='/tmp/ipsh-3proxy.cfg'
INTERFACE_NAME='IPSpeed'
TIMEOUT=15
LOG=0
LAP=1
COLUNS="`stty -a | awk -F"; " '{print $3}' | grep "columns" | awk -F" " '{print $2}'`"

NDMS_VERSION="`ndmc -c show version | grep "release" | awk -F": " '{print $2}'`"
if [ "`echo $NDMS_VERSION | awk -F"." '{print $1}'`" -lt "3" ];then
	NDMS_VERSION="2.x"
elif [ "`echo $NDMS_VERSION | awk -F"." '{print $1}'`" -lt "4" ];then
	NDMS_VERSION="4.0-"
elif [ "`echo $NDMS_VERSION | awk -F"." '{print $1}'`" -lt "5" -a "`echo $NDMS_VERSION | awk -F"." '{print $2}'`" -lt "3" ];then
	NDMS_VERSION="4.0+"
else
	NDMS_VERSION="4.3+"
fi
if [ -f "$PROFILE_PATH" ];then
	PARAM="`cat "$PROFILE_PATH" | grep "^SYSTEM_NAME" | awk -F"=" '{print $2}'`"
	if [ -n "$PARAM" ];then
		SYSTEM_NAME="$PARAM"
	fi
	PARAM="`cat "$PROFILE_PATH" | grep "^TIMEOUT" | awk -F"=" '{print $2}'`"
	if [ -n "$PARAM" ];then
		TIMEOUT="$PARAM"
	fi
	PARAM="`cat "$PROFILE_PATH" | grep "^LOG" | awk -F"=" '{print $2}'`"
	if [ -n "$PARAM" ];then
		LOG="$PARAM"
	fi
	PARAM="`cat "$PROFILE_PATH" | grep "^INTERFACE_NAME" | awk -F"=" '{print $2}'`"
	if [ -n "$PARAM" ];then
		INTERFACE_NAME="$PARAM"
	fi
	PARAM="`cat "$PROFILE_PATH" | grep "^POLICY_NAME" | awk -F"=" '{print $2}'`"
	if [ -n "$PARAM" ];then
		POLICY_NAME="$PARAM"
	fi
	PARAM="`cat "$PROFILE_PATH" | grep "^SWITCH_NEXT" | awk -F"=" '{print $2}'`"
	if [ -n "$PARAM" ];then
		SWITCH_NEXT="$PARAM"
	fi
fi

function headLine	#1 - заголовок	#2 - скрыть полосу под заголовком	#3 - добавить пустые строки для прокрутки
	{
	if [ -n "$3" ];then
		local COUNTER=24
		while [ "$COUNTER" -gt "0" ];do
			echo -e "\033[30m█\033[39m"
			local COUNTER=`expr $COUNTER - 1`
		done
	fi
	if [ "`expr $COLUNS / 2 \* 2`" -lt "$COLUNS" ];then
		local WIDTH="`expr $COLUNS / 2 \* 2`"
		local PREFIX=' '
	else
		local WIDTH=$COLUNS
		local PREFIX=""
	fi
	if [ -n "$1" ];then
		clear
		local TEXT=$1
		local LONG=`echo ${#TEXT}`
		local SIZE=`expr $WIDTH - $LONG`
		local SIZE=`expr $SIZE / 2`
		local FRAME=`awk -v i=$SIZE 'BEGIN { OFS=" "; $i=" "; print }'`
		if [ "`expr $LONG / 2 \* 2`" -lt "$LONG" ];then
			local SUFIX=' '
		else
			local SUFIX=""
		fi
		echo -e "\033[30m\033[47m$PREFIX$FRAME$TEXT$FRAME$SUFIX\033[39m\033[49m"
	else
		echo -e "\033[30m\033[47m`awk -v i=$COLUNS 'BEGIN { OFS=" "; $i=" "; print }'`\033[39m\033[49m"
	fi
	if [ -n "$MODE" -a -n "$1" -a -z "$2" ];then
		local LONG=`echo ${#MODE}`
		local SIZE=`expr $COLUNS - $LONG - 1`
		echo "`awk -v i=$SIZE 'BEGIN { OFS=" "; $i=" "; print }'`$MODE"
	elif [ -z "$MODE" -a -n "$1" -a -z "$2" ];then
		echo ""
	fi
	}

function messageBox	#1 - текст	#2 - цвет
	{
	local TEXT=$1
	local COLOR=$2
	local LONG=`echo ${#TEXT}`
	if [ ! "$LONG" -gt "`expr $COLUNS - 4`" ];then
		local TEXT="│ $TEXT │"
		local SIZE=`expr $COLUNS - $LONG - 4`
		local SIZE=`expr $SIZE / 2`
		local SPACE=`awk -v i=$SIZE 'BEGIN { OFS=" "; $i=" "; print }'`
	else
		local LONG=`expr $COLUNS - 4`
		local SPACE=""
	fi
	if [ "$COLUNS" = "80" ];then
		echo -e "$COLOR$SPACE┌─`awk -v i=$LONG 'BEGIN { OFS="─"; $i="─"; print }'`─┐\033[39m\033[49m"
		echo -e "$COLOR$SPACE$TEXT\033[39m\033[49m"
		echo -e "$COLOR$SPACE└─`awk -v i=$LONG 'BEGIN { OFS="─"; $i="─"; print }'`─┘\033[39m\033[49m"
	else
		echo -e "$COLOR$SPACE□-`awk -v i=$LONG 'BEGIN { OFS="-"; $i="-"; print }'`-□\033[39m\033[49m"
		echo -e "$COLOR$SPACE`showText "$TEXT"`\033[39m\033[49m"
		echo -e "$COLOR$SPACE□-`awk -v i=$LONG 'BEGIN { OFS="-"; $i="-"; print }'`-□\033[39m\033[49m"
	fi
	}

function showText	#1 - текст	#2 - цвет
	{
	local TEXT=`echo "$1" | awk '{gsub(/\\\t/,"____")}1'`
	local TEXT=`echo -e "$TEXT"`
	local STRING=""
	local SPACE=""
	IFS=$' '
	for WORD in $TEXT;do
			local WORD_LONG=`echo ${#WORD}`
			local STRING_LONG=`echo ${#STRING}`
			if [ "`expr $WORD_LONG + $STRING_LONG + 1`" -gt "$COLUNS" ];then
				echo -e "$2$STRING\033[39m\033[49m" | awk '{gsub(/____/,"    ")}1'
				local STRING=$WORD
			else
				local STRING=$STRING$SPACE$WORD
				local SPACE=" "
			fi
	done
	echo -e "$2$STRING\033[39m\033[49m" | awk '{gsub(/____/,"    ")}1'
	}

function copyRight	#1 - название	#2 - год
	{
	if [ "`date +"%C%y"`" -gt "$2" ];then
		local YEAR="-`date +"%C%y"`"
	fi
	local COPYRIGHT="© $2$YEAR rino Software Lab."
	local SIZE=`expr $COLUNS - ${#1} - ${#VERSION} - ${#COPYRIGHT} - 3`
	read -t 1 -n 1 -r -p " $1 $VERSION`awk -v i=$SIZE 'BEGIN { OFS=" "; $i=" "; print }'`$COPYRIGHT" keypress
	}

function showMessage	#1 - текст	#2 - не выводить в журнал	#3 - не выводить в NDMS	#4 - не выводить в терминал
	{
	if [ "$LOG" -lt "2" ];then
		local IPSH=$2
		local LOGGER=$3
	fi
	if [ -z "$4" ];then
		echo "$1"
	fi
	if [ -z "$IPSH" -a "$LOG" -gt "0" ];then
		echo "`date +"%C%y.%m.%d %H:%M:%S"` $1" >> $LOG_FILE
	fi
	if [ -z "$LOGGER" -a "$LOG" -gt "0" ];then
		logger "IPSh: $1"
	fi
	}

function showOption	#1 - текст	#2 - флаг блокировки
	{
	if [ -n "$2" ];then
		local COLOR="\033[90m"
	fi
	echo -e "$COLOR$1\033[39m"
	}

function interfaceID	#1 - форсировать создание подключения	#2 - остановиться после выполнения
	{
	if [ "$NDMS_VERSION" = "2.x" ];then
		local ID="`ndmc -c "show interface" | grep -i -B 3 -A 0 "$INTERFACE_NAME" | grep "id: " | awk -F": " '{print $2}'`"
	else
		local ID="`ndmc -c "show interface" | grep -i -B 4 -A 0 "$INTERFACE_NAME" | grep "id: " | awk -F": " '{print $2}'`"
	fi
	if [ -n "$ID" ];then
		INTERFACE="$ID"
		#showMessage "Идентификатор SSTP-подключения: $INTERFACE" "no log" "no ndms" "no console"
	else
		showMessage "Не удалось определить идентификатор SSTP-подключения"
		echo ""
		if [ -n "$2" ];then
			interfaceID "$1" "break"
		else
			ndmScriptDelete
			pingScheduleDelete
			connectionCreate "$1"
		fi
	fi
	}

function opkgElinks
	{
	if [ -z "`opkg list-installed | grep "^elinks"`" ];then
		showMessage "Установка elinks..."
		echo "`opkg update`" > /dev/null
		echo "`opkg install elinks`" > /dev/null
		echo ""
		if [ -z "`opkg list-installed | grep "^elinks"`" ];then
			messageBox "`showMessage "Не удалось установить: elinks"`"
			echo ""
			showText "\tВы можете попробовать установить пакет elinks вручную, командами:"
			showText "\t\t# opkg update"
			showText "\t\t# opkg install elinks"
			exit
		else
			ELINKS="elinks"
		fi
	else
		ELINKS="elinks"
	fi
	}

function loader	#1 - вторая попытка
	{
	local LOADER_FOLDER="`dirname "$LOADER"`"
	if [ ! -d "$LOADER_FOLDER" ];then
		mkdir -p "$LOADER_FOLDER"
	fi
	if [ -f "$LOADER" ];then
		echo "`$LOADER`" > /dev/null
	fi
	if [ ! -f "$LOADER" -o ! -f "$TABLE_TEMP" ];then
		wget -q -O $LOADER https://raw.githubusercontent.com/rino-soft-lab/ipsh/refs/heads/main/loader.sh
		echo "`chmod +x $LOADER`" > /dev/null
		if [ -z "$1" ];then
			loader "break"
		fi
	fi
	}

function newList
	{
	if [ -z "$ELINKS" ];then
		opkgElinks
	fi
	local TEST=`elinks -source https://ipspeed.info/freevpn_sstp.php | grep -c "vpn"`
	if [ "$TEST" -gt "0" ];then
		local LOADER=`dirname $PROFILE_PATH`/loader.sh
		loader
		if [ -f "$LOADER" -a -f "$TABLE_TEMP" ];then
			if [ "`cat "$TABLE_TEMP" | grep -c $`" -gt "0" ];then
				mv $TABLE_TEMP $TABLE_FILE
				showMessage "Таблица успешно загружена."
			else
				showMessage "В таблице отсутствуют записи..."
			fi
		else
			showMessage "Проблемы с загрузкой таблицы..."
		fi
		echo ""
		if [ -f "$TABLE_FILE" ];then
			local TEST=`cat $TABLE_FILE | grep -c $`
			cat $TABLE_FILE | awk -F"\t" '{print $2}' > $LIST_FILE
			showMessage "Сформирован список из $TEST серверов(а)..."
		else
			messageBox "`showMessage "Файл таблицы отсутствует."`" "\033[91m"
			exit
		fi
	else
		showMessage "Не удалось получить доступ к странице с таблицей..."
		if [ -f "$TABLE_FILE" ];then
			local TEST=`cat $TABLE_FILE | grep -c $`
			cat $TABLE_FILE | awk -F"\t" '{print $2}' > $LIST_FILE
			showMessage "Список из $TEST записей(и) - сформирован из предыдущей версии таблицы..."
		else
			messageBox "`showMessage "файл таблицы отсутствует."`" "\033[91m"
			exit
		fi
	fi
	echo ""
	}

function getList
	{
	if [ -f "$LIST_FILE" ];then
		LIST=`cat "$LIST_FILE"`
		LIST=`echo -e "$LIST"`
	else
		messageBox "`showMessage "Файл списка отсутствует."`" "\033[91m"
		exit
	fi
	}

function saveList
	{
	echo -e "$LIST" > $LIST_FILE
	}

function flagUp	#1 - источник	#2 - не выводить в терминал
	{
	if [ ! -f "$FLAG_FILE" ];then
		echo "$1" > $FLAG_FILE
		showMessage "Блокировка - установлена ($1)." "no log" "no ndms" "$2"
	fi
	}

function flagDown	#1 - не выводить в терминал
	{
	if [ -f "$FLAG_FILE" ];then
		rm -rf $FLAG_FILE
		showMessage "Блокировка - снята." "no log" "no ndms" "$1"
	fi	
	}

function flagCheck	#1 - игнорировать выход
	{
	if [ -f "$FLAG_FILE" ];then
		showMessage "Блокировка активна (`cat "$FLAG_FILE"`)." "no log" "no ndms"
		if [ -z "$1" ];then
			exit
		fi
	fi
	}

function isDisabled	#1 - момент выключения	#2 - игнорировать выход	#3 - принудительно включить SSTP-подключение
	{
	if [ "$NDMS_VERSION" = "2.x" ];then
		local RESULT="`ndmc -c "show interface $INTERFACE" | grep "state: down"`"
	else
		local RESULT="`ndmc -c "show interface $INTERFACE" | grep "conf: disabled"`"
	fi
	if [ -n "$RESULT" ];then
		if [ -n "$3" ];then
			connectionUp "$3"
		else
			if [ -z "$1" ];then
				showMessage "SSTP-подключение отключено." "no log" "no ndms"
				echo ""
			else
				showMessage "SSTP-подключение - выключено."
			fi
			if [ -z "$3" ];then
				flagDown "no console"
			else
				if [ -f "$FLAG_FILE" ];then
					if [ -z "`cat $FLAG_FILE | grep "определение system_name, при включенном SSTP-подключении"`" ];then
						flagDown "no console"
					fi
				fi
			fi
			if [ -z "$2" ];then
				exit
			fi
		fi
	fi
	}

function isConnected
	{
	if [ -n "`ndmc -c "show interface $INTERFACE" | grep "connected: yes"`" ];then
		echo "Yes"
	fi
	}

function opkgCurl
	{
	if [ -z "`opkg list-installed | grep "^curl"`" ];then
		showMessage "Установка curl..."
		echo "`opkg update`" > /dev/null
		echo "`opkg install curl`" > /dev/null
		echo ""
		if [ -z "`opkg list-installed | grep "^curl"`" ];then
			messageBox "`showMessage "Не удалось установить: curl"`"
			echo ""
			showText "\tВы можете попробовать установить пакет curl вручную, командами:"
			showText "\t\t# opkg update"
			showText "\t\t# opkg install curl"
			exit
		else
			CURL="curl"
		fi
	else
		CURL="curl"
	fi
	}

function httpCheck	#1 - игнорировать выход
	{
	if [ -z "$CURL" ];then
		opkgCurl
	fi
	if [ -z "`curl -s --head  --request GET www.google.com | grep "200 OK"`" ];then
		if [ -z "`curl -s --head  --request GET https://id.vk.com/about/id | grep "200 OK"`" ];then
			showMessage "Не удалось убедиться в наличие доступа к сети интернет."
			flagDown "no console"
			if [ -z "$1" ];then
				exit
			fi
		fi
	fi
	}

function adressCheck
	{
	httpCheck
	isDisabled
	local ADRESS=`echo "$LIST" | head -n1`
	if [ -n "$ADRESS" ];then
		flagUp "проверка сервера" "no console"
		showMessage "Попытка подключения к: $ADRESS" "no log" "no ndms"
		LIST="`echo "$LIST" | grep -v "$ADRESS"`"
		echo "`ndmc -c "interface $INTERFACE peer $ADRESS"`" > /dev/null
		sleep "$TIMEOUT"
		if [ -n "`isConnected`" ];then
			showMessage "Подключение к: $ADRESS - установлено."
			echo ""
			echo "`ndmc -c system configuration save`" > /dev/null
			proxyChange
			saveList
			flagDown "no console"
		else
			showMessage "Не удалось установить подключение к: $ADRESS..." "no log" "no ndms"
			adressCheck
		fi
	elif [ "$LAP" -lt "2" ];then
		LAP=2
		newList
		getList
		adressCheck
	else
		showMessage "Отключение SSTP-подключения..."
		echo "`ndmc -c "interface $INTERFACE down"`" > /dev/null
		echo "`ndmc -c system configuration save`" > /dev/null
		echo ""
		messageBox "`showMessage "Не удалось обнаружить рабочий сервер..."`" "\033[91m"
		exit
	fi
	}

function connectionNew
	{
	httpCheck
	interfaceID
	isDisabled "" "" "force"
	showMessage "Новый цикл."
	echo ""
	newList
	getList
	adressCheck
	}

function connectionNext
	{
	httpCheck
	interfaceID
	isDisabled "" "" "force"
	flagUp "поиск нового сервера" "no console"
	showMessage "Поиск нового сервера..."
	echo ""
	if [ -f "$TABLE_FILE" -a -f "$LIST_FILE" ];then
		getList
		adressCheck
	else
		connectionNew
	fi
	}

function connectionCheck	#1 - не использовать тайм-аут
	{
	httpCheck
	flagCheck
	interfaceID
	isDisabled
	flagUp "проверка подключения" "no console"
	if [ -z "$1" ];then
		sleep "$TIMEOUT"
	fi
	if [ -n "`isConnected`" ];then
		showMessage "Подключение - активно."
		echo ""
		proxyCheck
		flagDown "no console"
	else
		showMessage "Подключение отсутствует..."
		echo ""
		connectionNext
	fi
	}

function connectionPing
	{
	httpCheck
	flagCheck
	interfaceID
	isDisabled
	if [ -n "$SYSTEM_NAME" ];then
		local PING_RESULT="`ping 8.8.8.8 -I $SYSTEM_NAME -w 2 -q | grep "packets transmitted" | awk -F" " '{print $4" из "$1}'`"
		if [ -z "$PING_RESULT" ];then
			showMessage "Не удалось выполнить PING через SSTP-подключение..."
			echo ""
			httpCheck
			systemNameDetect
		elif [ "`echo "$PING_RESULT" | awk -F" " '{print $1}'`" = "`echo "$PING_RESULT" | awk -F" " '{print $3}'`" -a "`echo "$PING_RESULT" | awk -F" " '{print $3}'`" -gt "0" ];then
			showMessage "PING до Google (через $INTERFACE): успешно выполнен ($PING_RESULT)." "no log" "no ndms"
			echo ""
		else
			showMessage "PING до Google ($PING_RESULT)." "no log" "no ndms"
			echo ""
			local PING_RESULT="`ping 77.88.8.8 -I $SYSTEM_NAME -w 2 -q | grep "packets transmitted" | awk -F" " '{print $4" из "$1}'`"
			if [ "`echo "$PING_RESULT" | awk -F" " '{print $1}'`" = "`echo "$PING_RESULT" | awk -F" " '{print $3}'`" -a "`echo "$PING_RESULT" | awk -F" " '{print $3}'`" -gt "0" ];then
				showMessage "PING до Яndex (через $INTERFACE): успешно выполнен ($PING_RESULT)." "no log" "no ndms"
				echo ""
			else
				showMessage "PING до Яndex ($PING_RESULT)." "no log" "no ndms"
				echo ""
				messageBox "`showMessage "PING через SSTP-подключение отсутствует."`"
				echo ""
				connectionNext
			fi
		fi
	else
		systemNameDetect
		connectionPing
	fi
	}

function chmodRWX	#1 - путь к файлу
	{
	local DIR_NAME="`dirname "$1"`"
	local FILE_NAME="`basename "$1"`"
	if [ -z "`ls -l "$DIR_NAME" | grep "$FILE_NAME" | grep -G ".rwxr.xr.x"`" ];then
		chmod +rwx $1
	fi
	}

function pingScheduleAdd
	{
	if [ ! -f "$CRON_FILE" ];then
		if [ ! -d "`dirname "$CRON_FILE"`" ];then
			mkdir -p "`dirname "$CRON_FILE"`"
		fi
		echo "" > $CRON_FILE
	fi
	chmodRWX "$CRON_FILE"
	if [ -n "`cat $CRON_FILE | grep "ipsh -P"`" ];then
		local LIST="`cat $CRON_FILE | grep -v "ipsh -P"`"
		echo "$LIST" > $CRON_FILE
	fi
	echo '0-59 */1 * * * ipsh -P' >> $CRON_FILE
	messageBox "`showMessage "Автоматическая проверка PING - включена."`"
	echo "`killall crond`" > /dev/null
	echo "`crond`" > /dev/null
	echo ""
	}

function pingScheduleDelete	#1 - не выводить в терминал
	{
	if [ -n "`cat $CRON_FILE | grep "ipsh -P"`" ];then
		local LIST="`cat $CRON_FILE | grep -v "ipsh -P"`"
		echo "$LIST" > $CRON_FILE
	fi
	if [ -z "$1" ];then
		messageBox "`showMessage "Автоматическая проверка PING - отключена."`"
		echo ""
	fi
	echo "`killall crond`" > /dev/null
	echo "`crond`" > /dev/null
	}

function opkg3proxy
	{
	if [ -z "`opkg list-installed | grep "^3proxy"`" ];then
		showMessage "Установка 3proxy..."
		echo "`opkg update`" > /dev/null
		echo "`opkg install 3proxy`" > /dev/null
		echo ""
		if [ -z "`opkg list-installed | grep "^3proxy"`" ];then
			messageBox "`showMessage "Не удалось установить: 3proxy"`"
			echo ""
			showText "\t\t# Вы можете попробовать установить пакет 3proxy вручную, командами:"
			showText "\t\t# opkg update"
			showText "\topkg install 3proxy"
			exit
		else
			THREEPROXY="3proxy"
		fi
	else
		THREEPROXY="3proxy"
	fi
	}

function proxyChange
	{
	if [ -f "$PROFILE_PATH" ];then
		if [ -n "`opkg list-installed | grep "^3proxy"`" -a -n "`cat $PROFILE_PATH | grep "PROXY_"`" ];then
			interfaceID
			local PROXY_EXTERNAL="`ndmc -c "show interface $INTERFACE" | grep " address" | awk -F": " '{print $2}'`"
			local PROXY_INTERNAL="`cat $PROFILE_PATH | grep "^PROXY_INTERNAL" | awk -F"=" '{print $2}'`"
			local PROXY_PORT="`cat $PROFILE_PATH | grep "^PROXY_PORT=" | awk -F"=" '{print $2}'`"
			if [ -z "$PROXY_INTERNAL" ];then
				local PROXY_INTERNAL="`ip addr show br0 | awk -F" |/" '{gsub(/^ +/,"")}/inet /{print $2}'`"
			fi
			if [ -z "$PROXY_PORT" ];then
				local PROXY_PORT='1080'
			fi
			echo "Обновление конфигурации прокси-сервера..."
			echo ""
			echo -e "daemon\n\nexternal $PROXY_EXTERNAL\ninternal $PROXY_INTERNAL\n\nnserver 1.1.1.1\nnscache 65536\n\nconfig /tmp/ipsh-3proxy.cfg\n\nauth none\nallow *\nsocks -p$PROXY_PORT\n\nflush\n\nallow admin\nadmin -p8080" > $PROXY_FILE
			echo "`/opt/etc/init.d/S23proxy stop`" > /dev/null
			3proxy $PROXY_FILE
			showMessage "Конфигурация прокси-сервера обновлена..."
			if [ "$PROXY_INTERNAL" = "0.0.0.0" ];then
				local TEMP_INTERNAL="адрес Keenetic в любом сегменте, порт"
			else
				local TEMP_INTERNAL="IP: $PROXY_INTERNAL"
			fi
			showMessage "Внешний IP: $PROXY_EXTERNAL, внутренний $TEMP_INTERNAL:$PROXY_PORT" "no log" "no ndms"
			echo ""
		fi
	fi
	}

function proxyCheck
	{
	if [ -f "$PROFILE_PATH" ];then
		if [ -n "`opkg list-installed | grep "^3proxy"`" -a -n "`cat $PROFILE_PATH | grep "PROXY_"`" ];then
			if [ -f "$PROXY_FILE" ];then
				local PROXY_EXTERNAL="`cat "$PROXY_FILE" | grep "external " | awk -F" " '{print $2}'`"
			else
				local PROXY_EXTERNAL=""
			fi
			if [ ! "`ndmc -c "show interface $INTERFACE" | grep " address" | awk -F": " '{print $2}'`" = "$PROXY_EXTERNAL" ];then
				showMessage "Необходимо обновление конфигурации прокси-сервера..." "no log" "no ndms"
				echo ""
				proxyChange
			fi
		fi
	fi
	}

function ndmScriptAdd
	{
	interfaceID
	#if [ "$NDMS_VERSION" = "2.x" ];then
		#echo -e "#!/bin/sh\n\nif [ \"\$id\" = \"$INTERFACE\" ];then\n\tif [ \"\$link\" = \"down\" -a \"\$up\" = \"up\" -a \"\$change\" = \"config\" ];then\t\tif [ \"\`cat /opt/etc/ipsh/ipsh.conf | grep \"SWITCH_NEXT=\" | awk -F\"=\" '{print \$2}'\`\" = \"1\" ];then\n\t\t\tipsh -N &\n\t\telif [ \"\`cat /opt/etc/ipsh/ipsh.conf | grep \"SWITCH_NEXT=\" | awk -F\"=\" '{print \$2}'\`\" = \"2\" ];then\n\t\t\tipsh -R &\n\t\telse\n\t\t\tipsh -C &\n\t\tfi\n\telif [ \"\$link\" = \"up\" -a \"\$up\" = \"down\" -a \"\$change\" = \"config\" ];then\n\t\tipsh -D\n\tfi\nfi\nexit" > /opt/etc/ndm/ifstatechanged.d/ipsh.sh
		#chmodRWX "/opt/etc/ndm/ifstatechanged.d/ipsh.sh"
		#messageBox "`showMessage "Сценарий в ifstatechanged.d - создан."`"
	#el
	if [ "$NDMS_VERSION" = "4.0-" ];then
		echo -e "#!/bin/sh\n\nif [ \"\$id\" = \"$INTERFACE\" ];then\n\tif [ \"\$link\" = \"down\" -a \"\$up\" = \"up\" -a \"\$change\" = \"config\" -a \"\`ndmc -c \"show interface \$id\" | grep \"conf: \" | awk -F\": \" '{print \$2}'\`\" = \"running\" ];then\n\t\tif [ \"\`cat $PROFILE_PATH | grep \"SWITCH_NEXT=\" | awk -F\"=\" '{print \$2}'\`\" = \"1\" ];then\n\t\t\tipsh -N &\n\t\telif [ \"\`cat $PROFILE_PATH | grep \"SWITCH_NEXT=\" | awk -F\"=\" '{print \$2}'\`\" = \"2\" ];then\n\t\t\tipsh -R &\n\t\telse\n\t\t\tipsh -C &\n\t\tfi\n\telif [ \"\$link\" = \"down\" -a \"\$up\" = \"up\" -a \"\$change\" = \"config\" -a \"\`ndmc -c \"show interface \$id\" | grep \"conf: \" | awk -F\": \" '{print \$2}'\`\" = \"disabled\" ];then\n\t\tipsh -D &\n\tfi\nfi\nexit" > /opt/etc/ndm/ifstatechanged.d/ipsh.sh
		messageBox "`showMessage "Сценарий в ifstatechanged.d - создан."`"
	else
		echo -e "#!/bin/sh\n\nif [ \"\$id\" = \"$INTERFACE\" ];then\n\tif [ \"\$layer\" = \"conf\" -a \"\$level\" = \"running\" ];then\n\t\tif [ \"\`cat $PROFILE_PATH | grep \"SWITCH_NEXT=\" | awk -F\"=\" '{print \$2}'\`\" = \"1\" ];then\n\t\t\tipsh -N &\n\t\telif [ \"\`cat $PROFILE_PATH | grep \"SWITCH_NEXT=\" | awk -F\"=\" '{print \$2}'\`\" = \"2\" ];then\n\t\t\tipsh -R &\n\t\telse\n\t\t\tipsh -C &\n\t\tfi\n\telif [ \"\$layer\" = \"ctrl\" -a \"\$level\" = \"disabled\" ];then\n\t\tipsh -D &\n\tfi\nfi\nexit" > /opt/etc/ndm/iflayerchanged.d/ipsh.sh
		messageBox "`showMessage "Сценарий в iflayerchanged.d - создан."`"
	fi
	echo ""
	}

function ndmScriptDelete	#1 - не выводить в терминал
	{
	if [ -f "/opt/etc/ndm/ifstatechanged.d/ipsh.sh" ];then
		rm -rf /opt/etc/ndm/ifstatechanged.d/ipsh.sh
		if [ -z "$1" ];then
			messageBox "`showMessage "Сценарий из ifstatechanged.d - удалён."`"
			echo ""
		fi
	fi
	if [ -f "/opt/etc/ndm/iflayerchanged.d/ipsh.sh" ];then
		rm -rf /opt/etc/ndm/iflayerchanged.d/ipsh.sh
		if [ -z "$1" ];then
			messageBox "`showMessage "Сценарий из iflayerchanged.d - удалён."`"
			echo ""
		fi
	fi
	}

function systemNameDetect
	{
	showMessage "Определение \"system_name\" SSTP-интерфейса:"
	echo ""
	interfaceID
	#if [ "$NDMS_VERSION" = "4.3+" ];then
		#SYSTEM_NAME="`ndmc -c "show interface system-name $ID"`"
	#else
		echo -e "#!/bin/sh\n\nif [ \"\$id\" = \"$INTERFACE\" ];then\n\techo \"\$system_name\" > /tmp/system_name_detect.tmp\nfi\nexit" > /opt/etc/ndm/ifstatechanged.d/system_name_detect.sh
		if [ -n "`isDisabled "" "skip exit"`" ];then
			flagUp "определение system_name, при выключенном SSTP-подключении" "no console"
			echo "`ndmc -c "interface $INTERFACE up"`" > /dev/null
			sleep 5
			echo "`ndmc -c "interface $INTERFACE down"`" > /dev/null
			sleep 15
			flagDown "no console"
		else
			flagUp "определение system_name, при включенном SSTP-подключении" "no console"
			echo "`ndmc -c interface $INTERFACE down`" > /dev/null
			sleep 10
			echo "`ndmc -c interface $INTERFACE up`" > /dev/null
			sleep 5
			flagDown "no console"
		fi
		SYSTEM_NAME="`cat /tmp/system_name_detect.tmp`"
		messageBox "`showMessage "Системное имя интерфейса $INTERFACE: $SYSTEM_NAME"`"
		echo ""
		profileSave "SYSTEM_NAME=$SYSTEM_NAME"
		rm -rf /tmp/system_name_detect.tmp
		rm -rf /opt/etc/ndm/ifstatechanged.d/system_name_detect.sh
	#fi
	}

function connectionCreate	#1 - пропустить диалог
	{
	showMessage "SSTP-подключение \"$INTERFACE_NAME\" отсутствует."
	if [ -z "$1" ];then
		REPLY=""
		echo ""
		echo -e "\t1: Создать SSTP-подключение"
		echo -e "\t0: Отмена (по умолчанию)"
		echo ""
		read -t 30 -r -p "Ваш выбор (его нужно сделать в течении 30 секунд):"
		echo ""
	else
		REPLY="1"
	fi
	if [ "$REPLY" = "1" ];then
		local SHOW_INTERFACE="`ndmc -c show interface`"
		local NUM=0
		while [ -n "`echo "$SHOW_INTERFACE" | grep "SSTP$NUM"`" ];do
			local NUM=`expr $NUM + 1`
		done
		INTERFACE="SSTP$NUM"
		echo ""
		echo "Создание SSTP-подключения..."
		echo "`ndmc -c interface $INTERFACE`" > /dev/null
		echo ""
		echo "Изменение имени SSTP-подключения..."
		echo "`ndmc -c interface $INTERFACE description $INTERFACE_NAME`" > /dev/null
		echo ""
		echo "Изменение адреса сервера..."
		echo "`ndmc -c interface $INTERFACE peer ipspeed.info`" > /dev/null
		echo ""
		echo "Установка имени пользователя..."
		echo "`ndmc -c interface $INTERFACE authentication identity vpn`" > /dev/null
		echo ""
		echo "Установка пароля..."
		echo "`ndmc -c interface $INTERFACE authentication password vpn`" > /dev/null
		echo ""
		echo "Установка флага \"использовать для выхода в интернет\"..."
		local ORDER=`ndmc -c show interface | grep -c "global: yes"`
		echo "`ndmc -c interface $INTERFACE ip global order $ORDER`" > /dev/null
		echo ""
		echo "Подстройка TCP MSS..."
		echo "`ndmc -c interface $INTERFACE ip tcp adjust-mss pmtu`" > /dev/null
		echo ""
		echo "Запуск процесса подключения..."
		echo "`ndmc -c interface $INTERFACE connect`" > /dev/null
		echo ""
		echo "Сохранение настроек..."
		echo "`ndmc -c system configuration save`" > /dev/null
		echo ""
	else
		clear
		messageBox "SSTP-подключение отсутствует." "\033[91m"
		exit
	fi
	}

function policyCreate
	{
	interfaceID
	if [ -z "$POLICY_NAME" ];then
		POLICY_NAME=$INTERFACE_NAME
	fi
	local SHOW_IP_POLICY="`ndmc -c show ip policy`"
	if [ -z "`echo "$SHOW_IP_POLICY" | grep "description = $POLICY_NAME"`" ];then
		showMessage "Создание политики доступа..."
		local NUM=0
		while [ -n "`echo "$SHOW_IP_POLICY" | grep "Policy$NUM"`" ];do
			local NUM=`expr $NUM + 1`
		done
		local POLICY="Policy$NUM"
		echo "`ndmc -c ip policy $POLICY`" > /dev/null
		echo ""
		echo "Изменение имени политики доступа..."
		echo "`ndmc -c ip policy $POLICY description $POLICY_NAME`" > /dev/null
		echo ""
	else
		local POLICY="`echo "$SHOW_IP_POLICY" | grep "description = $POLICY_NAME" | awk -F" = " '{print $2}' | awk -F", " '{print $1}'`"
	fi
	echo "Добавление SSTP-подключения в политику доступа..."
	echo "`ndmc -c ip policy $POLICY permit global $INTERFACE order 0`" > /dev/null
	echo ""
	echo "Сохранение настроек..."
	echo "`ndmc -c system configuration save`" > /dev/null
	echo ""
	messageBox "Политика: $POLICY_NAME - настроена."
	echo ""
	}

function policyDelete
	{
	if [ -z "$POLICY_NAME" ];then
		POLICY_NAME=$INTERFACE_NAME
	fi
	local SHOW_IP_POLICY="`ndmc -c show ip policy`"
	if [ -n "`echo "$SHOW_IP_POLICY" | grep "description = $POLICY_NAME"`" ];then
		local POLICY="`echo "$SHOW_IP_POLICY" | grep "description = $POLICY_NAME" | awk -F" = " '{print $2}' | awk -F", " '{print $1}'`"
		echo "Удаление политики..."
		echo "`ndmc -c no ip policy $POLICY`" > /dev/null
		echo ""
		echo "Сохранение настроек..."
		echo "`ndmc -c system configuration save`" > /dev/null
		echo ""
		messageBox "Политика: $POLICY_NAME - удалена."
		echo ""
	else
		echo ""
		messageBox "Политика $POLICY_NAME - не найдена." "\033[91m"
		echo ""
	fi
	}

function profileSave	#1 - настройка, записываемая в файл конфигурации
	{
	if [ ! -d "`dirname "$PROFILE_PATH"`" ];then
		mkdir -p "`dirname "$PROFILE_PATH"`"
	fi
	if [ -f "$PROFILE_PATH"	];then
		local PROFILE=`cat $PROFILE_PATH`
		local PARAM=`echo "$1" | awk -F"=" '{print $1}'`
		local PROFILE=`echo -e "$PROFILE" | grep -v "$PARAM"`
		echo "$PROFILE" > "$PROFILE_PATH"
	fi
	if [ -n "`echo "$1" | awk -F"=" '{print $2}'`" ];then
		echo "$1" >> $PROFILE_PATH
	fi
	}

function warningMessage
	{
	showText "\tНастоятельно рекомендуется помнить: весь трафик, передаваемый через случайно выбранный, бесплатный сервер - вполне может быть доступен третьим лицам. Необходимо приложить максимум усилий, чтобы важные конфиденциальные данные - не передавались через такое подключение. Ответственность за возможные риски и последствия - вы берёте на себя..." "\033[91m"
	}

function portSet
	{
	read -r -p "Номер порта:"
	echo ""
	if [ -z "$REPLY" ];then
		PROXY_PORT="1080"
		messageBox "Установлено значение по умолчанию: 1080."
		echo ""
	elif [ -n "$REPLY" -a -z "`echo "$REPLY" | sed 's/[0-9]//g'`" -a  "$REPLY" -gt "0" -a "$REPLY" -lt "65536" ];then
		PROXY_PORT=$REPLY
	else
		messageBox "Введено некорректное значение." "\033[91m"
		echo ""
		portSet
	fi
	}

function segListGet
	{
	local IP_ADDR_SHOW=`ip addr show | awk -F" |/" '{gsub(/^ +/,"")}/inet /{print $(NF)"\t"$2}' | grep -v "^lo\|^ezcfg"`
	local SHOW_INTERFACE=`ndmc -c show interface | grep "address: \|description: "`
	IFS=$'\n'
	for LINE in $IP_ADDR_SHOW;do
		local IP="`echo "$LINE" | awk -F"\t" '{print $2}'`"
		local DESCRIPTION="`echo "$SHOW_INTERFACE" | grep -i -B 1 -A 0 "$IP" | head -n1 | awk -F": " '{print $2}'`"
		if [ -n "$DESCRIPTION" ];then
			IP_ADDR_SHOW="`echo "$IP_ADDR_SHOW" | sed -e "s/$IP/$IP ($DESCRIPTION)/g"`"
		fi
	done
	SEG_LIST="`echo "$IP_ADDR_SHOW" | awk -F"\t" '{print "\t• "$2}'`"
	}

function ipSet
	{
	echo "В каких сегментах - должно быть доступно данное прокси-подключение?"
	echo ""
	echo -e "\t1: Только в домашнем"
	echo -e "\t2: Ввести IP-адрес вручную"
	echo -e "\t0: Во всех (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	echo ""
	if [ "$REPLY" = "1" ];then
		PROXY_INTERNAL=`ip addr show br0 | awk -F" |/" '{gsub(/^ +/,"")}/inet /{print $2}'`""
		portSet
	elif [ "$REPLY" = "2" ];then
		echo "Доступны следующие варианты:"
		echo ""
		segListGet
		echo "$SEG_LIST"
		echo ""
		read -r -p "IP-адрес:"
		echo ""
		if [ -n "$REPLY" -a  -n "`echo "$SEG_LIST" | grep "$REPLY"`" ];then
			PROXY_INTERNAL=$REPLY
			portSet
		else
			messageBox "Введено некорректное значение." "\033[91m"
			echo ""
			ipSet
		fi
	else
		PROXY_INTERNAL="0.0.0.0"
		portSet
	fi
	}

function proxySetup
	{
	headLine "Настройка прокси-сервера"
	showText "\tВы можете настроить прокси-сервер, чтобы получить возможность направлять через SSTP-подключение отдельные приложения или устройства (поддерживающие работу с прокси)..."
	echo ""
	warningMessage
	echo ""
	if [ -f "$PROFILE_PATH" ];then
		if [ -n "`cat "$PROFILE_PATH" | grep "PROXY_"`" ];then
			local TEMP_INTERNAL="`cat "$PROFILE_PATH" | grep "PROXY_INTERNAL" | awk -F"=" '{print $2}'`"
			if [ "$TEMP_INTERNAL" = "0.0.0.0" ];then
				local TEMP_INTERNAL="Адрес Keenetic в любом сегменте"
			else
				local TEMP_INTERNAL="Прокси-сервер: $TEMP_INTERNAL"
			fi
			messageBox "$TEMP_INTERNAL, порт: `cat "$PROFILE_PATH" | grep "PROXY_PORT" | awk -F"=" '{print $2}'`"
			local STATE=""
		else
			messageBox "Прокси-сервер - не используется."
			local STATE="block"
		fi
	fi
	echo ""
	echo -e "\t1: Настроить прокси-сервер"
	showOption "\t2: Остановить прокси сервер" "$STATE"
	echo -e "\t0: Отмена (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	echo ""
	if [ "$REPLY" = "1" ];then
		if [ -z "$THREEPROXY" ];then
			opkg3proxy
		fi
		ipSet
		profileSave "PROXY_INTERNAL=$PROXY_INTERNAL"
		profileSave "PROXY_PORT=$PROXY_PORT"
		proxyChange
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
	elif [ "$REPLY" = "2" ];then
			
		if [ -z "$STATE" ];then
			profileSave "PROXY_"
			echo "Остановка прокси-сервера..."
			echo "`/opt/etc/init.d/S23proxy stop`" > /dev/null
			echo ""
			messageBox "`showMessage "Прокси-сервер - остановлен."`"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		else
			messageBox "Прокси-сервер уже отключен." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			proxySetup
		fi
	fi
	}

function policySetup
	{
	headLine "Настройка политики доступа"
	showText "\tНаправлять трафик отдельных устройств и целых сегментов сети - можно через политики доступа. IPSh может создать и настроить политику таким образом, что трафик всех добавленных в неё устройств/сегментов - будет направляться через SSTP-подключение..."
	echo ""
	warningMessage
	echo ""
	if [ -z "$POLICY_NAME" ];then
		POLICY_NAME=$INTERFACE_NAME
	fi
	local SHOW_IP_POLICY="`ndmc -c show ip policy`"
	if [ -n "`echo "$SHOW_IP_POLICY" | grep "description = $POLICY_NAME"`" ];then
		messageBox "Используется политика доступа: $POLICY_NAME"
		local STATE=""
	else
		messageBox "Политика доступа - не настроена."
		local STATE="block"
	fi
	echo ""
	echo -e "\t1: Создать/настроить политику"
	showOption "\t2: Удалить политику" "$STATE"
	echo -e "\t0: Отмена (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	echo ""
	if [ "$REPLY" = "1" ];then
		policyCreate
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
	elif [ "$REPLY" = "2" ];then
		if [ -z "$STATE" ];then
			policyDelete
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		else
			messageBox "Политика отсутствует." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			policySetup
		fi
	fi
	}

function logShow
	{
	headLine "Журнал" "hide" "space"
	if [ -f "$LOG_FILE" ];then
	local LOG_SHOW="`cat $LOG_FILE | awk NF`"
		if [ -n "$LOG_SHOW" ];then
			echo "$LOG_SHOW"
		else
			messageBox "Журнал пуст."
		fi
		headLine
	else
		messageBox "Файл журнала отсутствует." "\033[91m"
	fi
	echo ""
	if [ -f "$LOG_FILE" -a -n "$LOG_SHOW" ];then
		echo -e "\t1: Экспорт"
		echo -e "\t2: Очистить журнал"
		echo -e "\t0: В главное меню (по умолчанию)"
		echo ""
		read -r -p "Ваш выбор:"
		echo ""
		if [ "$REPLY" = "1" ];then
			cp $LOG_FILE "`dirname "$PROFILE_PATH"`/log.txt"
			messageBox "Журнал скопирован в: /etc/ipsh/log.txt"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		elif [ "$REPLY" = "2" ];then
			echo "" > $LOG_FILE
			messageBox "Журнал - очищен."
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		fi
	else
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
	fi
	}

function newCycleShow
	{
	headLine "Новый цикл"
	showText "\tНачав новый цикл, IPSh - постарается получить свежую версию таблицы, cajhvbhjdfnm из неё список серверов и начнёт перебирать их, в поисках того - к которому удастся подключиться..."
	echo ""
	connectionNew
	headLine
	}

function nextConnectionShow
	{
	headLine "Поиск сервера"
	showText "\tIPSh будет перебирать (оставшихся в списке) серверы, в поисках того - к которому удастся подключиться..."
	echo ""
	connectionNext
	headLine
	}

function connectionUp	#1 - пропустить диалог
	{
	messageBox "SSTP-подключение - отключено."
	echo ""
	if [ -z "$1" ];then
		REPLY="0"
		echo ""Хотите включить его?
		echo ""
		echo -e "\t1: Да"
		echo -e "\t0: Отмена (по умолчанию)"
		echo ""
		read -t 30 -r -p "Ваш выбор (его нужно сделать в течении 30 секунд):"
		echo ""
	else
		REPLY="1"
	fi
	if [ "$REPLY" = "1" ];then
		echo "Включение SSTP-подключения..."
		echo "`ndmc -c interface $INTERFACE up`" > /dev/null
		echo "`ndmc -c system configuration save`" > /dev/null
		echo ""
		sleep `expr $TIMEOUT + 10`
	else
		clear
		messageBox "SSTP-подключение не было включено." "\033[91m"
		exit
	fi
	}

function checkConnectionShow
	{
	interfaceID
	headLine "Проверка подключения"
	showText "\tБудет проверено состояние подключения и выполнен PING через него..."
	echo ""
	if [ -z "`isDisabled "" "skip exit"`" ];then
		if [ -z "`flagCheck "skip exit"`" ];then
			if [ -z "`httpCheck "skip exit"`" ];then
				connectionCheck "skip exit"
				connectionPing
				headLine
				echo ""
				read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			else
				messageBox "Не удалось убедиться в наличие доступа к сети интернет."
				echo ""
				read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			fi
		else
			messageBox "Блокировка - активна."
			echo ""
			echo "Хотите принудительно снять блокировку?"
			echo ""
			echo -e "\t1: Да"
			echo -e "\t0: Отмена (по умолчанию)"
			echo ""
			read -r -p "Ваш выбор:"
			echo ""
			if [ "$REPLY" = "1" ];then
				flagDown
				checkConnectionShow
			fi
		fi
	else
		connectionUp
		checkConnectionShow
	fi
	}

function logSettings
	{
	headLine "Режим работы журнала"
	showText "\tЖурнал позволяет отслеживать работу IPSh, его анализ может помочь при возникновении проблем в работе сценария. События из журнала - дублируются в системный журнал интернет-центра (с префиксом IPSh:)..."
	echo ""
	if [ "$LOG" = "1" ];then
		messageBox "В журнал выводится только важное."
		local STATE1="block"
		local STATE2=""
		local STATE3=""
	elif [ "$LOG" = "2" ];then
		messageBox "В журнал выводятся все события."
		local STATE1=""
		local STATE2="block"
		local STATE3=""
	else
		messageBox "Журнал - отключен."
		local STATE1=""
		local STATE2=""
		local STATE3="block"
	fi
	echo ""
	showOption "\t1: Только важное" "$STATE1"
	showOption "\t2: Все события" "$STATE2"
	showOption "\t3: Отключить журнал" "$STATE3"
	echo -e "\t0: Отмена (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	echo ""
	if [ "$REPLY" = "1" ];then
		if [ -z "$STATE1" ];then
			profileSave "LOG=1"
			LOG=1
		else
			messageBox "Этот вариант уже выбран." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			logSettings
		fi
	elif [ "$REPLY" = "2" ];then
		if [ -z "$STATE2" ];then
			profileSave "LOG=2"
			LOG=2
		else
			messageBox "Этот вариант уже выбран." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			logSettings
		fi
	elif [ "$REPLY" = "3" ];then
		if [ -z "$STATE3" ];then
			profileSave "LOG"
			LOG=0
			if [ -f "$LOG_FILE" ];then
				echo "Хотите удалить файл журнала?"
				echo ""
				echo -e "\t2: Да"
				echo -e "\t0: Нет (по умолчанию)"
				echo ""
				read -r -p "Ваш выбор:"
				echo ""
				if [ "$REPLY" = "1" ];then
					rm -rf $LOG_FILE
				fi
			fi
		else
			messageBox "Этот вариант уже выбран." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			logSettings
		fi
	fi
	}

function connectionWatchSettings
	{
	headLine "Отслеживание работы подключения"
	showText "\tВремя жизни серверов с IPSpeed.info - не очень велико. Данная функция, помогает автоматически найти новый, рабочий сервер - при потере подключения к текущему..."
	echo ""
	if [ -f /opt/etc/ndm/ifstatechanged.d/ipsh.sh -o -f /opt/etc/ndm/iflayerchanged.d/ipsh.sh ];then
		messageBox "Функция - включена."
		local STATE1="block"
		local STATE2=""
	else
		messageBox "Функция - отключена."
		local STATE1=""
		local STATE2="block"
	fi
	echo ""
	showOption "\t1: Включить" "$STATE1"
	showOption "\t2: Отключить" "$STATE2"
	echo -e "\t0: Отмена (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	echo ""
	if [ "$REPLY" = "1" ];then
		if [ -z "$STATE1" ];then
			ndmScriptAdd
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		else
			messageBox "Функция уже включена." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			connectionWatchSettings
		fi
	elif [ "$REPLY" = "2" ];then
		if [ -z "$STATE2" ];then
			ndmScriptDelete
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		else
			messageBox "Функция уже отключена." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			connectionWatchSettings
		fi
	fi
	}

function connectionPingSettings
	{
	headLine "Отслеживание наличия интернета"
	showText "\tСерверы с IPSpeed.info - сконфигурированы так, что отключают клиентам доступ в интернет (при отсутствии активности, в течении какого-то времени), не разрывая при этом подключения. Данная функция - позволяет (в некоторых случаях) продлить время работы с сервером, а в случае блокировки (на нём) доступа в интернет - автоматически найти новый..."
	echo ""
	if [ -n "`cat $CRON_FILE | grep "ipsh -P"`" ];then
		messageBox "Функция - включена."
		local STATE1="block"
		local STATE2=""
	else
		messageBox "Функция - отключена."
		local STATE1=""
		local STATE2="block"
	fi
	echo ""
	showOption "\t1: Включить" "$STATE1"
	showOption "\t2: Отключить" "$STATE2"
	echo -e "\t0: Отмена (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	echo ""
	if [ "$REPLY" = "1" ];then
		if [ -z "$STATE1" ];then
			pingScheduleAdd
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		else
			messageBox "Функция уже отключена." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			connectionPingSettings
		fi
	elif [ "$REPLY" = "2" ];then
		if [ -z "$STATE2" ];then
			pingScheduleDelete
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		else
			messageBox "Функция уже включена." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			connectionPingSettings
		fi
	fi
	}

function timeoutSet
	{
	headLine "Тайм-аут"
	showText "\tТайм-аут - временной промежуток, между изменением настроек SSTP-подключения и проверкой результата (удалось ли подключиться)."
	showText "\t• 0 - восстанавливает значение по умолчанию."
	showText "\t• Если оставить поле пустым и нажать ввод - настройка не будет изменена."
	echo ""
	messageBox "Текущее значение: $TIMEOUT сек."
	echo ""
	read -r -p "Тайм-аут (в секундах):"
	echo ""
	if [ -n "$REPLY" -a -z "`echo "$REPLY" | sed 's/[0-9]//g'`" ];then
		if [ "$REPLY" -gt "0" -a "$REPLY" -lt "65536" ];then
		profileSave "TIMEOUT=$REPLY"
		TIMEOUT=$REPLY
		elif [ "$REPLY" = "0" ];then
			profileSave "TIMEOUT"
			TIMEOUT=15
		fi
	fi
	}

function switchSettings
	{
	headLine "Поведение при включении"
	showText "\tХотя IPSh и позволяет настроить управление с помощью аппаратных кнопок (интернет-центра), не всегда имеется возможность до них добраться. В качестве альтернативы - можно использовать последовательность: выключения и включения SSTP-подключения..."
	showText "\t• Восстановить подключение - будет произведена попытка восстановить подключение с текущими настройками, и поиск нового сервера (в случае неудачи)..."
	showText "\t• Найти новый сервер - сразу после включения, начнётся процесс поиска нового рабочего сервера..."
	showText "\t• Начать новый цикл - после включения: будет скачана свежая таблица, сформирован новый список серверов и начнётся поиск рабочего (этот вариант актуален при эпизодическом использовании IPSh)..."
	echo "sn=$SWITCH_NEXT"
	if [ "$SWITCH_NEXT" = "1" ];then
		messageBox "Текущий режим: Найти новый сервер"
		local STATE1=""
		local STATE2="block"
		local STATE3=""
	elif [ "$SWITCH_NEXT" = "2" ];then
		messageBox "Текущий режим: Начать новый цикл"
		local STATE1=""
		local STATE2=""
		local STATE3="block"
	else
		messageBox "Текущий режим: Восстановить подключение"
		local STATE1="block"
		local STATE2=""
		local STATE3=""
	fi
	echo ""
	showOption "\t1: Восстановить подключение" "$STATE1"
	showOption "\t2: Найти новый сервер" "$STATE2"
	showOption "\t3: Начать новый цикл" "$STATE3"
	echo -e "\t0: Отмена (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	echo ""
	if [ "$REPLY" = "1" ];then
		if [ -z "$STATE1" ];then
			profileSave "SWITCH_NEXT"
			SWITCH_NEXT=0
		else
			messageBox "Этот режим уже выбран." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			switchSettings
		fi
	elif [ "$REPLY" = "2" ];then
		if [ -z "$STATE2" ];then
			profileSave "SWITCH_NEXT=1"
			SWITCH_NEXT=1
		else
			messageBox "Этот режим уже выбран." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			switchSettings
		fi
	elif [ "$REPLY" = "3" ];then
		profileSave "SWITCH_NEXT=2"
		SWITCH_NEXT=2
		if [ -z "$STATE" ];then
			profileSave "SWITCH_NEXT=2"
			SWITCH_NEXT=2
		else
			messageBox "Этот режим уже выбран." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			switchSettings
		fi
	fi
	}

function configShow
	{
	headLine "Файл конфигурации" "hide" "space"
	if [ -f "$PROFILE_PATH" ];then
		cat $PROFILE_PATH | awk NF
	else
		messageBox "Файл конфигурации отсутствует." "\033[91m"
	fi
	headLine
	}

function listShow
	{
	headLine "Список серверов" "hide" "space"
	if [ -f "$LIST_FILE" ];then
		cat $LIST_FILE | awk NF
	else
		messageBox "Файл списка отсутствует." "\033[91m"
	fi
	headLine
	}

function tableShow
	{
	headLine "Таблица с IPSpeed.info" "hide" "space"
	if [ -f "$TABLE_FILE" ];then
		local TEXT="`cat $TABLE_FILE | awk -F"\t" '{print $1}' | awk '{print length, $0}' | sort -rn | awk '{$1=""; print $0 }' | head -n 1`"
		local FIRST=`echo ${#TEXT}`
		local TEXT="`cat $TABLE_FILE | awk -F"\t" '{print $2}' | awk '{print length, $0}' | sort -rn | awk '{$1=""; print $0 }' | head -n 1`"
		local SECOND=`echo ${#TEXT}`
		local TEXT="`cat $TABLE_FILE | awk -F"\t" '{print $3}' | awk '{print length, $0}' | sort -rn | awk '{$1=""; print $0 }' | head -n 1`"
		local THIRD=`echo ${#TEXT}`
		local TEXT="`cat $TABLE_FILE | awk -F"\t" '{print $4}' | awk '{print length, $0}' | sort -rn | awk '{$1=""; print $0 }' | head -n 1`"
		local FOURTH=`echo ${#TEXT}`
		local STRING=""
		local CURENT=`expr $FIRST + $SECOND + $THIRD + $FOURTH`
		IFS=$'\n'
		for LINE in $(cat $TABLE_FILE);do
			local TEXT="`echo $LINE | awk -F"\t" '{print $1}'`"
			local SIZE=`expr $FIRST - ${#TEXT}`
			local STRING="$STRING$TEXT`awk -v i=$SIZE 'BEGIN { OFS=" "; $i=" "; print }'`"
			local TEXT="`echo $LINE | awk -F"\t" '{print $2}'`"
			local SIZE=`expr $SECOND - ${#TEXT}`
			if [ "$CURENT" -lt "$COLUNS" ];then
				local STRING="$STRING$TEXT`awk -v i=$SIZE 'BEGIN { OFS=" "; $i=" "; print }'`"
			else
				echo "$TEXT"
				local STRING="⤷$STRING"
			fi
			local TEXT="`echo $LINE | awk -F"\t" '{print $3}'`"
			local SIZE=`expr $THIRD - ${#TEXT}`
			local STRING="$STRING$TEXT`awk -v i=$SIZE 'BEGIN { OFS=" "; $i=" "; print }'`"
			local TEXT="`echo $LINE | awk -F"\t" '{print $4}'`"
			local SIZE=`expr $FOURTH - ${#TEXT}`
			local STRING="$STRING$TEXT`awk -v i=$SIZE 'BEGIN { OFS=" "; $i=" "; print }'`"
			echo $STRING
			local STRING=""
		done
	else
		messageBox "Файл таблицы отсутствует." "\033[91m"
	fi
	headLine
	}

function nameSet
	{
	headLine "Имя подключения"
	showText "\tIPSh ориентируется по имени подключения - которое отображается в веб-конфигураторе (\"Интернет/Другие подключения\"). По умолчанию используется имя \"IPSpeed\", но при необходимости - вы можете изменить его на другое..."
	showText "\t• 0 - восстанавливает значение по умолчанию..."
	showText "\t• Если оставить поле пустым - параметр не будет изменён..."
	echo ""
	messageBox "Текущее имя подключения: $INTERFACE_NAME"
	echo ""
	read -r -p "Имя подключения:"
	echo ""
	if [ -n "$REPLY" ];then
		interfaceID "skip exit"
		if [ "$REPLY" = "0" ];then
			if [ -n "$INTERFACE" ];then
				echo "`ndmc -c interface $INTERFACE description "IPSpeed"`" > /dev/null
				echo "`ndmc -c system configuration save`" > /dev/null
			fi
			profileSave "INTERFACE_NAME"
			INTERFACE_NAME="IPSpeed"
		else
			if [ -n "$INTERFACE" ];then
				echo "`ndmc -c interface $INTERFACE description $REPLY`" > /dev/null
				echo "`ndmc -c system configuration save`" > /dev/null
			fi
			profileSave "INTERFACE_NAME=$REPLY"
			INTERFACE_NAME=$REPLY
		fi
	fi
	}

function policySet
	{
	headLine "Имя политики доступа"
	showText "\tIPSh ориентируется по имени подключения - которое отображается в веб-конфигураторе (\"Интернет/Приоритеты подключений\"). По умолчанию используется имя - идентичное имени подключения \"$INTERFACE_NAME\", но при необходимости - вы можете изменить его на другое..."
	showText "\t• 0 - восстанавливает значение по умолчанию..."
	showText "\t• Если оставить поле пустым - параметр не будет изменён..."
	echo ""
	if [ -n "$POLICY_NAME" ];then
		messageBox "Текущее имя политики доступа: $POLICY_NAME"
	else
		messageBox "Имя политики доступа - не задано, используется: $INTERFACE_NAME"
		POLICY_NAME=$INTERFACE_NAME
	fi
	local POLICY="`ndmc -c show ip policy | grep "description = $POLICY_NAME" | awk -F" = " '{print $2}' | awk -F", " '{print $1}'`"
	echo ""
	read -r -p "Имя политики доступа:"
	echo ""
	if [ -n "$REPLY" ];then
		if [ "$REPLY" = "0" -a "$REPLY" ];then
			if [ -n "$POLICY" ];then
				echo "`ndmc -c ip policy $POLICY description $INTERFACE_NAME`" > /dev/null
				echo "`ndmc -c system configuration save`" > /dev/null
			fi
			profileSave "POLICY_NAME"
			POLICY_NAME=$INTERFACE_NAME
		else
			if [ -n "$POLICY" ];then
				echo "`ndmc -c ip policy $POLICY description $REPLY`" > /dev/null
				echo "`ndmc -c system configuration save`" > /dev/null
			fi
			profileSave "POLICY_NAME=$REPLY"
			POLICY_NAME=$REPLY
		fi
	fi
	}

function settingsMenu
	{
	if [ "$NDMS_VERSION" = "2.x" ];then
		local STATE="block"
	else
		local STATE=""
	fi
	headLine "Настройки"
	echo -e "\t1: Режим работы журнала"
	echo -e "\t2: Тайм-аут"
	showOption "\t3: Поведение при включении" "$STATE"
	showOption "\t4: Отслеживание работы подключения" "$STATE"
	echo -e "\t5: Отслеживание наличия интернета"
	echo -e "\t6: Имя подключения"
	echo -e "\t7: Имя политики доступа"
	echo -e "\t8: Настройка кнопок"
	echo -e "\t0: В главное меню (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	echo ""
	if [ "$REPLY" = "1" ];then
		logSettings
		settingsMenu
		exit
	elif [ "$REPLY" = "2" ];then
		timeoutSet
		settingsMenu
		exit
	elif [ "$REPLY" = "3" ];then
		if [ -z "$STATE" ];then
			switchSettings
		else
			messageBox "Функция недоступна на KeeneticOS 2.x." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		fi
		settingsMenu
		exit
	elif [ "$REPLY" = "4" ];then
		if [ -z "$STATE" ];then
			connectionWatchSettings
		else
			messageBox "Функция недоступна на KeeneticOS 2.x." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		fi
		settingsMenu
		exit
	elif [ "$REPLY" = "5" ];then
		connectionPingSettings
		settingsMenu
		exit
	elif [ "$REPLY" = "6" ];then
		nameSet
		settingsMenu
		exit
	elif [ "$REPLY" = "7" ];then
		policySet
		settingsMenu
		exit
	elif [ "$REPLY" = "8" ];then
		buttonSetup
		settingsMenu
		exit
	else
		mainMenu
		exit
	fi
	}

function ipshRemove
	{
	headLine "Удаление IPSh"
	echo "Вы действительно хотите удалить IPSh?"
	echo ""
	echo -e "\t1: Да"
	echo -e "\t0: Нет (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	echo ""
	if [ "$REPLY" = "1" ];then
		if [ -f "$PROFILE_PATH" ];then
			echo "Следует ли удалить файл настроек IPSh?"
			echo ""
			echo -e "\t1: Да (по умолчанию)"
			echo -e "\t0: Нет"
			echo ""
			read -r -p "Ваш выбор:"
			echo ""
			if [ ! "$REPLY" = "0" ];then
				rm -rf "$PROFILE_PATH"
				rm -rf "`dirname "$PROFILE_PATH"`"
			fi
		fi
		rm -rf "$TABLE_FILE"
		rm -rf "$LIST_FILE"
		rm -rf "$LOG_FILE"
		rm -rf "$FLAG_FILE"
		rm -rf "$PROXY_FILE"
		rm -rf "$BUTTON_FILE"
		ndmScriptDelete "no console"
		pingScheduleDelete "no console"
		echo ""
		echo -e "\tIPSh использует в своей работе сторонние пакеты..."
		echo ""
		if [ -n "`opkg list-installed | grep "^curl"`" ];then
			echo "Следует ли удалить пакет curl?"
			echo ""
			echo -e "\t1: Да (по умолчанию)"
			echo -e "\t0: Нет"
			echo ""
			read -r -p "Ваш выбор:"
			echo ""
			if [ ! "$REPLY" = "0" ];then
				echo "Удаление curl..."
				echo "`opkg remove curl`" > /dev/null
				echo ""
			fi
		fi
		if [ -n "`opkg list-installed | grep "^elinks"`" ];then
			echo "Следует ли удалить пакет elinks?"
			echo ""
			echo -e "\t1: Да (по умолчанию)"
			echo -e "\t0: Нет"
			echo ""
			read -r -p "Ваш выбор:"
			echo ""
			if [ ! "$REPLY" = "0" ];then
				echo "Удаление elinks..."
				echo "`opkg remove elinks`" > /dev/null
				echo ""
			fi
		fi
		if [ -n "`opkg list-installed | grep "^3proxy"`" ];then
			echo "Следует ли удалить пакет 3proxy?"
			echo ""
			echo -e "\t1: Да (по умолчанию)"
			echo -e "\t0: Нет"
			echo ""
			read -r -p "Ваш выбор:"
			echo ""
			if [ ! "$REPLY" = "0" ];then
				echo "Удаление 3proxy..."
				echo "`opkg remove 3proxy`" > /dev/null
				echo ""
			fi
		fi
		headLine
		copyRight "IPSh" "2025"
		rm -rf /opt/bin/ipsh
		clear
		exit
	fi
	}

function configReset
	{
	headLine "Сброс настроек"
	showText "\tУдаление файла конфигурации - позволит сбросить пользовательские настройки IPSh..."
	echo ""
	if [ -f "$PROFILE_PATH" ];then
		echo -e "\t1: Удалить файл конфигурации"
		echo -e "\t0: Отмена (по умолчанию)"
		echo ""
		read -r -p "Ваш выбор:"
		echo ""
		if [ "$REPLY" = "1" ];then
			rm -rf $PROFILE_PATH
			messageBox "Файл конфигурации - удалён."
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			headLine
			copyRight "IPSh" "2025"
			clear
			exit
		fi
	else
		messageBox "Файл конфигурации отсутствует." "\033[91m"
	fi
	}

function buttonSelect	#1 - без сохранения
	{
	local FLAG=$1
	echo "Выберите кнопку:"
	echo ""
	echo -e "\t1: Кнопка WiFi"
	echo -e "\t2: Кнопка FN1"
	echo -e "\t3: Кнопка FN2"
	showOption "\t4: Сохранить конфигурацию" "$FLAG"
	echo -e "\t0: Отмена (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:" BUTTON_NAME
	echo ""
	if [ "$BUTTON_NAME" = "1" -o "$BUTTON_NAME" = "2" -o "$BUTTON_NAME" = "3" ];then
		echo "Выберите тип нажатия:"
		echo ""
		echo -e "\t1: Короткое нажатие"
		echo -e "\t2: Двойное нажатие"
		echo -e "\t3: Длинное нажатие"
		echo -e "\t0: Отмена (по умолчанию)"
		echo ""
		read -r -p "Ваш выбор:" TYPE
		echo ""
		if [ "$TYPE" = "1" -o "$TYPE" = "2" -o "$TYPE" = "3" ];then
			echo "Выберите действие:"
			echo ""
			echo -e "\t1: Начать новый цикл"
			echo -e "\t2: Найти новый сервер"
			echo -e "\t0: Отмена (по умолчанию)"
			echo ""
			read -r -p "Ваш выбор:" ACTION
			echo ""
			if [ "$ACTION" = "1" -o "$ACTION" = "2" -o "$ACTION" = "3" ];then
				if [ "$ACTION" = "1" ];then
					ACTION='ipsh -R'
				else
					ACTION='ipsh -N'
				fi
				if [ "$TYPE" = "1" ];then
					TYPE='click'
				elif [ "$TYPE" = "2" ];then
					TYPE='double-click'
				else
					TYPE='hold'
				fi
				if [ "$BUTTON_NAME" = "1" ];then
					if [ -n "`echo $WLAN | grep "$TYPE"`" ];then
						local LIST="`echo -e "$WLAN" | awk '{gsub(/\t/,"\n")}1' | grep -v "^$TYPE"`"
						WLAN=""
						IFS=$'\n'
						for LINE in $LIST;do
							WLAN=$WLAN$LINE'\t'
						done
					fi
					WLAN=$WLAN$TYPE'&'$ACTION'\t'
				elif [ "$BUTTON_NAME" = "2" ];then
					if [ -n "`echo $FN1 | grep "$TYPE"`" ];then
						local LIST="`echo -e "$FN1" | awk '{gsub(/\t/,"\n")}1' | grep -v "^$TYPE"`"
						FN1=""
						IFS=$'\n'
						for LINE in $LIST;do
							FN1=$FN1$LINE'\t'
						done
					fi
					FN1=$FN1$TYPE'&'$ACTION'\t'
				else
					if [ -n "`echo $FN2 | grep "$TYPE"`" ];then
						local LIST="`echo -e "$FN2" | awk '{gsub(/\t/,"\n")}1' | grep -v "^$TYPE"`"
						FN2=""
						IFS=$'\n'
						for LINE in $LIST;do
							FN2=$FN2$LINE'\t'
						done
					fi
					FN2=$FN2$TYPE'&'$ACTION'\t'
				fi
				echo ""
				messageBox "Настройка - добавлена в конфигурацию."
				echo ""
				read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
				headLine "Новая конфигурация"
				buttonSelect
			fi
		fi
	elif [ "$BUTTON_NAME" = "4" ];then
		if [ -n "$FLAG" ];then
			messageBox "Отсутствуют данные для сохранения." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			headLine "Новая конфигурация"
			buttonSelect "no save"
		fi
	else
		WLAN=""
		FN1=""
		FN2=""
	fi
	}

function buttonConfig
	{
	headLine "Новая конфигурация"
	WLAN=""
	FN1=""
	FN2=""
	showText "\tНекоторые кнопки (из списка ниже) могут физически отсутствовать на вашей модели интернет-центра. Пожалуйста выбирайте только те кнопки - которые есть на устройстве..."
	echo ""
	buttonSelect "no save"
	if [ -n "$WLAN" -o -n "$FN1" -o -n "$FN2" ];then
		local TEXT='#!/opt/bin/sh\n\ncase "$button" in\n\n'
		if [ -n "$WLAN" ];then
			local TEXT=$TEXT'"WLAN")\n\tcase "$action" in\n'
			WLAN=`echo -e $WLAN`
			IFS=$'\t'
			for LINE in $WLAN;do
				local TEXT=$TEXT'\t"'`echo $LINE | awk '{gsub(/&/,"\")\n\t\t")}1'`'\n\t\t;;\n' 
			done
			local TEXT=$TEXT'\tesac\n\t;;\n'
		fi
		if [ -n "$FN1" ];then
			local TEXT=$TEXT'"FN1")\n\tcase "$action" in\n'
			FN1=`echo -e $FN1`
			IFS=$'\t'
			for LINE in $FN1;do
				local TEXT=$TEXT'\t"'`echo $LINE | awk '{gsub(/&/,"\")\n\t\t")}1'`'\n\t\t;;\n' 
			done
			local TEXT=$TEXT'\tesac\n\t;;\n'
		fi
		if [ -n "$FN2" ];then
			local TEXT=$TEXT'"FN2")\n\tcase "$action" in\n'
			FN2=`echo -e $FN2`
			IFS=$'\t'
			for LINE in $FN2;do
				local TEXT=$TEXT'\t"'`echo $LINE | awk '{gsub(/&/,"\")\n\t\t")}1'`'\n\t\t;;\n' 
			done
			local TEXT=$TEXT'\tesac\n\t;;\n'
		fi
		local TEXT=$TEXT'esac'
		echo -e "$TEXT" > "$BUTTON_FILE"
		messageBox "Новая конфигурация - сохранена."
		echo ""
		showText "\tНе забудьте выбрать вариант \"OPKG - Запуск скриптов button.d\" в веб-конфигураторе интернет-центра (Управление/Параметры системы/Назначение кнопок и индикаторов интернет-центра) для всех кнопок и типов нажатия - которые вы настроили..."
		echo ""
	else
		messageBox "Создания новой конфигурации - прервано."
		echo ""
		WLAN=""
		FN1=""
		FN2=""
	fi
	read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
	}

function buttonSetup
	{
	headLine "Настройка кнопок"
	showText "\tМожно управлять некоторыми функциями IPSh, при помощи аппаратных кнопок на интернет-центре..."
	echo ""
	if [ -f "$BUTTON_FILE" ];then
		messageBox "Конфигурация кнопок уже используется."
		local STATE=""
	else
		messageBox "Конфигурация не задана."
		local STATE="block"
	fi
	echo ""
	echo -e "\t1: Новая конфигурация"
	showOption  "\t2: Сброс конфигурации" "$STATE"
	echo -e "\t0: Отмена (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	echo ""
	if [ "$REPLY" = "1" ];then
		buttonConfig
		buttonSetup
	elif [ "$REPLY" = "2" ];then
		if [ -z "$STATE" ];then
			rm -rf $BUTTON_FILE
			messageBox "Файл конфигурации кнопок - удалён."
		else
			messageBox "Файл конфигурации кнопок отсутствует." "\033[91m"
		fi
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		buttonSetup
	fi
	}

function extraMenu
	{
	if [ ! -f "$PROFILE_PATH" ];then
		local STATE1="block"
	else
		local STATE1=""
	fi
	if [ ! -f "$TABLE_FILE" ];then
		local STATE2="block"
	else
		local STATE2=""
	fi
	if [ ! -f "$LIST_FILE" ];then
		local STATE3="block"
	else
		local STATE3=""
	fi
	headLine "Дополнительно"
	showOption "\t1: Сброс настроек" "$STATE1"
	showOption "\t2: Просмотр конфигурации" "$STATE1"
	showOption "\t3: Просмотр таблицы" "$STATE2"
	showOption "\t4: Просмотр списка" "$STATE3"
	echo -e "\t9: Удалить IPSh"
	echo -e "\t0: В главное меню (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	echo ""
	if [ "$REPLY" = "1" ];then
		if [ -z "$STATE1" ];then
			configReset
		else
			messageBox "Файл конфигурации отсутствует." "\033[91m"
		fi
		extraMenu
		exit
	elif [ "$REPLY" = "2" ];then
		if [ -z "$STATE1" ];then
			configShow
		else
			messageBox "Файл конфигурации отсутствует." "\033[91m"
		fi
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		extraMenu
		exit
	elif [ "$REPLY" = "3" ];then
		if [ -z "$STATE2" ];then
			tableShow
		else
			messageBox "Файл таблицы отсутствует." "\033[91m"
		fi
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		extraMenu
		exit
	elif [ "$REPLY" = "4" ];then
		if [ -z "$STATE3" ];then
			listShow
		else
			messageBox "Файл списка отсутствует." "\033[91m"
		fi
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		extraMenu
		exit
	elif [ "$REPLY" = "9" ];then
		ipshRemove
		extraMenu
		exit
	else
		mainMenu
		exit
	fi
	}

function mainMenu
	{
	if [ "$LOG" = "0" ];then
		local STATE="block"
	else
		local STATE=""
	fi
	headLine "IPSpeed.info helper"
	echo "Главное меню:"
	echo ""
	echo -e "\t1: Начать новый цикл"
	echo -e "\t2: Найти новый сервер"
	echo -e "\t3: Состояние подключения"
	echo -e "\t4: Прокси-сервер"
	echo -e "\t5: Политика доступа"
	showOption "\t6: Журнал" "$STATE"
	echo -e "\t8: Настройки"
	echo -e "\t9: Дополнительно"
	echo -e "\t0: Выход (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	echo ""
	if [ "$REPLY" = "1" ];then
		newCycleShow
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		mainMenu
		exit
	elif [ "$REPLY" = "2" ];then
		nextConnectionShow
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		mainMenu
		exit
	elif [ "$REPLY" = "3" ];then
		checkConnectionShow
		echo ""
		mainMenu
		exit
	elif [ "$REPLY" = "4" ];then
		proxySetup
		mainMenu
		exit
	elif [ "$REPLY" = "5" ];then
		policySetup
		mainMenu
		exit
	elif [ "$REPLY" = "6" ];then
		if [ -z "$STATE" ];then
			logShow
		else
			messageBox "Журнал - отключен." "\033[91m"
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		fi
		mainMenu
		exit
	elif [ "$REPLY" = "8" ];then
		settingsMenu
		exit
	elif [ "$REPLY" = "9" ];then
		extraMenu
		mainMenu
		exit
	else
		headLine
		copyRight "IPSh" "2025"
		clear
		exit
	fi
	}

function firstStart	# текст
	{
	headLine "Привет!"
	showText "\tПохоже это $1 IPSpeed.info helper... Существует мнение что: в хорошей программе - должна быть одна единственная кнопка: \"сделать хорошо\". Руководствуясь им, вам предоставляется возможность настроить почти всё - нажатием одной клавиши (Ввод). А получить доступ к более гибким настройкам, можно - перейдя в \"Главное меню\"..."
	echo ""
	echo -e "     Ввод: Сделать хорошо"
	echo -e "\t0: В главное меню"
	echo ""
	read -n 1 -r -p "Ваш выбор:"
	echo ""
	if [ -z "$REPLY" ];then
		interfaceID "force"
		connectionNew
		if [ -n "`isConnected`" ];then
			messageBox "Подключение - установлено."
			echo ""
			
		else
			connectionUp "force"
			if [ -n "`isConnected`" ];then
				messageBox "Подключение - установлено."
			else
				messageBox "Не удалось установить подключение."
				echo ""
				read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
				mainMenu
				exit
			fi
			
		fi
		connectionPing
		pingScheduleAdd
		if [ ! "$NDMS_VERSION" = "2.x" ];then
			ndmScriptAdd
		fi
		showText "\tВ интернет-центре (в \"Интернет/Другие подключения\") - создано/настроено SSTP-подключение: \"$INTERFACE_NAME\". Установлена связь с сервером и задействованы механизмы автоматического поддержания этого подключения в рабочем состоянии."
		echo ""
		showText "\tПерейдя в главное меню, вы можете настроить прокси-сервер и/или \"политику доступа\", чтобы получить возможность гибкого управления доступом приложений/устройств к этому подключению..."
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		mainMenu
	fi
	}

echo;while [ -n "$1" ];do
case "$1" in

-C)	connectionCheck
	exit
	;;

-D)	interfaceID
	isDisabled "skip" "context"
	exit
	;;

-f)	firstStart "имитация первого запуска"
	exit
	;;

-N)	flagCheck
	connectionNext
	exit
	;;

-n)	connectionNext
	exit
	;;

-P)	connectionPing
	exit
	;;

-R)	flagCheck
	connectionNew
	exit
	;;

-u)	SCRIPT_NAME="IPSh"
	headLine "Обновление $SCRIPT_NAME"
	FILE_NAME="`echo "$SCRIPT_NAME" | tr '[:upper:]' '[:lower:]'`"
	if [ -f "/opt/_update/$FILE_NAME.sh" ];then
		echo "Локальное обновление..."
		echo ""
		mv /opt/_update/$FILE_NAME.sh /opt/bin/$FILE_NAME
		rm -rf /opt/_update/
	else
		echo "Обновление..."
		echo ""
		echo "`opkg update`" > /dev/null
		echo "`opkg install ca-certificates wget-ssl`" > /dev/null
		echo "`opkg remove wget-nossl`" > /dev/null
		wget -q -O /tmp/$FILE_NAME.sh https://raw.githubusercontent.com/rino-soft-lab/ipsh/refs/heads/main/ipsh.sh
		if [ ! -n "`cat "/tmp/$FILE_NAME.sh" | grep 'function copyRight'`" ];then
			messageBox "Не удалось загрузить файл." "\033[91m"
			exit
		else
			mv /tmp/$FILE_NAME.sh /opt/bin/$FILE_NAME
		fi
	fi
	chmod +x /opt/bin/$FILE_NAME
	messageBox "$SCRIPT_NAME обновлён до версии: `cat "/opt/bin/$FILE_NAME" | grep '^VERSION="' | awk -F"=" '{print $2}' | awk '{gsub(/"/,"")}1'` build `cat "/opt/bin/$FILE_NAME" | grep '^BUILD="' | awk -F'"' '{print $2}'`"
	exit
	;;

-v)	echo "$0 $VERSION build $BUILD"
	LOADER_PATH="`dirname $PROFILE_PATH`/loader.sh"
	if [ -f "$LOADER_PATH" ];then
		echo "$LOADER_PATH `cat $LOADER_PATH | grep "^VERSION=" | awk -F'"' '{print $2}'`"
	fi
	exit
	;;

*) echo "Доступные ключи:

	-C: Проверка подключения (служебное)
	-D: Реакция на отключение интерфейса (служебное)
	-f: Имитация первого запуска
	-N: Поиск нового сервера (служебное)
	-n: Поиск нового сервера
	-P: Выполнение PING (служебное)
	-R: Начало нового цикла (служебное)
	-u: Обновление IPSh
	-v: Версия IPSh"
	exit
	;;

esac;shift;done
if [ ! -f "$PROFILE_PATH" -a ! -f "$TABLE_FILE" -a ! -f "$LIST_FILE" ];then
	firstStart "первый запуск"
fi
mainMenu
