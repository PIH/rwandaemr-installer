#!/bin/bash


## find global_var.sh file, and load global vars
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source $DIR/global_vars_child.sh

INPUTFILE=$1
FOLDER=$2

#make sure the input file is valid
if [ ! -f "$INPUTFILE" ]; then
     echo $DATE 'File' $INPUTFILE 'does not exist. in routine verifyMD5.' >> $ROOT_DIR/compareMD5.error
     echo 'FAILED'
     exit 1
fi


#skip md5 files
if [[ "$INPUTFILE" == *.md5 ]]; then
   echo 'OK'
   exit 1
fi

#if there is not md5 file already for the input file
INPUTFILEMD5=$INPUTFILE'.md5'
if [ ! -f "$INPUTFILEMD5" ]; then
     echo $DATE 'MD5 not found by verify MD5.  This shouldnt happen.' $INPUTFILEMD5  >> $ROOT_DIR/maintenance.log
     echo 'FAILED'
     exit 1
fi

#if the input file has changed, give it an update
if [ -f "$INPUTFILE" ]; then
    cd $FOLDER
    STATUS=`exec md5sum --check < "$INPUTFILEMD5" | grep -o FAILED`
    if [ $STATUS ]; then
        echo 'FAILED'
    fi
    STATUS=`exec md5sum --check < "$INPUTFILEMD5" | grep -o OK`
    if [ $STATUS ]; then
        echo 'OK'
    fi
fi

