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

echo "Got input arguments:"
echo "SITE NAME: ${SITE_NAME}"
echo "VERSION: ${VERSION}"
echo "RUN ID: $RUN_ID"
echo "OMRS_DB_PORT: $OMRS_DB_PORT"
echo "OMRS_SERVER_PORT: $OMRS_SERVER_PORT"
echo "RECREATE: ${RECREATE}"

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
  DISTRIBUTION_ARTIFACT_ID="rwandaemr-imb-$SITE_NAME"
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
  rm -fR $RUN_SITE_ID
fi

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
fi

echo "Updating Installer code"
pushd $RUN_SITE_ID/rwandaemr-installer
git pull --rebase
RETURN_CODE=$?
if [[ $RETURN_CODE != 0 ]]; then
  echo "failed to pull the latest installer code from https://github.com/PIH/rwandaemr-installer"
  exit $RETURN_CODE
fi
popd

echo "Updating DB to utf8 and utf8_general_ci encoding and ensure liquibase is not locked"
DB_UPDATE_CONTAINER="${RUN_SITE_ID}_db_update_db"
DB_UPDATE_DATA_DIR=$(pwd)/${RUN_SITE_ID}/data/mysql
DB_UPDATE_SCRIPT_DIR=$(pwd)/${RUN_SITE_ID}/rwandaemr-installer/src/main/resources/scripts
docker stop $DB_UPDATE_CONTAINER || true
docker rm $DB_UPDATE_CONTAINER || true
docker run --name $DB_UPDATE_CONTAINER -d -p ${OMRS_DB_PORT}:3306 -v $DB_UPDATE_DATA_DIR:/var/lib/mysql -v $DB_UPDATE_SCRIPT_DIR:/scripts mysql:5.6 --character-set-server=utf8 --collation-server=utf8_general_ci --max_allowed_packet=1G
sleep 5
docker exec $DB_UPDATE_CONTAINER /scripts/change-db-to-utf8.sh openmrs password
docker exec -i $DB_UPDATE_CONTAINER sh -c 'exec mysql -u root -ppassword openmrs -e "UPDATE liquibasechangeloglock set locked=0;"'
RETURN_CODE=$?
docker stop $DB_UPDATE_CONTAINER || true
docker rm $DB_UPDATE_CONTAINER || true
if [[ $RETURN_CODE != 0 ]]; then
  echo "Failed to update database character set and collation"
  exit $RETURN_CODE
fi

if [ -d "$RUN_SITE_ID/distribution" ]; then
  echo "Removing the existing distribution"
  rm -rf $RUN_SITE_ID/distribution
fi
echo "Downloading distribution artifact"
mkdir -p $RUN_SITE_ID/distribution
./$RUN_SITE_ID/rwandaemr-installer/src/main/resources/scripts/download-maven-artifact.sh --groupId=org.openmrs.distro --artifactId=$DISTRIBUTION_ARTIFACT_ID --version=$DISTRIBUTION_VERSION --classifier=distribution --type=zip --targetDir=$RUN_SITE_ID
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

echo "Looking for pre-upgrade migrations"
if [ ! -z "$PRE_MIGRATIONS" ]; then

  echo "Found migration file: $PRE_MIGRATIONS"

  MIGRATION_CONTAINER="${RUN_SITE_ID}_migration_db"
  DB_VOLUME_DIR=$(pwd)/${RUN_SITE_ID}/data/mysql
  echo "Starting DB container for migration: $MIGRATION_CONTAINER" using volume $DB_VOLUME_DIR

  docker stop $MIGRATION_CONTAINER || true
  docker rm $MIGRATION_CONTAINER || true
  docker run --name $MIGRATION_CONTAINER -d -p ${OMRS_DB_PORT}:3306 -v $DB_VOLUME_DIR:/var/lib/mysql mysql:5.6 --character-set-server=utf8 --collation-server=utf8_general_ci --max_allowed_packet=1G

  echo "Executing pre-upgrade migrations"

  pushd $RUN_SITE_ID/rwandaemr-installer
  mvn liquibase:update -Ddb_port=$OMRS_DB_PORT -Ddb_user=root -Ddb_password=password
  RETURN_CODE=$?
  docker stop $MIGRATION_CONTAINER || true
  docker rm $MIGRATION_CONTAINER || true
  if [[ $RETURN_CODE != 0 ]]; then
    echo "Failed to run liquibase pre-upgrade migrations"
    exit $RETURN_CODE
  fi
  popd

  echo "Pre-upgrade migrations completed"
fi

echo "Starting up $DISTRIBUTION_NAME"

pushd $RUN_SITE_ID
cp ./rwandaemr-installer/src/main/resources/docker/$DOCKER_COMPOSE_FILE ./docker-compose.yml
if [[ "$RECREATE" == "true" ]]; then
  docker-compose down -v || true
fi
docker-compose up -d
popd

echo "OpenMRS is starting up"
# wait 10 seconds for the containers to start up
ping -w 1000 -c 10 127.0.0.1

# If there are post-migration updates, perform these after core liquibase updates have finished
if [ ! -z "$POST_MIGRATIONS" ]; then
  echo "Waiting for core updates to complete before running post-upgrade migrations: $POST_MIGRATIONS"
  docker logs -f --tail 1000 $SERVER_CONTAINER 2>&1 | grep -q "liquibase: Successfully released change log lock"
  RETURN_CODE=$?
  if [[ $RETURN_CODE != 0 ]]; then
    echo "Core liquibase updates have finished, executing post-upgrade migrations"

    echo "Executing post-upgrade migrations"

    pushd $RUN_SITE_ID/rwandaemr-installer
    mvn liquibase:update -Ddb_port=$OMRS_DB_PORT -Ddb_user=root -Ddb_password=password -Dchangelog_dir=post-2x-upgrade
    RETURN_CODE=$?
    if [[ $RETURN_CODE != 0 ]]; then
      echo "Failed to run liquibase post-upgrade migrations"
      exit $RETURN_CODE
    fi
    popd

    echo "Post-upgrade migrations completed"
  fi
fi


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
