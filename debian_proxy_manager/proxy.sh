#!/bin/bash

clear

echo "Do you want to [r]emove or [a]dd proxy settings to your system?"

read yno
case $yno in

        [rR] )
                ./removeproxy.sh
                ;;

        [aA] )
                ./proxyadd.sh
                exit 1
                ;;
        *) echo "Invalid input"
            ;;
esac


