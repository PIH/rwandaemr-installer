#!/bin/bash

## find global_var.sh file, and load global vars
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source $DIR/global_vars_child.sh



#make sure the input file is valid
INPUTFILE=$1
if [ ! -f "$INPUTFILE" ]; then
     echo $DATE 'File' $INPUTFILE 'does not exist. in routine compareMD5.' >> $ROOT_DIR/compareMD5.error
     exit 1
fi

# skip md5 files
if [[ "$INPUTFILE" == *.md5 ]]; then
   exit 1
fi


OUT=`exec /usr/bin/md5sum "$INPUTFILE"`
echo -ne $OUT

