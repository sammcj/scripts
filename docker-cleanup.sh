#!/bin/bash
set -o nounset
set -o errexit

GetDockerID() {
    grep -E '(^|\s)$1($|\s)'
}

GetDockerID() {
    grep -E '(^|\s)$1($|\s)'
}

echo "This will STOP all the following containers, REMOVE them, then DELETE the image"

echo "Containers:"
docker ps -a | GetDockerID
echo "Images:"
docker images | GetDockerID

read -r -p "Are you sure? [y/N] " response
case $response in
[yY][eE][sS] | [yY])
    echo "There's no going back now..."
    docker stop "$(docker ps -a | GetDockerID | awk '{print $1}')"
    docker rm "$(docker ps -a | GetDockerID | awk '{print $1}')"
    docker rmi "$(docker images | GetDockerID | awk '{print $3}')"
    ;;
*)
    exit 0
    ;;
esac
