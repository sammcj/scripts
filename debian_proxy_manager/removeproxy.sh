#!/bin/bash

##removeproxys.sh


clear

echo "Are you sure you want to REMOVE proxy settings to your system? (Y/N)"

read yno
case $yno in

        [yY] )
                .#apt.conf
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

		#git
		git config --global http.proxy ""
                ;;

        *) echo "Cancelled"
		exit 1
            ;;
esac





