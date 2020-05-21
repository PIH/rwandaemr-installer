#!/bin/bash -eu

Git_Url="https://github.com/PIH/rwandaemr-installer.git"
Temp_Dir="/tmp/rwandaemr"

function installer(){

  #install recommended packages
  apt-get -y install git maven
	
	# remove git dir if exists
	[ -d ${Temp_Dir} ] && rm -rf ${Temp_Dir}
	
	# clone the repo into the temporary directory
	git clone ${Git_Url} ${Temp_Dir}
  cd ${Temp_Dir}

  #will be removed when we merge to master
	git checkout RWA-766-env-setup-scripts
}

########### Dev ennvironment
function dev-env(){
	echo "1"
}

	
########## Test environment
function test-env(){
  echo "Setting up a Test environment"
}
        

########## Production environment
function prod-env(){
        echo "james"
}

### site names
function artifact-name-butaro() {
    sed -i 's/Artifact_ID=.*/Artifact_ID="rwandaemr-imb-butaro"/g' vars
}

function artifact-name-rwinkwavu() {
    sed -i 's/Artifact_ID=.*/Artifact_ID="rwandaemr-imb-rwinkwavu"/g' vars
}

function artifact-name-rwandaemr() {
    sed -i 's/Artifact_ID=.*/Artifact_ID="rwandaemr"/g' vars
}


## versions
function version1() {
  sed -i 's/Version=.*/Version="1.1.0-SNAPSHOT"/g' vars
}

function version2() {
  sed -i 's/Version=.*/Version="2.0.0-SNAPSHOT"/g' vars
}

## Delete
function remove-distribution-dir() {
  [ -d ${Temp_Dir}/distribution ] && rm -rf ${Temp_Dir}/distribution
}

### commands
## Usage
## rwandaemr download installer

case "$1" in
      download)
        installer
        ;;
esac

## Usage
## rwandaemr setup dev-env

case "$1" in	
	setup)
		if [ "$2" == "dev-env" ]; then
			dev-env
		fi

		if [ "$2" == "test-env" -o "$2" == "prod-env" ]; then

      test-env
      cd ${Temp_Dir}/scripts

        if [ "$3" == "butaro" ]; then
          artifact-name-butaro
            if [ "$4" == "v1" ]; then
            version1
            fi
            if [ "$4" == "v2" ]; then
            version2
            fi
        fi

        if [ "$3" == "rwinkwavu" ]; then
          artifact-name-rwinkwavu
            if [ "$4" == "v1" ]; then
            version1
            fi
            if [ "$4" == "v2" ]; then
            version2
            fi
        fi

        if [ "$3" == "rwandaemr" ]; then
          artifact-name-rwandaemr
            if [ "$4" == "v1" ]; then
            version1
            fi
            if [ "$4" == "v2" ]; then
            version2
            fi
        fi

    fi


      source vars
      remove-distribution-dir
      bash install.sh

        ;;
esac