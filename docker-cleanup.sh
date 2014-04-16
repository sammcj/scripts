#!/bin/bash

echo "This will STOP all the following containers, REMOVE them, then DELETE the image"

echo "Containers:"
docker ps -a | grep -E '(^|\s)$1($|\s)'
echo "Images:"
docker images | grep -E '(^|\s)$1($|\s)'

read -r -p "Are you sure? [y/N] " response
case $response in
    [yY][eE][sS]|[yY])
        echo "There's no going back now..."
        docker stop $(docker ps -a | grep -E '(^|\s)$1($|\s)' | awk '{print $1}')
        docker rm $(docker ps -a | grep -E '(^|\s)$1($|\s)' | awk '{print $1}')
        docker rmi $(docker images | grep -E '(^|\s)$1($|\s)' | awk '{print $3}')
        ;;
    *)
        exit 0
        ;;
esac

