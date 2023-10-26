#!/bin/bash
# Usage:
#
# To make the node primary:
# /usr/bin/vipchange.sh makeactive
# Or to set the node to standby:
# /usr/bin/vipchange.sh disableactive
#
# The following variables are critical:
# the ${FOO:-"BAR"} allows to provide default values if nothing is provided when invoking the command

############################################################################################################################################
##
##  /!\ IF YOU EDIT THIS SCRIPT USE THE MOCKUP (AND TESTS!)
##
############################################################################################################################################

if [ -r /etc/vipchange.cfg ]; then
  . /etc/vipchange.cfg
fi

if [ -r ./vipchange.cfg ]; then
  . ./vipchange.cfg
fi

do_add() {
	echo -n "setting up new interface $1"
	/usr/bin/augtool <<-EOF
	set /files/etc/network/interfaces/iface[. = \'$POSTGRES_NIC\']/post-up "/sbin/ip addr add $2/$3 broadcast $POSTGRES_BCAST dev $POSTGRES_NIC label $1"
	save
	quit
	EOF
	if [ $? -eq 0 ]; then
		echo "success!"
	else
		echo "failed, debug follows:"
	  augtool print /augeas//error
	fi
}
do_rm() {
	echo -n "removing interface $1"
	/usr/bin/augtool <<-EOF
	rm /files/etc/network/interfaces/iface[. = \'$POSTGRES_NIC\']/post-up
	save
	quit
	EOF
	if [ $? -eq 0 ]; then
		echo "success!"
	else
		echo "failed, debug follows:"
		augtool print /augeas//error
	fi
}

check_nic() {
	ip addr show $POSTGRES_NIC > /dev/null
	if [ $? -ne 0 ] ; then
		echo "No such device $POSTGRES_NIC"
		exit 3
	fi
}

disable_active() {
	ip addr show $POSTGRES_NIC| grep $POSTGRES_NIC:active > /dev/null
	if [ $? -eq 0 ]; then
		echo "taking down $POSTGRES_NIC:active..."
		ip addr del $POSTGRES_ACTIVE_IP/$POSTGRES_ACTIVE_NETMASK dev $POSTGRES_NIC:active > /dev/null
	fi
	do_rm $POSTGRES_NIC:active
	do_add $POSTGRES_NIC:standby $POSTGRES_STANDBY_IP $POSTGRES_STANDBY_NETMASK
	echo "OK, now go to the standby node and run $0 makeactive"
}

make_active() {
	ip addr show $POSTGRES_NIC| grep $POSTGRES_NIC:standby > /dev/null
	if [ $? -eq 0 ]; then
		echo "taking down $POSTGRES_NIC:standby..."
		ip addr del $POSTGRES_STANDBY_IP/$POSTGRES_STANDBY_NETMASK dev $POSTGRES_NIC:standby > /dev/null
	fi
	do_rm $POSTGRES_NIC:standby
	do_add $POSTGRES_NIC:active $POSTGRES_ACTIVE_IP $POSTGRES_ACTIVE_NETMASK
	ip addr add $POSTGRES_ACTIVE_IP/$POSTGRES_ACTIVE_NETMASK broadcast $POSTGRES_BCAST dev $POSTGRES_NIC label $POSTGRES_NIC:active
	arping -c 4 -S $POSTGRES_ACTIVE_IP -i $POSTGRES_NIC $POSTGRES_BCAST
	ip addr show $POSTGRES_NIC| grep $POSTGRES_NIC:active > /dev/null
	if [ $? -eq 0 ]; then
		echo "brought up active IP, touching postgres file to trigger r/w now..."
		touch /tmp/postgresql.trigger.5432
		echo "Now active, check applications are OK."
	else
		echo "failed to bring up active IP, maybe you did not stop the active first....?"
	fi
}

make_standby() {
	ip addr show $POSTGRES_NIC| grep $POSTGRES_NIC:active > /dev/null
	if [ $? -eq 0 ]; then
		echo "READ THE WIKI PAGE, THAT WAS WRONG. THIS IS CURRENTLY AN ACTIVE NODE"
		exit 3
	else
		read -r -p "Do not forget to run syncpostgres.sh on the active node after this. Press any key to continue" response
		echo "bringing up $POSTGRES_NIC:standby..."
		ip addr del $POSTGRES_STANDBY_IP/$POSTGRES_STANDBY_NETMASK dev $POSTGRES_NIC:standby  > /dev/null
		ip addr add $POSTGRES_STANDBY_IP/$POSTGRES_STANDBY_NETMASK broadcast $POSTGRES_BCAST dev $POSTGRES_NIC label $POSTGRES_NIC:standby
		arping -c 4 -S $POSTGRES_STANDBY_IP -i $POSTGRES_NIC $POSTGRES_BCAST
		ip addr show $POSTGRES_NIC| grep $POSTGRES_NIC:standby > /dev/null
		if [ $? -eq 0 ]; then
			echo "brought up standby IP"
		else
			echo "failed to bring up standby IP, maybe you did not stop the standby first....?"
		fi
	fi
}

case "$1" in
	disableactive)
		check_nic
		disable_active
		;;
	makeactive)
		check_nic
		make_active
		;;
	makestandby)
		check_nic
		make_standby
		;;
	*)
		echo "Usage: $0 {disableactive|makeactive|makestandby}"
		exit 3
		;;
esac
