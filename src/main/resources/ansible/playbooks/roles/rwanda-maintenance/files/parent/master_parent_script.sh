#!/bin/bash
# this file should be scheduled to run a couple times per day.  it calculates server md5s, and then manages propagating files to the child servers.
# usage:  if you run this file with no arguments, it will run against all servers listed in the global_vars.sh file.
# however, if you specify servernames as arguments, this will only propagate to those servers.  For example, ./master_parent_script.sh XXX.pih-em.org will only run against XXX.pih-emr.org


## find global_var.sh file, and load global vars
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source $DIR/global_vars.sh

## since this script does chmods and chowns, double check that all variables have been set to avoid potential disaster!
[ -z "$DATE" ] && echo "Warning: unset DATE global var, aborting" && exit 1
[ -z "$USER" ] && echo "Warning: unset USER global var, aborting" && exit 1
[ -z "$USER_HOME_DIR" ] && echo "Warning: unset USER_HOME_DIR global var, aborting" && exit 1
[ -z "$ROOT_DIR" ] && echo "Warning: unset ROOT_DIR global var, aborting" && exit 1
[ -z "$SERVER_LIST" ] && echo "Warning: unset SERVER_LIST global var, aborting" && exit 1

echo ' '  >> $ROOT_DIR/maintenance.log
echo $DATE ' BEGINNING MASTER PARENT SCRIPT '  >> $ROOT_DIR/maintenance.log
echo $DATE 'Running compareAndCreateMD5 on all drop folders'  >> $ROOT_DIR/maintenance.log


###########################
# FILE PERMISSIONS       ##
###########################

# NOTE:  here's what you need in your sudoers file for the $USER
# <<USER>> ALL=NOPASSWD: /bin/chown,/bin/chmod,/bin/cp    (replace <<USER>> with the real user)
##  chmod notes:  3 digits are (owner)(group)(everyone else), read=4, write=2, execute=1

sudo chown -R $USER $ROOT_DIR
sudo chmod -R 776 $ROOT_DIR

############################
#### GENERATING MD5 FILES:  LOOPS OVER ALL DROP FOLDERS AND CALCULATES MD5 FILES ##
############################

declare -a FOLDERS=(openmrs_war openmrs_modules trusted_sql other_files)
for FOLDER in "${FOLDERS[@]}"; do
       if [ "$(ls -A $ROOT_DIR/$FOLDER)" ]; then
		for FILE in $ROOT_DIR/$FOLDER/* ; do
  			 $DIR/compareAndCreateMD5.sh "$FILE"
		done
	fi
done


#####################################
#### HERE'S THE RSYNC BLOCK #########
#####################################
##  NOTE:  BatchMode on ssh causes automatic failure rather than getting a password prompt if auto ssh login isn't set up

## modify server list from all servers to just servers passed as arguments, if there are arguments
if [ $# -gt 0 ]; then
 SERVER_LIST="$@"
fi

for SERVER in $SERVER_LIST ; do

	## send md5 files first
	echo $DATE 'Starting rsync for all md5 files.  ' $SERVER  >> $ROOT_DIR/maintenance.log
	/usr/bin/rsync -arvzOE --delete-before --include '*/' --include '*.md5' --exclude '*' --timeout 500 --partial -e 'ssh -oBatchMode=yes' $ROOT_DIR/ $SERVER:$ROOT_DIR/ >> $ROOT_DIR/maintenance.log
	echo $DATE 'Finished rsync for all md5 files.  ' $SERVER  >> $ROOT_DIR/maintenance.log
      
        ##then, send regular files.
	echo $DATE 'Running rsync on all regular files.  ' $SERVER  >> $ROOT_DIR/maintenance.log
	/usr/bin/rsync -arvzOE --delete-before --include '*/' --include '*.war' --include '*.omod' --include '*.sql' --exclude '*' --timeout 500 --partial -e 'ssh -oBatchMode=yes' $ROOT_DIR/ $SERVER:$ROOT_DIR/ >> $ROOT_DIR/maintenance.log
	/usr/bin/rsync -arvzOE --delete-before --exclude '*.md5' --timeout 500 --partial -e 'ssh -oBatchMode=yes' $ROOT_DIR/other_files/ $SERVER:$ROOT_DIR/other_files/ >> $ROOT_DIR/maintenance.log
 
        ## get the external logs
        /usr/bin/rsync -arvzOE --timeout 500 --partial -e 'ssh -oBatchMode=yes' $SERVER:$ROOT_DIR/maintenance.log $ROOT_DIR/maintenance_$SERVER.log >> $ROOT_DIR/maintenance.log
	echo $DATE 'Finished rsync on all regular files.  ' $SERVER  >> $ROOT_DIR/maintenance.log
	
	##this updates the child server's master scripts according to the ../tools/child/master_child_script.sh on the parent
        /usr/bin/rsync -avz --timeout 500 --partial -e 'ssh -oBatchMode=yes' $ROOT_DIR/tools/child/master_child_script.sh $SERVER:$ROOT_DIR/tools/child/master_child_script.sh >> $ROOT_DIR/maintenance.log
        echo $DATE 'Finished rsync on master_child_script.sh.  ' $SERVER  >> $ROOT_DIR/maintenance.log

done

echo $DATE ' ENDING MASTER PARENT SCRIPT '  >> $ROOT_DIR/maintenance.log
echo ' '  >> $ROOT_DIR/maintenance.log

exit 0

