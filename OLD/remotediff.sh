#!/bin/bash

# Remotediff written by Sam McLeod 20.5.11
set -x

clear

echo -n "Enter remote hostname: "
read hostname

echo -n "Enter remote filepath: "
read filepath

echo -n "Compair the same file / path locally? (y/n) "
read localcompair

if [ $localcompair = y ]; then
	$localfile <$filepath

else
	echo -n "Enter local filepath: "
	read localfile
fi

echo -n "Enter username on remote server: "
read username

clear

ssh $username@$hostname cat $filepath | diff $localfile - >/tmp/remotediff.tmp
cat /tmp/remotediff.tmp

read enter

echo -n "Would you like this emailed to you? (y/n)"
read email

if
	[ $email = y ]

	echo -n "What is your local username? "
	read localuser
then
	mailx -s /tmp/remotediff.tmp $localuser
fi
