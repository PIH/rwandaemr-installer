#!/bin/bash -eu

source vars

#tomcat port
#use the range of 9090 - 9095 if
echo "Using the next available port in the range of 9090 - 9095 for tomcat docker"

function unused_tomcat_port() {
  for tomcat_port in $(seq 9090 9096);
  do
    echo -ne "\035" | telnet 127.0.0.1 $tomcat_port > /dev/null 2>&1;
    [ $? -eq 1 ] && echo $tomcat_port && break;
  done
}

free_tomcat_port="$(unused_tomcat_port)"
echo $free_tomcat_port
sed -i "s/App_Port=.*/App_Port=$free_tomcat_port/g" ../docker/.env

#mysql port
#use the range of 3336 - 3342
echo "Using the next available port in the range 3336 to 3342 for mysql docker"

function unused_mysql_port() {
  for mysql_port in $(seq 3336 3342);
  do
    echo -ne "\035" | telnet 127.0.0.1 $mysql_port > /dev/null 2>&1;
    [ $? -eq 1 ] && echo $mysql_port && break;
  done
}

free_mysql_port="$(unused_mysql_port)"
echo $free_mysql_port
sed -i "s/DB_Port=.*/DB_Port=$free_mysql_port/g" ../docker/.env