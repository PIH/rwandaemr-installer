#!/bin/bash

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

download_maven_installer(){
	  create_base_dir
	  Target_Dir=${Base_Dir}/${Installer_Dir}
	  Version=${Installer_Version}
	  Classifier=${Installer_classifier}
	  Artifact_ID=${Installer_Artifact_ID}
	  mkdir -p ${Target_Dir}
	  ./download-maven-artifact.sh --groupId=${Group_ID} --artifactId=${Artifact_ID} --version=${Version} --classifier=${Classifier} --type=${Type} --targetDir=${Target_Dir}
	  unzip ${Target_Dir}/${Artifact_ID}-${Version}-${Classifier}.zip
	  mv ${Artifact_ID}-${Version}/* ${Target_Dir}
	  rm -rf ${Target_Dir}/${Artifact_ID}-${Version}-${Classifier}.zip
}

#download_maven_distribution
download_maven_installer
