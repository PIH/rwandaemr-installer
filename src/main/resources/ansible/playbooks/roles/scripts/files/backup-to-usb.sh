#! /bin/bash
# USB openmrs DB Backup Script
#

MYSQL_USERNAME='root'
MYSQL_PASSWORD=''
OPENMRS_DATABASE_NAME='openmrs'
DIR=/media/home/Data_backup/
ENCRYPTION_PASSWORD=''


if [ -n "$1" ]
then
  MODIFIER=release_$1
else
  MODIFIER=`date +%Y%m%d-%H%M%S`
fi

FILENAME=rwanda_backup_${MODIFIER}.sql.7z
CURRENT_FILENAME=rwanda_current_backup.sql.7z

# create the needed directories
mkdir -p ${DIR}/current
mkdir -p ${DIR}/sequences

# Dump database, encrypt and compress
mysqldump -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} --opt --flush-logs --single-transaction ${OPENMRS_DATABASE_NAME} | 7z a -p${ENCRYPTION_PASSWORD} -si -t7z ${DIR}/sequences/${FILENAME} -mx9

# link the current to the latest dump
rm -f ${DIR}/current/${CURRENT_FILENAME}
ln -s ${DIR}/sequences/${FILENAME} ${DIR}/current/${CURRENT_FILENAME}
