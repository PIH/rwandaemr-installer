#!/bin/bash

set -uo pipefail
IFS=$'\n\t'

RETURN_CODE=0

SITE_NAME=""
RUN_ID=""

# read environment variables DB_REPO_USER, DB_REPO_PASSWORD and DB_REPO_BASE_URL from env_vars file located in the same directory
source .env
RETURN_CODE=$?

if [[ $RETURN_CODE != 0 ]]; then
  echo "env_vars file is missing"
  exit $RETURN_CODE
fi

function usage() {
  echo "USAGE:"
  echo "Download database from repository"
  echo ""
  echo "Input Options"
  echo " --siteName : Used to specify which DB to migrate"
}

echo "Parsing input arguments"

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

echo "Prompt user for input arguments if necessary"

if [ -z "$SITE_NAME" ]; then
  read -e -p 'Site Name: ' -i "butaro" SITE_NAME
fi

echo "Got input argument:"
echo "SITE NAME: ${SITE_NAME}"

echo "Creating directory for downloading the db"
mkdir -p "dbs"


DB_ZIP_NAME="$SITE_NAME-anonymized"
echo "DB_ZIP_NAME: $DB_ZIP_NAME"

# attempt to download a new db to a temp folder
rm -rf /tmp/$DB_ZIP_NAME.zip
wget --user $DB_REPO_USER --password $DB_REPO_PASSWORD -O /tmp/$DB_ZIP_NAME.zip "$DB_REPO_BASE_URL/$DB_ZIP_NAME/data.zip"
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to download $DB_REPO_BASE_URL/$DB_ZIP_NAME/data.zip"
    exit $RETURN_CODE
fi

# replace the existing copy of the db
rm -rf dbs/$DB_ZIP_NAME.zip
mv /tmp/$DB_ZIP_NAME.zip dbs/
ls -lah dbs/



