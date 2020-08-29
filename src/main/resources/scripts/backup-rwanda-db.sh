#!/bin/bash

set -uo pipefail
IFS=$'\n\t'

RETURN_CODE=0

SITE_NAME=""
VERSION=""
RUN_ID=""
OMRS_DB_PORT=""
OMRS_SERVER_PORT=""
RECREATE="false"


function usage() {
  echo "USAGE:"
  echo "rwandaemr installer"
  echo ""
  echo "Input Options"
  echo " --siteName : Used to specify which DB to backup"
  echo " --version : Either 1x or 2x"
  echo " --runId : By default, this will be ${siteName}${version}. This allows overriding this."
}

echo "Parsing input arguments"

for i in "$@"
do
case $i in
    --siteName=*)
      SITE_NAME="${i#*=}"
      shift # past argument=value
    ;;
    --version=*)
      VERSION="${i#*=}"
      shift # past argument=value
    ;;
    --runId=*)
      RUN_ID="${i#*=}"
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
if [ -z "$VERSION" ]; then
  read -e -p 'Version: ' -i "2x" VERSION
fi
if [ -z "$OMRS_SERVER_PORT" ]; then
  read -e -p 'OMRS_SERVER_PORT: ' -i "8081" OMRS_SERVER_PORT
fi

echo "Got input arguments:"
echo "SITE NAME: ${SITE_NAME}"
echo "VERSION: ${VERSION}"
echo "RUN ID: $RUN_ID"
echo "OMRS_SERVER_PORT: $OMRS_SERVER_PORT"

RUN_SITE_ID="${SITE_NAME}${VERSION}${RUN_ID}"
echo "RUN_SITE_ID: $RUN_SITE_ID"
DB_CONTAINER="${RUN_SITE_ID}_db_1"
SERVER_CONTAINER="${RUN_SITE_ID}_server_1"

if [ $VERSION == '1x' ]; then
  DISTRIBUTION_ARTIFACT_ID="rwandaemr-imb-$SITE_NAME"
  DISTRIBUTION_VERSION="1.1.0-SNAPSHOT"
  SERVER_CONTAINER_IMAGE="openmrs-server:1.x"
  DOCKER_COMPOSE_FILE="docker-compose-1x.yml"
  PRE_MIGRATIONS=""
  POST_MIGRATIONS=""
elif [ $VERSION == '2x' ]; then
  DISTRIBUTION_ARTIFACT_ID="rwandaemr-imb"
  DISTRIBUTION_VERSION="2.0.0-SNAPSHOT"
  SERVER_CONTAINER_IMAGE="openmrs-server:latest"
  DOCKER_COMPOSE_FILE="docker-compose-2x.yml"
  PRE_MIGRATIONS="pre-2x-upgrade"
  POST_MIGRATIONS="post-2x-upgrade"
else
  echo "You must specify either 1x or 2x for version."
  exit 1
fi


if [ ! -d "$RUN_SITE_ID/data/mysql" ]; then
    echo "Directory: $RUN_SITE_ID/data/mysql does not exist. There is no database here to backup"
    exit 9999
else
    echo "Directory: $RUN_SITE_ID/data/mysql exists."
fi

# this is the directory where the zipped db would be stored
mkdir -p "dbs"

# Stop and remove any existing docker containers
docker ps --all
docker stop $SERVER_CONTAINER || true
docker rm $SERVER_CONTAINER || true
docker stop $DB_CONTAINER || true
docker rm $DB_CONTAINER || true
docker ps --all

DB_ZIP_NAME="$RUN_SITE_ID"
echo "DB_ZIP_NAME: $DB_ZIP_NAME"

rm -rf dbs/$DB_ZIP_NAME.zip
# zip the $RUN_SITE_ID/data/mysql folder
pushd $RUN_SITE_ID/data/
zip -r ../../dbs/$DB_ZIP_NAME.zip mysql
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to zip $RUN_SITE_ID/data/mysql"
    exit $RETURN_CODE
  fi
popd

pushd $RUN_SITE_ID
docker-compose up -d
popd

echo "OpenMRS is starting up"

# Watch for OpenMRS startup message in the logs
echo "Waiting for OpenMRS startup message..."
docker logs -f --tail 100 $SERVER_CONTAINER 2>&1 | grep -q "INFO: Server startup in"
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
