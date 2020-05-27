#!/bin/bash -eu

Tomcat_Port="8080"

source .env

#Tomcat and Mysql default port
Tomcat_Default_Port=$(lsof -i -P -n | grep LISTEN | grep  8080)
MySQL_Default_Port=$(lsof -i -P -n | grep LISTEN | grep  3306)

# Use Tomcat default port if open, if it is not ask a user
# to specify port. If the port is also in use. Exit
if [ -z "$Tomcat_Default_Port" ]
then
  echo "Using port 8080"
  sed -i 's/App_Port=.*/App_Port=8080/g' ../docker/.env
else
  echo "Port 8080 in use,"
  while read -p 'Specify Tomcat Port to use: ' Tomcat_Port ;
  do
    Check_Tomcat_Port=$(lsof -i -P -n | grep LISTEN | grep  ${Tomcat_Port})
    if [ -z "$Check_Tomcat_Port" ];
    then
      echo "Using port $Tomcat_Port"
      sed -i "s/App_Port=.*/App_Port=$Tomcat_Port/g" ../docker/.env
    break
    else
      echo "Port $Tomcat_Port in use, specify another port"
      continue
    fi
  done
fi

# Use MySQL default port if open, if it doesn't ask a user
# to specify port. If the port is also in use, exit
if [ -z "$MySQL_Default_Port" ]
then
  echo "Using port 3306"
  sed -i 's/DB_Port=.*/DB_Port=8080/g' ../docker/.env
else
  echo "Port 3306 in use,"
  while read -p 'Specify MySQL Port to use: ' MySQL_Port ;
  do
    Check_MySQL_Port=$(lsof -i -P -n | grep LISTEN | grep  ${MySQL_Port})
    if [ -z "$Check_MySQL_Port" ];
    then
      echo "Using port $MySQL_Port"
      sed -i "s/DB_Port=.*/DB_Port=$MySQL_Port/g" ../docker/.env
    break
    else
      echo "Port $MySQL_Port in use, specify another port"
      continue
    fi
  done
fi