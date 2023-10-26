#!/bin/bash
# Updates system-wide configs to add http proxy settings
clear

echo "--------------------------------------------------------------------"
echo "This script will look for old proxy settings on DEBIAN BASED DISTROs"
echo "Ask for your new proxy settings"
echo "and update your config files"
echo ""
echo "Files supported by this script are:"
echo "/etc/apt/apt.conf"
echo "~/.zshrc"
echo "~/.bashrc"
echo "Git"
echo "--------------------------------------------------------------------"

echo ""
## - Reading variables

echo "Input username:"
read username

echo ""
echo "Input password - WARNING - STORED IN CLEAR TEXT ON THE FILE SYSTEM :"
stty_orig=`stty -g`
stty -echo
read password
stty $stty_orig 

echo ""
echo "Input the proxy's hostname:"
read proxyhost

echo ""
echo "Input the proxy's port:"
read port

## Setting the proxyurl string
proxyurl="http://$username:$password@$proxyhost:$port"


## - Displaying settings for config files and setting variables
clear

echo "Files to be modified:"
echo ""
echo "[/etc/apt/apt.conf]"
echo "Acquire::http::Proxy $proxyurl;"
aptproxy="Acquire::http::Proxy $proxyurl;"
echo ""

echo "[~/.bashrc] and [~/.zshrc]"
echo "export http_proxy=$proxyurl"
zbproxy="export http_proxy=$proxyurl"
echo ""

echo "Press any key to continue or ctrl+c to quit"
read input1

clear


## Removes old proxy settings

#apt.conf
cp /etc/apt/apt.conf /etc/apt/apt.conf.preproxy
sed "/Proxy/d" /etc/apt/apt.conf >/etc/apt/apt.conf.new
cp /etc/apt/apt.conf.new /etc/apt/apt.conf

#zshrc
cp ~/.zshrc ~/.zshrc.preproxy
sed "/http_proxy/d" ~/.zshrc >~/.zshrc.new
cp ~/.zshrc.new ~/.zshrc

#bashrc
cp ~/.bashrc ~/.bashrc.preproxy
sed "/http_proxy/d" ~/.bashrc >~/.bashrc.new
cp ~/.bashrc.new ~/.bashrc


## - Adding proxy settings to config files

echo $aptproxy >> /etc/apt/apt.conf
echo $zbproxy >> ~/.zshrc
echo $zbproxy >> ~/.bashrc
touch ~/.gitconfig
git config --global http.proxy $proxyurl

echo "Config files updated"
echo "re-reading .bashrc / .zshrc"

source ~/.zshrc
source ~/.bashrc

exit 0
