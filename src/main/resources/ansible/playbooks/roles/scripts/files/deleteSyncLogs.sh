#!/bin/bash
## tomcat base directory 
DIR=/var/lib/tomcat7/
# stop tomcat
service tomcat7 stop
rm -rf ${DIR}/logs/*
rm -rf ${DIR}/webapps/openmrs
rm -rf ${DIR}/work/*
mv /usr/share/tomcat7/.OpenMRS/sync/recrd /usr/share/tomcat7/.OpenMRS/sync/old_recrd
rm -rf /usr/share/tomcat7/.OpenMRS/sync/old_recrd
# start tomcat
service tomcat7 start
