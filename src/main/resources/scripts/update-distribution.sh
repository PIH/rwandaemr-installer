#!/bin/bash

set -uo pipefail
IFS=$'\n\t'

RETURN_CODE=0

SITE_NAME=""
VERSION=""
SCRIPT_DIR=`dirname "$0"`

function usage() {
  echo "USAGE:"
  echo "update-distribution --siteName=[rwinkwavu,butaro] --version=[1x,2x]"
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

if [ $VERSION == '1x' ]; then
  DISTRIBUTION_VERSION="1.1.0-SNAPSHOT"
  SERVER_CONTAINER_IMAGE="openmrs-server:1.x"
  OMRS_SERVER_PORT="8080"
elif [ $VERSION == '2x' ]; then
  DISTRIBUTION_VERSION="2.0.0-SNAPSHOT"
  SERVER_CONTAINER_IMAGE="openmrs-server:latest"
  OMRS_SERVER_PORT="8081"
else
  echo "You must specify either 1x or 2x for version."
  exit 1
fi

RUN_SITE_ID="${SITE_NAME}${VERSION}"
DB_CONTAINER="${RUN_SITE_ID}_db_1"
SERVER_CONTAINER="${RUN_SITE_ID}_server_1"
DISTRIBUTION_ARTIFACT_ID="rwandaemr-imb-$SITE_NAME"
DISTRIBUTION_NAME="$DISTRIBUTION_ARTIFACT_ID-$DISTRIBUTION_VERSION"

echo "Stopping OpenMRS"

pushd $RUN_SITE_ID
docker-compose down || true
popd

echo "Downloading latest distribution"
rm -fR $RUN_SITE_ID/distribution
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

echo "Starting OpenMRS back up"
pushd $RUN_SITE_ID
docker-compose up -d
popd

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
