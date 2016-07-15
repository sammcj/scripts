#!/bin/bash
#
# Author: Ross Williamson, Infoxchange

# The purpose of this script is to easily run interface-rename on XenServer in order to order the network interfaces in a common
# way on all pool members. This typically gets run after a fresh install of XS, as it usually picks up the NICs on the HP
# blades in the wrong order.
# This script could be injected into the XS installer ISO as until the interfaces are in the correct order, network connection is
# impossible. Therefore it would be useless for this to go into puppet or any other form of post-install automation.

set -e

IR=$(interface-rename -l 2>/dev/null)
#IR=$(cat ixint.txt)


echo "Current state:"
printf %s "$IR"
echo ""
echo "---------------------------"

CPORT=''

function get_port_by_name() {
  PORT=$(printf %s "$IR" | grep "$*" | sed 's/  /|/g')
  CPORT=$PORT
}

get_port_by_name 'Port 1'
OBNIC1MAC=$(echo $CPORT | cut -d'|' -f 2)
OBNIC1NAME=$(echo $CPORT | cut -d'|' -f 6)
OBNIC1PHYS=$(echo $CPORT | cut -d'|' -f 5)

get_port_by_name 'Port 2'
OBNIC2MAC=$(echo $CPORT | cut -d'|' -f 2)
OBNIC2NAME=$(echo $CPORT | cut -d'|' -f 6)
OBNIC2PHYS=$(echo $CPORT | cut -d'|' -f 5)

get_port_by_name 'Mezzanine Slot 1'
SLOT1P1=$(printf %s "$CPORT" | grep 'p1p1')
MSLOT1P1MAC=$(echo $SLOT1P1 | cut -d'|' -f 2)
MSLOT1P1NAME=$(echo $SLOT1P1 | cut -d'|' -f 6)
MSLOT1P1PHYS=$(echo $SLOT1P1 | cut -d'|' -f 5)

SLOT1P2=$(printf %s "$CPORT" | grep 'p1p2')
MSLOT1P2MAC=$(echo $SLOT1P2 | cut -d'|' -f 2)
MSLOT1P2NAME=$(echo $SLOT1P2 | cut -d'|' -f 6)
MSLOT1P2PHYS=$(echo $SLOT1P2 | cut -d'|' -f 5)

echo "Detected ONBOARD port 1 as MAC=$OBNIC1MAC NAME=$OBNIC1NAME PHYS=$OBNIC1PHYS"
echo "Detected ONBOARD port 2 as MAC=$OBNIC2MAC NAME=$OBNIC2NAME PHYS=$OBNIC2PHYS"
echo "Detected MEZZANINE slot 1 port 1 as MAC=$MSLOT1P1MAC NAME=$MSLOT1P1NAME PHYS=$MSLOT1P1PHYS"
echo "Detected MEZZANINE slot 1 port 2 as MAC=$MSLOT1P2MAC NAME=$MSLOT1P2NAME PHYS=$MSLOT1P2PHYS"
echo "---------------------------"
echo "If the current state is incorrect, the interface-rename command we will run will be:"
IRCMD="interface-rename --update eth0=$OBNIC1MAC eth1=$OBNIC2MAC eth2=$MSLOT1P1MAC eth3=$MSLOT1P2MAC"
echo ""
echo $IRCMD
echo ""
echo -n "Do you want to go ahead and run the command now y/n?"
read reply

if [ "$reply" = y -o "$reply" = Y ]
then
   $IRCMD
   echo "interface-rename WAS run, reboot now for changes to take effect"
else
   echo "interface-rename was NOT run"
fi

