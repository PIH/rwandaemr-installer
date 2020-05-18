#!/bin/bash -eu

SITE_NAME=""
RUN_ID=""

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

echo "Creating directory for this run"
mkdir -p $RUN_ID

DB_ZIP_NAME="$SITE_NAME-anonymized"

if [ ! -f "dbs/$DB_ZIP_NAME.zip" ]; then
  echo "Downloading DB zip"
  wget --user $DB_REPO_USER --password $DB_REPO_PASSWORD -O dbs/$DB_ZIP_NAME.zip "$DB_REPO_BASE_URL/$DB_ZIP_NAME/data.zip"
else
  echo "DB zip already downloaded"
fi

if [ ! -d "$RUN_ID/data/mysql" ]; then
  echo "Extracting DB from zip"
  mkdir -p $RUN_ID/data
  unzip dbs/$DB_ZIP_NAME.zip -d $RUN_ID/data
  mv $RUN_ID/data/data $RUN_ID/data/mysql
else
  echo "DB zip already extracted"
fi

DB_VOLUME_DIR=$(pwd)/$RUN_ID/data/mysql

echo "Starting MySQL container using DB"

docker stop $RUN_ID || true
docker rm $RUN_ID || true
docker run --name $RUN_ID -d -p 3308:3306 -v $DB_VOLUME_DIR:/var/lib/mysql mysql:5.6 --character-set-server=utf8 --collation-server=utf8_unicode_ci --max_allowed_packet=1G

if [ ! -d "$RUN_ID/openmrs-module-rwandaemr" ]; then
  echo "Downloading Migration code"
  pushd $RUN_ID
  git clone https://github.com/PIH/openmrs-module-rwandaemr
  popd
else
  echo "Updating Migration code"
  pushd $RUN_ID/openmrs-module-rwandaemr
  git pull --rebase
  popd
fi

echo "Executing the Migration"
pushd $RUN_ID/openmrs-module-rwandaemr/migration
mvn liquibase:update -Ddb_port=3308 -Ddb_user=root -Ddb_password=password
popd

docker stop $RUN_ID
docker rm $RUN_ID

if [ ! -d "$RUN_ID/rwandaemr-installer" ]; then
  echo "Downloading Installer code"
  pushd $RUN_ID
  git clone https://github.com/PIH/rwandaemr-installer
  popd
else
  echo "Updating Installer code"
  pushd $RUN_ID/rwandaemr-installer
  git pull --rebase
  popd
fi

if [ ! -d "$RUN_ID/distribution" ]; then
  echo "Downloading distribution artifact"
  mkdir -p $RUN_ID/distribution
  ./$RUN_ID/rwandaemr-installer/src/main/resources/scripts/download-maven-artifact.sh --groupId=org.openmrs.distro --artifactId=rwandaemr-imb-$SITE_NAME --version=2.0.0-SNAPSHOT --classifier=distribution --type=zip --targetDir=$RUN_ID
  unzip $RUN_ID/rwandaemr-imb-$SITE_NAME-2.0.0-SNAPSHOT-distribution.zip -d $RUN_ID/distribution
  mv $RUN_ID/distribution/rwandaemr-imb-$SITE_NAME-2.0.0-SNAPSHOT/* $RUN_ID/distribution/
  rm -fR $RUN_ID/distribution/rwandaemr-imb-$SITE_NAME-2.0.0-SNAPSHOT/
else
  echo "Distribution already downloaded"
fi

echo "Updating openmrs-server docker image"
docker pull partnersinhealth/openmrs-server:latest

echo "Starting up OpenMRS distribution to run through the upgrade"

pushd $RUN_ID
cp ./rwandaemr-installer/src/main/resources/docker/docker-compose.yml .
docker-compose up -d
popd

SERVER_CONTAINER="${RUN_ID}_server_1"
docker logs -f $SERVER_CONTAINER

