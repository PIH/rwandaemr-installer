#!/bin/bash -eu

source vars

#tomcat port
Tomcat_Default_Port=$(lsof -i -P -n | grep LISTEN | grep  8080)
if [ -z "$Tomcat_Default_Port" ]
then
      echo "Using port 8080"
      sed -i 's/App_Port=.*/App_Port=8080/g' ../docker/.env
else
      echo "Port 8080 in use, using the next available port in the range of 9090 - 9095"
      for port in $(seq 9090 9095);
      do
        echo -ne "\035" | telnet 127.0.0.1 $port > /dev/null 2>&1;
        [ $? -eq 1 ] && echo "Using $port" && sed -i 's/App_Port=.*/App_Port=$port/g' ../docker/.env && break;
      done
fi

#mysql port
MySQL_Default_Port=$(lsof -i -P -n | grep LISTEN | grep  3306)
if [ -z "$MySQL_Default_Port" ]
then
      echo "Using port 3306"
      sed -i 's/DB_Port=.*/App_Port=3306/g' ../docker/.env
else
#use the range of 3336 - 33342 if port 3306 is in use
      echo "Port 3306 is in using the next available port in the range 3336 to 33402"
      for port in $(seq 3336 3342);
      do
        echo -ne "\035" | telnet 127.0.0.1 $port > /dev/null 2>&1;
        [ $? -eq 1 ] && echo "Using $port" && sed -i 's/DB_Port=.*/DB_Port=$port/g' ../docker/.env && break;
      done
fi