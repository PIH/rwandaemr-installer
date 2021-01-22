#!/bin/bash -e
#ALL VARIABLE VALUES ARE SET IN THIS FILE

DATE=`exec /bin/date`

USER=openmrs_maintenance_rwanda

USER_HOME_DIR=/home/$USER

ROOT_DIR=$USER_HOME_DIR/maintenance

#usually /var/lib/tomcat6/webapps
TOMCAT_WEBAPP_DIR=/var/lib/tomcat7/webapps

TOMCAT_USER=tomcat7

TOMCAT_SERVICE=tomcat7

#usually /home/openmrs/.OpenMRS/modules
OPENMRS_MODULES_DIR=/usr/share/tomcat7/.OpenMRS/modules

OPENMRS_RUNTIME_PROPERTIES_FILE=/usr/share/tomcat7/.OpenMRS/openmrs-runtime.properties

OPENMRS_DATABASE_NAME=openmrs

OPENMRS_WEBAPP_NAME=openmrs

