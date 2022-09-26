#!/bin/bash

# get all running docker container names
containers=$(sudo docker ps | awk '{if(NR>1) print $NF}')

# loop through all containers
for container in $containers; do
  invokeMatches=($(sudo docker exec $container /bin/sh -c "/bin/grep -o -i 'chown -R' /app/entrypoint.sh /app/invoke /app/invoke.sh 2> /dev/null"))

  for i in $invokeMatches; do
    app_env=($(docker inspect $container | egrep 'ENVIRONMENT'))
    app_tag=($(docker inspect $container | egrep 'SERVICE_TAGS'))
    echo "Chown abuse detected in $container in $app_env with $app_tag"

  done
done
