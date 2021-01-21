#!/bin/sh

# Backup one week's worth of OpenMRS database
#  and store locally.  Backup EVERYTHING including sync
#  tables.
SERVER_NAME=$(hostname)
LOWER_SERVER_NAME=$(echo "$SERVER_NAME" | tr '[:upper:]' '[:lower:]')
MYSQL_USER_NAME="root"
MYSQL_USER_PASSWORD=""

mkdir -p /home/backups/current
cd /home/openmrs/backups/
mkdir sequences
mkdir to_backup
mysqldump -u $MYSQL_USER_NAME -e -r --single-transaction -r "/home/backups/to_backup/$LOWER_SERVER_NAME-openmrs-dump.sql" -p$MYSQL_USER_PASSWORD openmrs

# Zip file
cd /home/backups/to_backup
gzip $LOWER_SERVER_NAME-openmrs-dump.sql

# Move to current directory and overwrite previous one
mv $LOWER_SERVER_NAME-openmrs-dump.sql.gz ../current/.

# copy current file to sequences
cd ../sequences
cp ../current/$LOWER_SERVER_NAME-openmrs-dump.sql.gz $LOWER_SERVER_NAME-openmrs-`date +%A`.sql.gz
