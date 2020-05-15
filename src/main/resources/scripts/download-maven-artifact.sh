#!/bin/bash -eu

GROUP_ID=""
ARTIFACT_ID=""
VERSION=""
CLASSIFIER=""
TYPE=""
TARGET_DIR=""
UPDATE="true"

function usage() {
  echo "USAGE:"
  echo "Download a Maven Artifact"
  echo ""
  echo "Input Options"
  echo " --groupId : Used to specify the group ID (eg. --groupId=org.openmrs.distro)"
  echo " --artifactId : Used to specify the artifact ID (eg. --artifactId=rwandaemr-imb-butaro)"
  echo " --version : Used to specify the version (eg. --version=2.0.0-SNAPSHOT)"
  echo " --classifier : Used to specify the classifier (eg. --classifier=distribution)"
  echo " --type : Used to specify the type (eg. --type=zip)"
  echo " --targetDir : Used to specify an existing directory into which the artifact should be downloaded."
  echo " --help : prints this usage information"
  echo ""
  echo "Example"
  echo "  ./download-mvn-artifact.sh -groupId=org.openmrs.distro -artifactId=rwandaemr-installer --version=2.0.0-SNAPSHOT --classifier=installer --type=zip --targetDir=/tmp/omrs"
  echo ""
  echo "  If artifact or targetDir are not supplied, user will be prompted for these values."
}

# Input arguments are retrieved as options to the command
# This is the preferred way to invoke this without requiring user prompts, and only accepts artifact syntax
for i in "$@"
do
case $i in
    --groupId=*)
      GROUP_ID="${i#*=}"
      shift # past argument=value
    ;;
    --artifactId=*)
      ARTIFACT_ID="${i#*=}"
      shift # past argument=value
    ;;
    --version=*)
      VERSION="${i#*=}"
      shift # past argument=value
    ;;
    --classifier=*)
      CLASSIFIER="${i#*=}"
      shift # past argument=value
    ;;
    --type=*)
      TYPE="${i#*=}"
      shift # past argument=value
    ;;
    --targetDir=*)
      TARGET_DIR="${i#*=}"
      shift # past argument=value
    ;;
    --help)
      usage
      exit 0
    ;;
    *)
      usage    # unknown option
      exit 1
    ;;
esac
done

# If no input arguments are supplied, then prompt the user for input values.
# Since this is interactive with the user, break the artifact prompt up into components for easier user
# Add sensible default values to add to ease of use and consistency

if [ -z "$GROUP_ID" ]; then
  read -e -p 'Group ID: ' -i "org.openmrs.distro" GROUP_ID
fi
if [ -z "$ARTIFACT_ID" ]; then
  read -e -p 'Artifact ID: ' -i "rwandaemr-imb-butaro" ARTIFACT_ID
fi
if [ -z "$VERSION" ]; then
  read -e -p 'Version: ' -i "2.0.0-SNAPSHOT" VERSION
fi
if [ -z "$CLASSIFIER" ]; then
  read -e -p 'Classifier: ' -i "distribution" CLASSIFIER
fi
if [ -z "$TYPE" ]; then
  read -e -p 'Type: ' -i "zip" TYPE
fi
if [ -z "$TARGET_DIR" ]; then
  read -e -p 'Target Directory: ' -i "/opt/openmrs/distribution" TARGET_DIR
fi

ARTIFACT="$GROUP_ID:$ARTIFACT_ID:$VERSION:$TYPE:$CLASSIFIER"
ARTIFACT_NAME="$ARTIFACT_ID-$VERSION-$CLASSIFIER.$TYPE"

echo "DOWNLOADING ARTIFACT: $ARTIFACT"
echo "INTO TARGET DIRECTORY: $TARGET_DIR"
echo "AS FILE NAMED: $ARTIFACT_NAME"

# Writing this into a maven settings file tells this script to use the OpenMRS Maven repository as a source of artifacts

MAVEN_SETTINGS_FILE="$TARGET_DIR/maven-settings.xml"

cat > $MAVEN_SETTINGS_FILE << EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings>
  <profiles>
    <profile>
      <repositories>
        <repository>
          <id>openmrs-repo</id>
          <name>OpenMRS Nexus Repository</name>
          <url>http://mavenrepo.openmrs.org/nexus/content/repositories/public</url>
        </repository>
      </repositories>
      <id>openmrs</id>
    </profile>
  </profiles>
  <activeProfiles>
    <activeProfile>openmrs</activeProfile>
  </activeProfiles>
</settings>
EOF

# These Maven commands first download the requested artifact to the local Maven repository (.m2)
# Then copies this artifact from that local repository to the directory of choice
# The -Dmdep.useBaseVersion=true specifies to copy snapshot artifacts with the SNAPSHOT suffix, not the timestamp suffix

mvn dependency:get -U -Dartifact=$ARTIFACT -s $MAVEN_SETTINGS_FILE
mvn dependency:copy -Dartifact=$ARTIFACT -DoutputDirectory=$TARGET_DIR -Dmdep.useBaseVersion=true

# Clean up the generated maven settings file

rm $MAVEN_SETTINGS_FILE
