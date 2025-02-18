#!/bin/bash

# set variables
_VERSION=0.2.0

# create build
docker build -t johann8/postgresql-upgrade:${_VERSION}-debian . 2>&1 | tee ./build.log
_BUILD=$?
if ! [ ${_BUILD} = 0 ]; then
   echo "ERROR: Docker Image build was not successful"
   exit 1
else
   echo "Docker Image build successful"
   docker images -a 
   docker tag johann8/postgresql-upgrade:${_VERSION}-debian johann8/postgresql-upgrade:latest-debian
fi

#push image to dockerhub
if [ ${_BUILD} = 0 ]; then
   echo "Pushing docker images to dockerhub..."
   docker push johann8/postgresql-upgrade:latest-debian
   docker push johann8/postgresql-upgrade:${_VERSION}-debian
   _PUSH=$?
   docker images -a |grep postgresql-upgrade
fi


#delete build
if [ ${_PUSH=} = 0 ]; then
   echo "Deleting docker images..."
   docker rmi johann8/postgresql-upgrade:latest-debian
   #docker images -a
   docker johann8/postgresql-upgrade:${_VERSION}-debian
   #docker images -a
   #docker rmi ubuntu
   docker images -a
fi

# Delete none images
# docker rmi $(docker images --filter "dangling=true" -q --no-trunc)
