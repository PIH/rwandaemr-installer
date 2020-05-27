#!/bin/bash -eu

## load variables from the env file
source .env

create_data_dir(){
  mkdir -p ${Base_Dir}/${Data_Dir}
}

download_maven_distribution(){
# Ensure target dir is empty if it exists.
    rm -rf ${Target_Dir}/*
# Create target dir if it doesn't exist
    mkdir -p ${Target_Dir}
	  ./download-maven-artifact.sh --groupId=${Group_ID} --artifactId=${Artifact_ID} --version=${Version} --classifier=${Classifier} --type=${Type} --targetDir=${Target_Dir}
	  unzip ${Target_Dir}/${Artifact_ID}-${Version}-${Classifier}.zip
	  rm -rf ${Target_Dir}/${Artifact_ID}-${Version}-${Classifier}.zip
	  mv ${Artifact_ID}-${Version}/* ${Target_Dir}
	  rm -rf ${Artifact_ID}-${Version}
}

set_image_version(){
    bash set-image-version.sh
}

set_ports(){
    bash set-ports.sh
}

create_data_dir
download_maven_distribution
set_image_version
set_ports