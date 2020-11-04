#!/bin/bash

set -uo pipefail
IFS=$'\n\t'

RETURN_CODE=0

URL=""
SERVER_ID=""
DEST_FILE=""

function usage() {
    echo "USAGE:"
    echo "update-module-from-url"
    echo ""
    echo "Input Options"
    echo " --url : Used to specify the location of the module to install"
    echo " --serverId : Used to specify the server to install into"
    echo " --destFile : Used to specify the name of the omod in the modules folder"
}

echo "Parsing input arguments"

for i in "$@"
do
    case $i in
	--url=*)
	    URL="${i#*=}"
	    shift # past argument=value
	    ;;
	--serverId=*)
	    SERVER_ID="${i#*=}"
	    shift # past argument=value
	    ;;
	--destFile=*)
	    DEST_FILE="${i#*=}"
	    shift # past argument=value
	    ;;
	*)
	    usage    # unknown option
	    exit 1
	    ;;
    esac
done

echo "Got input arguments:"
echo "URL: ${URL}"
echo "SERVER_ID: ${SERVER_ID}"
echo "DEST_FILE: ${DEST_FILE}"

DEST_DIR="/home/docker/${SERVER_ID}/distribution/openmrs_modules"

if [ ! -d "$DEST_DIR" ]; then
    echo "Invalid destination directory: $DEST_DIR"
    exit 1
fi

sudo wget $URL -O $DEST_DIR/$DEST_FILE

pushd /home/docker/$SERVER_ID
docker-compose down
docker-compose up -d
popd

echo "OpenMRS is starting up"
