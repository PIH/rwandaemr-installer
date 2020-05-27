#!/bin/bash -eu

source .env

#if distribution is 2.x download latest image, if images is 1.x download 1.x image
# setups container name
if [ "$Version" == "1.1.0-SNAPSHOT" ];
then
      sed -i 's/Server_Image_Version=.*/Server_Image_Version=1.x/g' ../docker/.env
else
      sed -i 's/Server_Image_Version=.*/Server_Image_Version=latest/g' ../docker/.env
fi

sed -i "s/Site_Name=.*/Site_Name=${Artifact_ID}-${Version}/g" ../docker/.env
