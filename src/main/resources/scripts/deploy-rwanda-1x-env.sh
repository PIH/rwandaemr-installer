#!/bin/bash

set -uo pipefail
IFS=$'\n\t'

RETURN_CODE=0

SITE_NAME=""
DB_NAME=""
RUN_ID=""
OMRS_DB_PORT=""
OMRS_SERVER_PORT=""


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
  echo " --siteName : Used to specify the subdirectory name"
  echo " --dbName : Used to specify which DB to migrate"
  echo " --runId : Used to distinguish one run from another"
  echo " --omrsDbPort : Used to specify the mysql db port"
  echo " --omrsServerPort : Used specify the OpenMRS webapp port"
}

echo "Parsing input arguments"

for i in "$@"
do
case $i in
    --siteName=*)
      SITE_NAME="${i#*=}"
      shift # past argument=value
    ;;
    --dbName=*)
      DB_NAME="${i#*=}"
      shift # past argument=value
    ;;
    --runId=*)
      RUN_ID="${i#*=}"
      shift # past argument=value
    ;;
    --omrsDbPort=*)
      OMRS_DB_PORT="${i#*=}"
      shift # past argument=value
    ;;
    --omrsServerPort=*)
      OMRS_SERVER_PORT="${i#*=}"
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
  read -e -p 'Site Name: ' -i "rwinkwavu" SITE_NAME
fi
if [ -z "$DB_NAME" ]; then
  read -e -p 'Site Name: ' -i "rwinkwavu" SITE_NAME
fi
if [ -z "$RUN_ID" ]; then
  read -e -p 'Run ID: ' -i "$SITE_NAME"-$(date +"%y-%m-%d-%H-%M") SITE_NAME
fi
if [ -z "$OMRS_DB_PORT" ]; then
  read -e -p 'OMRS_DB_PORT: ' -i "3308" OMRS_DB_PORT
fi
if [ -z "$OMRS_SERVER_PORT" ]; then
  read -e -p 'OMRS_SERVER_PORT: ' -i "8081" OMRS_SERVER_PORT
fi


echo "Got input arguments:"
echo "SITE NAME: ${SITE_NAME}"
echo "DB NAME: ${DB_NAME}"
echo "RUN ID: $RUN_ID"
echo "OMRS_DB_PORT: $OMRS_DB_PORT"
echo "OMRS_SERVER_PORT: $OMRS_SERVER_PORT"

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
docker stop $SERVER_CONTAINER || true
docker rm $SERVER_CONTAINER || true
docker stop $DB_CONTAINER || true
docker rm $DB_CONTAINER || true
docker ps --all

DB_ZIP_NAME="$DB_NAME-anonymized"
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

if [ ! -d "$RUN_SITE_ID/data/mysql" ]; then
    echo "The data mysql directory does not exist"
    mkdir -p $RUN_SITE_ID/data
    unzip dbs/$DB_ZIP_NAME.zip -d $RUN_SITE_ID/data
    RETURN_CODE=$?
    if [[ $RETURN_CODE != 0 ]]; then
        echo "failed to unzip dbs/$DB_ZIP_NAME.zip to $RUN_SITE_ID/data"
        exit $RETURN_CODE
    fi
    mv $RUN_SITE_ID/data/data $RUN_SITE_ID/data/mysql
    RETURN_CODE=$?
    if [[ $RETURN_CODE != 0 ]]; then
        echo "failed to move $RUN_SITE_ID/data/data to $RUN_SITE_ID/data/mysql"
        exit $RETURN_CODE
    fi
else
    echo "The data mysql directory already exists"
fi

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

if [ -d "$RUN_SITE_ID/distribution" ]; then
  echo "Removing the existing distribution"
  rm -rf $RUN_SITE_ID/distribution
fi
echo "Downloading distribution artifact"
mkdir -p $RUN_SITE_ID/distribution
./$RUN_SITE_ID/rwandaemr-installer/src/main/resources/scripts/download-maven-artifact.sh --groupId=org.openmrs.distro --artifactId=rwandaemr-imb-rwinkwavu --version=1.1.0-SNAPSHOT --classifier=distribution --type=zip --targetDir=$RUN_SITE_ID
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to download distribution artifact"
    exit $RETURN_CODE
fi
unzip $RUN_SITE_ID/rwandaemr-imb-rwinkwavu-1.1.0-SNAPSHOT-distribution.zip -d $RUN_SITE_ID/distribution
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to unzip distribution artifact to $RUN_SITE_ID/distribution"
    exit $RETURN_CODE
fi
mv $RUN_SITE_ID/distribution/rwandaemr-imb-rwinkwavu-1.1.0-SNAPSHOT/* $RUN_SITE_ID/distribution/
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to move distribution artifact to $RUN_SITE_ID/distribution"
    exit $RETURN_CODE
fi
rm -fR $RUN_SITE_ID/distribution/rwandaemr-imb-rwinkwavu-1.1.0-SNAPSHOT/

echo "Updating openmrs-server docker image"
docker pull partnersinhealth/openmrs-server:1.x
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to pull docker image partnersinhealth/openmrs-server:1.x"
    exit $RETURN_CODE
fi
echo "Starting up OpenMRS 1.x distribution"

pushd $RUN_SITE_ID/rwandaemr-installer
git checkout 1.x
popd

pushd $RUN_SITE_ID
cp ./rwandaemr-installer/src/main/resources/docker/docker-compose.yml .
docker-compose up -d
popd

# it will stop reading the logs when OpenMRS starts up
docker logs -f --tail 20 $SERVER_CONTAINER 2>&1 | grep -q "INFO: Server startup in"
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "RETURN_CODE when looking for server startup message: $RETURN_CODE"
    # OpenMRS started
fi
echo "OpenMRS has started"
# now print the entire openmrs.log
docker logs $SERVER_CONTAINER

echo "check url: http://localhost:$OMRS_SERVER_PORT/openmrs/"
RESPONSE=$(curl --write-out %{http_code} --silent --output /dev/null "http://localhost:$OMRS_SERVER_PORT/openmrs/")
echo "curl RESPONSE= $RESPONSE"
if [[ $RESPONSE != 200 ]]; then
    if [[ $RESPONSE != 302 ]]; then
        echo "OpenMRS web app is not responding"
        exit 1
     fi
fi
echo "OpenMRS web app is app and running"
