#!/bin/bash -eu

source vars

#ports
#If defaults ports are in use, use other ports
# increments? -- this could work but what if that incremented port number is in use

#tomcat port
# what if port 9090 is in use?
Tomcat_Default_Port=$(lsof -i -P -n | grep LISTEN | grep  8080)
if [ -z "$Tomcat_Default_Port" ]
then
      echo "Using port 8080"
      sed -i 's/App_Port=.*/App_Port=8080/g' ../docker/.env

else
      echo "Port 8080 is in using port 9090"
      sed -i 's/App_Port=.*/App_Port=9090/g' ../docker/.env
fi

#mysql port
#what if port 3336 is in use?
MySQL_Default_Port=$(lsof -i -P -n | grep LISTEN | grep  3306)
if [ -z "$MySQL_Default_Port" ]
then
      echo "Using port 3306"
      sed -i 's/DB_Port=.*/App_Port=3306/g' ../docker/.env

else
      echo "Port 3306 is in using port 3336"
      sed -i 's/DB_Port=.*/App_Port=3336/g' ../docker/.env
fi

#if distribution is 2.x download latest image, if images is 1.x download 1.x image
if [ "$Version" == "1.1.0-SNAPSHOT" ];
then
      sed -i 's/Server_Image_Version=.*/Server_Image_Version=1.x/g' ../docker/.env
      sed -i "s/Site_Name=.*/Site_Name=${Artifact_ID}-${Version}/g" ../docker/.env
else
      sed -i 's/Server_Image_Version=.*/Server_Image_Version=latest/g' ../docker/.env
      sed -i "s/Site_Name=.*/Artifact_ID-Version/g" ../docker/.env
fi

#How should we handle container names?
#remove container name?
