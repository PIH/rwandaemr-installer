#!/bin/bash -e
#This is for the parent server.  This does three things:
#1.  checks to see that the passed in file is a valid file
#2.  if the passed in file does not yet have an md5 file, it creates one.
#3.  if the passed in file has an md5 file, but the md5 sums don't agree, recreates the md5 file for the file.

#WARNING:  THIS SHOULD NEVER BE CALLED ON A CHILD SERVER

#CORRECT USAGE:  this should be called by a master script that calls this for each file in all drop-box folders. 



## find global_var.sh file, and load global vars
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source $DIR/global_vars.sh


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
#if there is not md5 file already for the input file
INPUTFILEMD5=$INPUTFILE'.md5'
if [ ! -f "$INPUTFILEMD5" ]; then
     $DIR/createMD5.sh "$INPUTFILE"
     echo $DATE 'MD5 not found.  Creating new md5 file' $INPUTFILEMD5  >> $ROOT_DIR/maintenance.log
     exit 1
fi

#if the input file has changed, give it an update
if [ -f "$INPUTFILE" ]; then
    STATUS=`exec md5sum --check < "$INPUTFILEMD5" | grep -o FAILED`
    if [ $STATUS ]; then
        #the file has been updated
        rm "$INPUTFILEMD5"
        echo $DATE 'Md5 found but has changed for' $INPUTFILE'.  Removing the old md5, and calling createMD5 to recreate.'  >> $ROOT_DIR/maintenance.log
        $DIR/createMD5.sh "$INPUTFILE"
    fi
fi
