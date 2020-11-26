#!/bin/bash

# The purpose of this script is to execute the migrations needed to upgrade the rwanda from 1.9 to 2.3
# This involves the following steps:
#  IN  = A mysqldump file that represents the latest backup of a production database from MySQL 5.6 and OpenMRS 1.9.9
#  IN  = A directory that will be used store execution files and resulting migrated data artifacts for the migration run
#  1. Execute a series of "pre-migration" database updates that allow the OpenMRS upgrade process to proceed without errors
#  2. Execute the core OpenMRS upgrade process against this database
#  3. Execute a series of "post-migration" database updates that are needed to apply various configurations and updates
#  4. Execute a series of core MySQL upgrades in order to convert the DB to MySQL 8.0 compatibility
#  OUT = A directory with a upgraded data artifacts supports MySQL 8.0 and OpenMRS 2.3.3

# Required libraries:  docker, pv, maven, java

set -uo pipefail
IFS=$'\n\t'

function usage() {
  echo "USAGE:"
  echo "execute-2x-migration.sh --inputSqlFile=/path/to/sql/file.sql --migrationDir=/path/to/migration/dir"
}

RETURN_CODE=0

INPUT_SQL_FILE=""
MIGRATION_DIR=""
HOST_EXECUTION_DIR=$(pwd)

for i in "$@"
do
case $i in
    --inputSqlFile=*)
      INPUT_SQL_FILE="${i#*=}"
      shift # past argument=value
    ;;
    --migrationDir=*)
      MIGRATION_DIR="${i#*=}"
      shift # past argument=value
    ;;
    *)
      usage    # unknown option
      exit 1
    ;;
esac
done

if [ ! -f $INPUT_SQL_FILE ]; then
  echo "You must specify a valid input SQL file"
  usage
  exit 1
fi

if [ -d $MIGRATION_DIR ]; then
  echo "Migration directory already exists."
  #usage  TODO: Uncomment if we want to enforce the use of a new directory.
  #exit 1
fi

echo "$(date): Migrating to 2.x from $INPUT_SQL_FILE"
echo "$(date): Writing output to $MIGRATION_DIR"
mkdir -p $MIGRATION_DIR

function remove_all_docker_artifacts() {
  docker stop $MYSQL_CONTAINER || true
  docker rm $MYSQL_CONTAINER || true
  docker network rm $DOCKER_NETWORK || true
}

function create_docker_network() {
    echo "$(date): Creating a Docker Network"
    docker network create $DOCKER_NETWORK
    echo "$(date): Docker Network Created"
}

function start_mysql_container() {
  MYSQL_VERSION=${1:-5.6}
  echo "$(date): Creating a MySQL $MYSQL_VERSION container"
  docker run --name $MYSQL_CONTAINER --network $DOCKER_NETWORK -d -p 3306:3306 \
    -v $MYSQL_DATA_DIR:/var/lib/mysql \
    -v $HOST_EXECUTION_DIR:/scripts \
    -e MYSQL_ROOT_PASSWORD=password \
    -e MYSQL_USER=openmrs \
    -e MYSQL_PASSWORD=openmrs \
    -e MYSQL_DATABASE=openmrs \
    mysql:$MYSQL_VERSION --character-set-server=utf8 --collation-server=utf8_general_ci --max_allowed_packet=1G
  echo "$(date): Container created. Waiting 15 seconds..."
  sleep 15
}

function remove_mysql_container() {
  echo "$(date): Stopping and removing MySQL container"
  docker stop $MYSQL_CONTAINER || true
  docker rm $MYSQL_CONTAINER || true
  echo "$(date): MySQL container removed"
}

# Import the starting sql file into the mysql container.  This uses pv to monitor progress, as this can take over an hour
function import_initial_db() {
  echo "$(date): Importing the provided database backup"
  pv $INPUT_SQL_FILE | docker exec -i $MYSQL_CONTAINER sh -c 'exec mysql -u openmrs -popenmrs openmrs'
  echo "$(date): Import complete"
}

# Zip up the MySQL data directory
# This expects a single argument which is the filename for the target zip.  It uses pv to monitor progress, as this can take around 10 minutes.
function archive_data_dir() {
  # Back-up the data directory
  ARCHIVE_FILE_NAME=$1
  echo "$(date): Archiving data dir to $ARCHIVE_FILE_NAME"
  sudo zip -r $MIGRATION_DIR/$ARCHIVE_FILE_NAME $MYSQL_DATA_DIR/ 2>&1 | pv -lbp -s $(ls -Rl1 $MYSQL_DATA_DIR/ | egrep -c '^[-/]') > /dev/null
  echo "$(date): Data dir successfully archived to: $ARCHIVE_FILE_NAME"
}

function ensure_db_is_utf8() {
  echo "$(date): Updating all tables to utf8"
  docker exec $MYSQL_CONTAINER /scripts/change-db-to-utf8.sh openmrs password
  echo "$(date): Done updating to utf8"
}

function run_migrations() {
  CHANGELOG_DIR=${1:pre-2x-upgrade}
  echo "$(date): Running migrations: $CHANGELOG_DIR"
  mvn -f ../../../../pom.xml liquibase:update -Ddb_port=3306 -Ddb_user=openmrs -Ddb_password=openmrs -Dchangelog_dir=$CHANGELOG_DIR
  echo "$(date): Migrations completed in: $CHANGELOG_DIR"
}

function download_distribution() {
  echo "$(date): Downloading distribution"
  ./download-maven-artifact.sh \
    --groupId=org.openmrs.distro \
    --artifactId=rwandaemr-imb \
    --version=2.0.0-SNAPSHOT \
    --classifier=distribution \
    --type=zip \
    --targetDir=$MIGRATION_DIR
  unzip $MIGRATION_DIR/rwandaemr-imb-2.0.0-SNAPSHOT-distribution.zip -d $MIGRATION_DIR
  echo "$(date): Distribution downloaded and extracted"
}

function ensure_liquibase_is_not_locked() {
  echo "$(date): Ensuring liquibase is not locked"
  docker exec -i $MYSQL_CONTAINER sh -c 'exec mysql -u openmrs -popenmrs openmrs -e "UPDATE liquibasechangeloglock set locked=0;"'
  echo "$(date): Liquibasechangeloglock updated"
}

function perform_openmrs_core_updates() {
  echo "$(date): Starting OpenMRS Server to execute core updates"
  docker run --name $OPENMRS_CONTAINER --network $DOCKER_NETWORK -d -p 8080:8080 \
    -v $MIGRATION_DIR/rwandaemr-imb-2.0.0-SNAPSHOT:/openmrs/distribution \
    -v $HOST_EXECUTION_DIR:/scripts \
    -e OMRS_CONFIG_CONNECTION_SERVER="$MYSQL_CONTAINER" \
    -e OMRS_CONFIG_CONNECTION_USERNAME="openmrs" \
    -e OMRS_CONFIG_CONNECTION_PASSWORD="openmrs" \
    -e OMRS_CONFIG_CONNECTION_EXTRA_ARGS="&zeroDateTimeBehavior=convertToNull" \
    -e OMRS_CONFIG_AUTO_UPDATE_DATABASE="true" \
    partnersinhealth/openmrs-server:latest
  echo "$(date): OpenMRS server docker container started to perform core updates.  Check docker logs for status..."
  sleep 15
  docker logs -f --tail 1000 $OPENMRS_CONTAINER 2>&1 | grep -q "liquibase: Successfully released change log lock"
  RETURN_CODE=$?
  if [[ $RETURN_CODE != 0 ]]; then
    echo "$(date): Core updates have finished."
  fi
  docker logs $OPENMRS_CONTAINER
  docker stop $OPENMRS_CONTAINER
  docker rm $OPENMRS_CONTAINER
}

function run_mysql_upgrade() {
  docker exec -it $MYSQL_CONTAINER mysql_upgrade -uroot -ppassword
}

DOCKER_NETWORK="rwandaemr-upgrade-network"
MYSQL_CONTAINER="rwandaemr-upgrade-mysql"
OPENMRS_CONTAINER="rwandaemr-upgrade-openmrs"
MYSQL_DATA_DIR=$MIGRATION_DIR/data

# Remove all existing docker artifacts
#remove_all_docker_artifacts

# Create a docker network to use to communicate between DB and Server containers as needed
#create_docker_network

# Create a docker mysql 5.6 container to use for the initial upgrade
#start_mysql_container "5.6"

# Import the supplied database into the MySQL container and ensure all tables are configured as utf8
#import_initial_db
#archive_data_dir "initial-import-data.zip"

# Perform pre-migrations
#ensure_db_is_utf8
#run_migrations "pre-2x-upgrade"
#archive_data_dir "pre-2x-upgrade-completed-data.zip" # NOTE, these are around 4-5 GB each, and take 10+ minutes to zip, so only run if needed

# Perform OpenMRS platform upgrade
#download_distribution
#ensure_liquibase_is_not_locked
#perform_openmrs_core_updates
#archive_data_dir "core-updates-completed-data.zip"

# Perform post-migrations
#run_migrations "post-2x-upgrade"
#archive_data_dir "post-2x-upgrade-completed-data.zip"

# Upgrade to MySQL 5.7
#remove_mysql_container
#start_mysql_container "5.7"
#run_mysql_upgrade

# Upgrade to MySQL 5.8
#remove_mysql_container
#start_mysql_container "8.0"
#run_mysql_upgrade

#archive_data_dir "migrated-into-mysql-8.zip"

# TODO: considerations
# clean out db early of more stuff:  sync_records, hl7_archives, etc.
