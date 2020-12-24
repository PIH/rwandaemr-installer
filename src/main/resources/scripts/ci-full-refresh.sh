#!/bin/bash

set -uo pipefail
IFS=$'\n\t'

RETURN_CODE=0
SCRIPT_DIR=`dirname "$0"`

function usage() {
  echo "USAGE:"
  echo "ci-full-refresh --siteName=[rwinkwavu,butaro]"
}

SITE_NAME=""

for i in "$@"
do
case $i in
    --siteName=*)
      SITE_NAME="${i#*=}"
      shift # past argument=value
    ;;
    *)
      usage    # unknown option
      exit 1
    ;;
esac
done

if [ -z $SITE_NAME ]; then
  usage
  exit 1
fi

echo "$(date): Initiating full refresh for $SITE_NAME"

# Pull down the latest scripts
pushd $SCRIPT_DIR/../../../../
git pull --rebase
popd

# Download database volume
echo "$(date): Downloading prepared database volume for 1x"
$SCRIPT_DIR/download-rwanda-db.sh --siteName=$SITE_NAME
DB_VOLUME_ZIP_FILE="$(pwd)/dbs/$SITE_NAME-anonymized"

# Install 1x server using this docker db volume
echo "$(date): Installing 1.x environment"
$SCRIPT_DIR/install-1x.sh --siteName=$SITE_NAME --dbVolume=$DB_VOLUME_ZIP_FILE

# Export 1x DB
DB_DUMP_FILE="$(pwd)/dbs/${SITE_NAME}1x.sql"
echo "$(date): Exporting 1x DB using mysqldump for migration to $DB_DUMP_FILE"
$SCRIPT_DIR/export-db-for-upgrade.sh root password openmrs $DB_DUMP_FILE ${SITE_NAME}1x_db_1

# Install 2x server using this sql dump
echo "$(date): Migrating the 1.x SQL dump to a 2.x SQL dump and installing 2.x server"
$SCRIPT_DIR/install-2x.sh --siteName=$SITE_NAME --dbSqlDump=$DB_DUMP_FILE

echo "$(date): Full refresh for $SITE_NAME completed successfully.  Please examine logs to confirm."
