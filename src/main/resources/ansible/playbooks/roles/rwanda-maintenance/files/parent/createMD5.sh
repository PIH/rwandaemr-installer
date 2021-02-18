#!/bin/bash -e
# this script creates MD5 files


## find global_var.sh file, and load global vars
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source $DIR/global_vars.sh

#make sure the input file is valid
INPUTFILE=$1
if [ ! -f "$INPUTFILE" ]; then
     echo $DATE 'File' $INPUTFILE 'does not exist. in routine createMD5.sh' >> $ROOT_DIR/createMD5.error
     exit 1
else
     /usr/bin/md5sum "$INPUTFILE" > "$INPUTFILE.md5"
     echo $DATE 'md5 created for ' $INPUTFILE 'by createMD5.sh routine.' >> $ROOT_DIR/maintenance.log
fi
chmod 777 "$INPUTFILE.md5"

