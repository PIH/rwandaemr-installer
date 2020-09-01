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
SYNC_PARENT_ADDRESS=""
SYNC_PARENT_USER_NAME=""
SYNC_PARENT__USER_PASSWORD=""

# read environment variables DB_REPO_USER, DB_REPO_PASSWORD and DB_REPO_BASE_URL from env_vars file located in the same directory
source .env
RETURN_CODE=$?

if [[ $RETURN_CODE != 0 ]]; then
  echo ".env file is missing"
  exit $RETURN_CODE
fi

function usage() {
  echo "USAGE:"
  echo "rwandaemr installer"
  echo ""
  echo "Input Options"
  echo " --siteName : Used to specify which DB to migrate"
  echo " --version : Either 1x or 2x"
  echo " --runId : By default, this will be ${siteName}${version}. This allows overriding this."
  echo " --omrsDbPort : Used to specify the mysql db port"
  echo " --omrsServerPort : Used specify the OpenMRS webapp port"
  echo " --recreate=true : If specified, this will recreate the instance from scratch"
  echo " --syncParentAddress= http://rwinkwavu-ci.pih-emr.org:8081/openmrs/: The Parent OpenMRS URL"
  echo " --syncParentUserName=userName : Parent login username"
  echo " --syncParentUserPassword=userPassword : Parent login user password"
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
    --omrsDbPort=*)
      OMRS_DB_PORT="${i#*=}"
      shift # past argument=value
    ;;
    --omrsServerPort=*)
      OMRS_SERVER_PORT="${i#*=}"
      shift # past argument=value
    ;;
    --recreate=*)
      RECREATE="${i#*=}"
      shift # past argument=value
    ;;
    --syncParentAddress=*)
      SYNC_PARENT_ADDRESS="${i#*=}"
      shift # past argument=value
    ;;
    --syncParentUserName=*)
      SYNC_PARENT_USER_NAME="${i#*=}"
      shift # past argument=value
    ;;
    --syncParentUserPassword=*)
      SYNC_PARENT__USER_PASSWORD="${i#*=}"
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
if [ -z "$OMRS_DB_PORT" ]; then
  read -e -p 'OMRS_DB_PORT: ' -i "3308" OMRS_DB_PORT
fi
if [ -z "$OMRS_SERVER_PORT" ]; then
  read -e -p 'OMRS_SERVER_PORT: ' -i "8081" OMRS_SERVER_PORT
fi
if [ -z "$RECREATE" ]; then
  read -e -p 'Recreate: ' -i "false" RECREATE
fi
if [ -z "$SYNC_PARENT_ADDRESS" ]; then
  read -e -p 'Sync Parent address: ' -i "http://rwinkwavu-ci.pih-emr.org:8081/openmrs/" SYNC_PARENT_ADDRESS
fi
if [ -z "$SYNC_PARENT_USER_NAME" ]; then
  read -e -p 'Sync parent user name: ' -i "userName" SYNC_PARENT_USER_NAME
fi
if [ -z "$SYNC_PARENT__USER_PASSWORD" ]; then
  read -e -p 'Site Name: ' -i "userPassword" SYNC_PARENT__USER_PASSWORD
fi

echo "Got input arguments:"
echo "SITE NAME: ${SITE_NAME}"
echo "VERSION: ${VERSION}"
echo "RUN ID: $RUN_ID"
echo "OMRS_DB_PORT: $OMRS_DB_PORT"
echo "OMRS_SERVER_PORT: $OMRS_SERVER_PORT"
echo "RECREATE: ${RECREATE}"
echo "SYNC_PARENT_ADDRESS: ${SYNC_PARENT_ADDRESS}"

PARENT_RUN_SITE_ID="${SITE_NAME}${VERSION}${RUN_ID}"
CHILD_RUN_SITE_ID="${SITE_NAME}${VERSION}${RUN_ID}-child"
echo "PARENT_RUN_SITE_ID: $PARENT_RUN_SITE_ID"
echo "CHILD_RUN_SITE_ID: $CHILD_RUN_SITE_ID"

DB_CONTAINER="${CHILD_RUN_SITE_ID}_db_1"
SERVER_CONTAINER="${CHILD_RUN_SITE_ID}_server_1"

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

DISTRIBUTION_NAME="$DISTRIBUTION_ARTIFACT_ID-$DISTRIBUTION_VERSION"

if [[ "$RECREATE" == "true" ]]; then
  rm -fR $CHILD_RUN_SITE_ID
fi

echo "Creating directory for this run"
mkdir -p "$CHILD_RUN_SITE_ID"
# have to create .env file in the same directory with docker-compose.yml file
rm -rf  "$CHILD_RUN_SITE_ID/.env"
cat > "$CHILD_RUN_SITE_ID/.env" << EOF1
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

DB_ZIP_NAME="$PARENT_RUN_SITE_ID"
echo "DB_ZIP_NAME: $DB_ZIP_NAME"

if [ ! -f "dbs/$DB_ZIP_NAME.zip" ]; then
  echo "Parent DB is missing in dbs/$DB_ZIP_NAME.zip. Please run CI plan to backup parent Db"
  exit 1
fi

if [ ! -d "$CHILD_RUN_SITE_ID/data/mysql" ]; then
    echo "The data mysql directory does not exist"
    mkdir -p $CHILD_RUN_SITE_ID/data
    unzip dbs/$DB_ZIP_NAME.zip -d $CHILD_RUN_SITE_ID/data
    RETURN_CODE=$?
    if [[ $RETURN_CODE != 0 ]]; then
        echo "failed to unzip dbs/$DB_ZIP_NAME.zip to $CHILD_RUN_SITE_ID/data"
        exit $RETURN_CODE
    fi
    if [ ! -d "$CHILD_RUN_SITE_ID/data/mysql" ]; then
        echo "failed to unzip dbs/$DB_ZIP_NAME.zip to $CHILD_RUN_SITE_ID/data/mysql"
        exit 2
    fi
else
    echo "The data mysql directory already exists"
fi

SYNC_DB_CONTAINER="${CHILD_RUN_SITE_ID}_sync_db"
DB_VOLUME_DIR=$(pwd)/${CHILD_RUN_SITE_ID}/data/mysql
echo "Starting DB container for sync cleanup: $SYNC_DB_CONTAINER" using volume $DB_VOLUME_DIR

docker stop $SYNC_DB_CONTAINER || true
docker rm $SYNC_DB_CONTAINER || true
docker run --name $SYNC_DB_CONTAINER -d -p ${OMRS_DB_PORT}:3306 -v $DB_VOLUME_DIR:/var/lib/mysql mysql:5.6 --character-set-server=utf8 --collation-server=utf8_general_ci --max_allowed_packet=1G
# wait 10 seconds for the containers to start up
ping -w 1000 -c 10 127.0.0.1
echo "Deleting sync tables"
DELETE_SYNC_TABLES_DB_SCRIPT=$(pwd)/rwandaemr-installer/src/main/resources/sql/deleteSyncTables.sql
echo "DELETE_SYNC_TABLES_DB_SCRIPT = $DELETE_SYNC_TABLES_DB_SCRIPT"
mysql -h 127.0.0.1 -P ${OMRS_DB_PORT} -u root --password=password openmrs < $DELETE_SYNC_TABLES_DB_SCRIPT
RETURN_CODE=$?
docker stop $SYNC_DB_CONTAINER || true
docker rm $SYNC_DB_CONTAINER || true
if [[ $RETURN_CODE != 0 ]]; then
    echo "RETURN_CODE when deleting the sync tables: $RETURN_CODE"
  fi

if [ -d "$CHILD_RUN_SITE_ID/distribution" ]; then
  echo "Removing the existing child server distribution"
  rm -rf $CHILD_RUN_SITE_ID/distribution
fi

echo "Copying distribution from the parent"
cp -a $PARENT_RUN_SITE_ID/distribution $CHILD_RUN_SITE_ID/
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "failed to copy distribution from parent"
    exit $RETURN_CODE
fi

echo "Copy openmrs-server docker image from parent"
rm -rf $CHILD_RUN_SITE_ID/docker-compose.yml
cp $PARENT_RUN_SITE_ID/docker-compose.yml $CHILD_RUN_SITE_ID/docker-compose.yml

pushd $CHILD_RUN_SITE_ID
echo "Starting up child server"
docker-compose up -d
popd

echo "OpenMRS is starting up"
# wait 10 seconds for the containers to start up
ping -w 1000 -c 10 127.0.0.1
# Watch for OpenMRS startup message in the logs
echo "Waiting for OpenMRS startup message..."
docker logs --tail 100 $SERVER_CONTAINER 2>&1 | grep -q "INFO: Server startup in"
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

# configure sync child server
PARENT_SERVER_UUID=$(uuidgen)
echo "PARENT_SERVER_UUID = $PARENT_SERVER_UUID"
CHILD_SERVER_UUID=$(uuidgen)
echo "CHILD_SERVER_UUID = $CHILD_SERVER_UUID"

UPDATE_CHILD_SERVER_SETTINGS_SCRIPT=$(pwd)/rwandaemr-installer/src/main/resources/sql/updateChildServerSettings.sql
echo "UPDATE_CHILD_SERVER_SETTINGS_SCRIPT = $UPDATE_CHILD_SERVER_SETTINGS_SCRIPT"
mysql -h 127.0.0.1 -P ${OMRS_DB_PORT} -u root --password=password openmrs -A -e "set @sync_parent_address='$SYNC_PARENT_ADDRESS'; set @sync_parent_user_name='$SYNC_PARENT_USER_NAME'; set @sync_parent_user_password='$SYNC_PARENT__USER_PASSWORD'; set @sync_parent_name='$PARENT_RUN_SITE_ID'; set @sync_parent_uuid='$PARENT_SERVER_UUID'; set @child_server_uuid='$CHILD_SERVER_UUID'; set @child_name='$CHILD_RUN_SITE_ID'; source $UPDATE_CHILD_SERVER_SETTINGS_SCRIPT;"
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "RETURN_CODE when updating child sync server settings: $RETURN_CODE"
fi
echo "Child sync server has been configured"

# read parent DB port from the parent directory .env file
source $PARENT_RUN_SITE_ID/.env
echo "Parent OMRS_DB_PORT: $OMRS_DB_PORT"
UPDATE_PARENT_SERVER_SETTINGS_SCRIPT=$(pwd)/rwandaemr-installer/src/main/resources/sql/updateParentServerSettings.sql
echo "UPDATE_PARENT_SERVER_SETTINGS_SCRIPT = $UPDATE_PARENT_SERVER_SETTINGS_SCRIPT"
mysql -h 127.0.0.1 -P ${OMRS_DB_PORT} -u root --password=password openmrs -A -e "set @sync_parent_name='$PARENT_RUN_SITE_ID'; set @sync_parent_uuid='$PARENT_SERVER_UUID'; set @child_server_uuid='$CHILD_SERVER_UUID'; set @child_name='$CHILD_RUN_SITE_ID'; source $UPDATE_PARENT_SERVER_SETTINGS_SCRIPT;"
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
    echo "RETURN_CODE when updating parent sync server settings: $RETURN_CODE"
fi

echo "Parent sync server has been configured"
