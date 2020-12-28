#!/bin/bash

set -uo pipefail
IFS=$'\n\t'

RETURN_CODE=0

SITE_NAME=""
DB_SQL_DUMP=""
OMRS_DB_PORT="3307"
OMRS_SERVER_PORT="8081"
SCRIPT_DIR=`dirname "$0"`

function usage() {
  echo "USAGE:"
  echo "install-2x --siteName=[rwinkwavu,butaro] --dbSqlDump=/path/to/mysqldump/for/1x.sql"
}

echo "Parsing input arguments"

for i in "$@"
do
case $i in
    --siteName=*)
      SITE_NAME="${i#*=}"
      shift # past argument=value
    ;;
    --dbSqlDump=*)
      DB_SQL_DUMP="${i#*=}"
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

if [ -z $DB_SQL_DUMP ]; then
  usage
  exit 1
fi

RUN_SITE_ID="${SITE_NAME}2x"
DB_CONTAINER="${RUN_SITE_ID}_db_1"
SERVER_CONTAINER="${RUN_SITE_ID}_server_1"
DISTRIBUTION_ARTIFACT_ID="rwandaemr-imb-$SITE_NAME"
DISTRIBUTION_VERSION="2.0.0-SNAPSHOT"
SERVER_CONTAINER_IMAGE="openmrs-server:latest"
DOCKER_COMPOSE_FILE="docker-compose-2x.yml"

DISTRIBUTION_NAME="$DISTRIBUTION_ARTIFACT_ID-$DISTRIBUTION_VERSION"

echo "Recreating 2x execution directory at $RUN_SITE_ID"
rm -fR $RUN_SITE_ID
mkdir -p "$RUN_SITE_ID"

# have to create .env file in the same directory with docker-compose.yml file
rm -rf  "$RUN_SITE_ID/.env"
cat > "$RUN_SITE_ID/.env" << EOF1
OMRS_DB_PORT=$OMRS_DB_PORT
OMRS_SERVER_PORT=$OMRS_SERVER_PORT
EOF1

# Stop and remove any existing docker containers
echo "Removing all existing docker containers"
docker ps --all
docker stop $SERVER_CONTAINER || true
docker rm -v $SERVER_CONTAINER || true
docker stop $DB_CONTAINER || true
docker rm -v $DB_CONTAINER || true
docker ps --all

echo "Executing the database migration"
$SCRIPT_DIR/execute-2x-migration.sh --inputSqlFile=$DB_SQL_DUMP --migrationDir=$(pwd)/$RUN_SITE_ID
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "Failed to successfully execute the database migration"
    exit $RETURN_CODE
fi

echo "Installing the distribution"
mkdir -p $RUN_SITE_ID/distribution
$SCRIPT_DIR/download-maven-artifact.sh --groupId=org.openmrs.distro --artifactId=$DISTRIBUTION_ARTIFACT_ID --version=$DISTRIBUTION_VERSION --classifier=distribution --type=zip --targetDir=$RUN_SITE_ID
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to download distribution artifact"
    exit $RETURN_CODE
fi
unzip $RUN_SITE_ID/$DISTRIBUTION_NAME-distribution.zip -d $RUN_SITE_ID/distribution
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to unzip distribution artifact to $RUN_SITE_ID/distribution"
    exit $RETURN_CODE
fi
mv $RUN_SITE_ID/distribution/$DISTRIBUTION_NAME/* $RUN_SITE_ID/distribution/
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to move distribution artifact to $RUN_SITE_ID/distribution"
    exit $RETURN_CODE
fi
rm -fR $RUN_SITE_ID/distribution/$DISTRIBUTION_NAME/

echo "Updating openmrs-server docker image"
docker pull partnersinhealth/$SERVER_CONTAINER_IMAGE
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to pull docker image partnersinhealth/$SERVER_CONTAINER_IMAGE"
    exit $RETURN_CODE
fi

echo "Starting up $DISTRIBUTION_NAME"

cp $SCRIPT_DIR/../docker/$DOCKER_COMPOSE_FILE $RUN_SITE_ID/docker-compose.yml
pushd $RUN_SITE_ID
docker-compose down -v || true
docker-compose up -d
popd

echo "OpenMRS is starting up"
# wait 10 seconds for the containers to start up
ping -w 1000 -c 10 127.0.0.1

# Watch for OpenMRS startup message in the logs
echo "Waiting for OpenMRS startup message..."
docker logs -f --tail 1000 $SERVER_CONTAINER 2>&1 | grep -q "INFO: Server startup in"
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
