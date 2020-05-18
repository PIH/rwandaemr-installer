#!/bin/bash -eu

## load variables from the env file
source vars

create_base_dir(){
  mkdir -p ${Base_Dir}
}

download_maven_distribution(){
    create_base_dir
    mkdir -p ${Target_Dir}
	  ./download-maven-artifact.sh --groupId=${Group_ID} --artifactId=${Artifact_ID} --version=${Version} --classifier=${Classifier} --type=${Type} --targetDir=${Target_Dir}
	  unzip ${Target_Dir}/${Artifact_ID}-${Version}-${Classifier}.zip
	  mv ${Artifact_ID}-${Version}/* ${Target_Dir}
	  rm -rf ${Artifact_ID}-${Version}
}

download_maven_distribution