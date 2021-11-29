#!/bin/bash

set -uo pipefail
IFS=$'\n\t'

RETURN_CODE=0

SITE_NAME=""
SCRIPT_DIR=`dirname "$0"`

function usage() {
  echo "USAGE:"
  echo "update-distribution-from-src --siteName=[rwinkwavu,butaro]"
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

if [ -z $SITE_NAME ]; then
  usage
  exit 1
fi

DISTRIBUTION_VERSION="2.0.0-SNAPSHOT"
SERVER_CONTAINER_IMAGE="openmrs-server:latest"
OMRS_SERVER_PORT="8081"

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
rm -fR $RUN_SITE_ID/github

mkdir $RUN_SITE_ID/github
pushd $RUN_SITE_ID/github
git clone https://github.com/Rwanda-EMR/openmrs-module-mohappointment && mvn clean install -f ./openmrs-module-mohappointment/pom.xml
git clone https://github.com/Rwanda-EMR/openmrs-module-mohtracportal && mvn clean install -f ./openmrs-module-mohtracportal/pom.xml
git clone https://github.com/Rwanda-EMR/openmrs-module-laboratorymanagement-v2 && mvn clean install -f ./openmrs-module-laboratorymanagement-v2/pom.xml
git clone https://github.com/Rwanda-EMR/openmrs-module-mohbilling && mvn clean install -f ./openmrs-module-mohbilling/pom.xml
git clone https://github.com/Rwanda-EMR/openmrs-module-rwandaprimarycare && mvn clean install -f ./openmrs-module-rwandaprimarycare/pom.xml
git clone https://github.com/PIH/openmrs-distro-rwandaemr-imb && mvn clean install -f ./openmrs-distro-rwandaemr-imb/pom.xml
popd

unzip ${RUN_SITE_ID}/github/openmrs-distro-rwandaemr-imb/${DISTRIBUTION_ARTIFACT_ID}/target/${DISTRIBUTION_NAME}-distribution.zip ${RUN_SITE_ID}/distribution
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
