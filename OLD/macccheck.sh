#!/bin/bash 

while [ 1 ]
do

	clear
	echo
	echo
	echo "Enter the PC asset number, or enter to exit"
	read PC
	if [ "" = "$PC" ]; then
		exit 0
	fi

	echo
	echo
	echo "Trying to ping PC...."
	ping -c 1 $PC > /dev/null 2>&1
	PSTATUS=$?

	clear
	echo
	echo
	echo "PC Name:"
	echo $PC

	echo
	echo
	case $PSTATUS in
	2)
		echo "Can not resolve PC name, try another asset"
		;;
	1)
		echo "Can resolve PC name but can not ping, use ntvdocs user tracker to search for MAC"
		;;
	0)
		echo "Can ping PC, this is the MAC:"
		IP=`nslookup $PC | awk '/Address/ {print $2}' | grep -v '#'`
		MAC=`nmblookup -A $IP | awk '/MAC/ {print $4}' | tr -d "-"`
		echo $MAC
		echo
		echo "Other commands for Homer:"
		echo "TNET-"$MAC"-0001"
		echo "SED PORT-PARAMS TNET-"$MAC"-0001"
		;;
	esac

	echo
	echo
	echo
	echo "Hit any key to continue"
	read -n 1 DUMMY

done
exit 0