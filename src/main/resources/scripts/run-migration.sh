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
  echo "Execute a migration"
  echo ""
  echo "Input Options"
  echo " --siteName : Used to specify which DB to migrate"
  echo " --runId : Used to distinguish one run from another"
}

echo "Parsing input arguments"

for i in "$@"
do
case $i in
    --siteName=*)
      SITE_NAME="${i#*=}"
      shift # past argument=value
    ;;
    --runId=*)
      RUN_ID="${i#*=}"
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
if [ -z "$RUN_ID" ]; then
  read -e -p 'Run ID: ' -i "$SITE_NAME"-$(date +"%y-%m-%d-%H-%M") SITE_NAME
fi

echo "Got input arguments:"
echo "SITE NAME: ${SITE_NAME}"
echo "RUN ID: $RUN_ID"
RUN_SITE_ID="${SITE_NAME}$RUN_ID"
echo "RUN_SITE_ID: $RUN_SITE_ID"
DB_CONTAINER="${RUN_SITE_ID}_db_1"
SERVER_CONTAINER="${RUN_SITE_ID}_server_1"

echo "Creating directory for this run"
mkdir -p "$RUN_SITE_ID"
# have to create .env file in the same directory with docker-compose.yml file
rm -rf  "$RUN_SITE_ID/.env"
cat > "$RUN_SITE_ID/.env" << EOF1
OMRS_DB_PORT=$OMRS_DB_PORT
OMRS_SERVER_PORT=$OMRS_SERVER_PORT
EOF1
mkdir -p "dbs"

# Stop and remove any existing docker containers
docker ps --all
docker stop $RUN_SITE_ID || true
docker rm $RUN_SITE_ID || true
docker stop $SERVER_CONTAINER || true
docker rm $SERVER_CONTAINER || true
docker stop $DB_CONTAINER || true
docker rm $DB_CONTAINER || true
docker ps --all

DB_ZIP_NAME="$SITE_NAME-anonymized"
echo "DB_ZIP_NAME: $DB_ZIP_NAME"

if [ ! -f "dbs/$DB_ZIP_NAME.zip" ]; then
  echo "Downloading DB zip"
  wget --user $DB_REPO_USER --password $DB_REPO_PASSWORD -O dbs/$DB_ZIP_NAME.zip "$DB_REPO_BASE_URL/$DB_ZIP_NAME/data.zip"
  RETURN_CODE=$?
  if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to download $DB_REPO_BASE_URL/$DB_ZIP_NAME/data.zip"
    exit $RETURN_CODE
  fi
else
  echo "DB zip already downloaded"
fi

if [ -d "$RUN_SITE_ID/data/mysql" ]; then
  echo "Remove existing db"
  rm -rf "$RUN_SITE_ID/data"
fi
echo "Extracting DB from zip"
mkdir -p $RUN_SITE_ID/data
unzip dbs/$DB_ZIP_NAME.zip -d $RUN_SITE_ID/data
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to download unzip dbs/$DB_ZIP_NAME.zip to $RUN_SITE_ID/data"
    exit $RETURN_CODE
fi
mv $RUN_SITE_ID/data/data $RUN_SITE_ID/data/mysql
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to download move $RUN_SITE_ID/data/data to $RUN_SITE_ID/data/mysql"
    exit $RETURN_CODE
fi

DB_VOLUME_DIR=$(pwd)/$RUN_SITE_ID/data/mysql
echo "DB_VOLUME_DIR: $DB_VOLUME_DIR"

echo "Starting MySQL container using DB"
docker run --name $RUN_SITE_ID -d -p 3308:3306 -v $DB_VOLUME_DIR:/var/lib/mysql mysql:5.6 --character-set-server=utf8 --collation-server=utf8_unicode_ci --max_allowed_packet=1G

RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
  echo "failed to start docker db container with $RUN_SITE_ID/data/mysql"
  exit $RETURN_CODE
fi

if [ ! -d "$RUN_SITE_ID/openmrs-module-rwandaemr" ]; then
  echo "Downloading Migration code"
  pushd $RUN_SITE_ID
  git clone https://github.com/PIH/openmrs-module-rwandaemr
  RETURN_CODE=$?
  if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to download the migration code from https://github.com/PIH/openmrs-module-rwandaemr"
    exit $RETURN_CODE
  fi
  popd
else
  echo "Updating Migration code"
  pushd $RUN_SITE_ID/openmrs-module-rwandaemr
  git pull --rebase
  RETURN_CODE=$?
  if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to pull the latest migration code from https://github.com/PIH/openmrs-module-rwandaemr"
    exit $RETURN_CODE
  fi
  popd
fi

echo "Executing the Migration"
pushd $RUN_SITE_ID/openmrs-module-rwandaemr/migration
mvn liquibase:update -Ddb_port=3308 -Ddb_user=root -Ddb_password=password
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
  echo "failed to run liquibase data migrations"
  exit $RETURN_CODE
fi
popd


if [ ! -d "$RUN_SITE_ID/rwandaemr-installer" ]; then
  echo "Downloading Installer code"
  pushd $RUN_SITE_ID
  git clone https://github.com/PIH/rwandaemr-installer
  RETURN_CODE=$?
  if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to download the installer code from https://github.com/PIH/rwandaemr-installer"
    exit $RETURN_CODE
  fi
  popd
else
  echo "Updating Installer code"
  pushd $RUN_SITE_ID/rwandaemr-installer
  git pull --rebase
  RETURN_CODE=$?
  if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to pull the latest installer code from https://github.com/PIH/rwandaemr-installer"
    exit $RETURN_CODE
  fi
  popd
fi

if [ ! -d "$RUN_SITE_ID/distribution" ]; then
  echo "Downloading distribution artifact"
  mkdir -p $RUN_SITE_ID/distribution
  ./$RUN_SITE_ID/rwandaemr-installer/src/main/resources/scripts/download-maven-artifact.sh --groupId=org.openmrs.distro --artifactId=rwandaemr-imb --version=2.0.0-SNAPSHOT --classifier=distribution --type=zip --targetDir=$RUN_SITE_ID
  RETURN_CODE=$?
  if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to download distribution artifact"
    exit $RETURN_CODE
  fi
  unzip $RUN_SITE_ID/rwandaemr-imb-2.0.0-SNAPSHOT-distribution.zip -d $RUN_SITE_ID/distribution
  RETURN_CODE=$?
  if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to unzip distribution artifact to $RUN_SITE_ID/distribution"
    exit $RETURN_CODE
  fi
  mv $RUN_SITE_ID/distribution/rwandaemr-imb-2.0.0-SNAPSHOT/* $RUN_SITE_ID/distribution/
  RETURN_CODE=$?
  if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to move distribution artifact to $RUN_SITE_ID/distribution"
    exit $RETURN_CODE
  fi
  rm -fR $RUN_SITE_ID/distribution/rwandaemr-imb-2.0.0-SNAPSHOT/
else
  echo "Distribution already downloaded"
fi

echo "Updating openmrs-server docker image"
docker pull partnersinhealth/openmrs-server:latest
RETURN_CODE=$?
  if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to pull docker image partnersinhealth/openmrs-server:latest"
    exit $RETURN_CODE
  fi
echo "Starting up OpenMRS distribution to run through the upgrade"

pushd $RUN_SITE_ID
cp ./rwandaemr-installer/src/main/resources/docker/docker-compose.yml .
docker-compose up -d
popd

docker logs -f $SERVER_CONTAINER
