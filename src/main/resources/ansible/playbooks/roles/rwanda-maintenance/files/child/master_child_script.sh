#!/bin/bash

#Heres what this needs to do:
# 1. scan all folders for failed md5 matches.  If there's a failure, don't do anything (just log the failure)
# 2. if md5 matches all pan out, check to see if there are any items not already logged in the run_log
# 3. if an item is not in the run_log, then do the UPDATE action.

#TOOLS:  
# verifyMD5.sh compares a file to its md5 file
# previousRunCheck.sh <file> <text> checks for the <text> in the <file>.  Use this to scan the run_log.


## find global_var.sh file, and load global vars
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source $DIR/global_vars_child.sh

## since this script does chmods and chowns, double check that all variables have been set to avoid potential disaster!
[ -z "$DATE" ] && echo "Warning: unset DATE global var, aborting" && exit 1
[ -z "$USER" ] && echo "Warning: unset USER global var, aborting" && exit 1
[ -z "$USER_HOME_DIR" ] && echo "Warning: unset USER_HOME_DIR global var, aborting" && exit 1
[ -z "$ROOT_DIR" ] && echo "Warning: unset ROOT_DIR global var, aborting" && exit 1
[ -z "$TOMCAT_WEBAPP_DIR" ] && echo "Warning: unset TOMCAT_WEBAPP_DIR global var, aborting" && exit 1
[ -z "$TOMCAT_USER" ] && echo "Warning: unset TOMCAT_USER global var, aborting" && exit 1
[ -z "$TOMCAT_SERVICE" ] && echo "Warning: unset TOMCAT_SERVER global var, aborting" && exit 1
[ -z "$OPENMRS_MODULES_DIR" ] && echo "Warning: unset OPENMRS_MODULES_DIR global var, aborting" && exit 1
[ -z "$OPENMRS_RUNTIME_PROPERTIES_FILE" ] && echo "Warning: unset OPENMRS_RUNTIME_PROPERTIES_FILE global var, aborting" && exit 1
[ -z "$OPENMRS_DATABASE_NAME" ] && echo "Warning: unset OPENMRS_DATABASE_NAME global var, aborting" && exit 1
[ -z "$OPENMRS_WEBAPP_NAME" ] && echo "Warning: unset OPENMRS_WEBAPP_NAME global var, aborting" && exit 1

echo ' '  >> $ROOT_DIR/maintenance.log
echo $DATE ' BEGINNING MASTER CHILD SCRIPT '  >> $ROOT_DIR/maintenance.log

########################################################
#### FIRST PASS, LETS LOOK FOR NON-MATCHING MD5 FILES ##
########################################################
## if a local md5 calculation doesn't agree with an md5 sent from the parent, then RUN_UPDATES is set to false, and this script exits. 
## i'm leaving other_files out of the list, because these aren't used in updating the child servers.  I'll leave it to the user to see if the files in other_files are fully propagated (for now)

declare -a FOLDERS=(openmrs_war openmrs_modules trusted_sql)

RUN_UPDATES=true

for FOLDER in "${FOLDERS[@]}"; do
	
	if [ "$(ls -A $ROOT_DIR/$FOLDER)" ]; then
		for FILE in $ROOT_DIR/$FOLDER/* ; do
		   STATUS=`exec $DIR/verifyMD5.sh "$FILE" "$ROOT_DIR/$FOLDER"`
		   if [ "$STATUS" == "FAILED" ]; then
		      RUN_UPDATES=false
		   fi
		done
	fi
done


echo $DATE 'RUN_UPDATES calculated to be' $RUN_UPDATES  >> $ROOT_DIR/maintenance.log

## MIGHT AS WELL ENSURE THAT THE RUN_LOG EXISTS.
## run_log is a changeset that records processed md5s.  If a file's checksum is found in the run_log, the file won't be re-applied to production.		     	

if [ ! -f $DIR/run_log ]; then
 echo 'HERE WE GO' >> $DIR/run_log
 chmod 600 $DIR/run_log
 echo $DATE 'CREATED run_log.' >> $ROOT_DIR/maintenance.log 
fi

###################################################
###  IF CHECKSUMS ALL MATCH, DO STUFF      ########
###################################################
if [ $RUN_UPDATES == true ]; then
  

  #######################################
  ###  WAR file
  ########################################
  # if the folder is not empty
  if [ "$(ls -A $ROOT_DIR/openmrs_war)" ]; then
        for FILE in $ROOT_DIR/openmrs_war/* ; do

		 if [[ "$FILE" == *.war ]]; then
		   ##calculate local md5 and compare with entries in run_log	
		   MD5=`exec $DIR/calculateMD5.sh "$FILE"` 
		   ALREADY_FOUND=`$DIR/previousRunCheck.sh $DIR/run_log "$MD5" | grep -o true`
                   
                   ## if not found in run_log, then its new:  update 
		   if [ "$ALREADY_FOUND" == "true" ]; then
	 		   echo $DATE $FILE 'does not need to be updated.'  >> $ROOT_DIR/maintenance.log
		   else
		       `exec sudo chmod 777 $TOMCAT_WEBAPP_DIR`
		       `exec sudo chmod 777 $TOMCAT_WEBAPP_DIR/*`
		       `exec sudo chown $USER $TOMCAT_WEBAPP_DIR/*.war`

               `exec rm -r "$TOMCAT_WEBAPP_DIR/$OPENMRS_WEBAPP_NAME"  > /dev/null`
		       `exec sudo cp -f "$FILE" "$TOMCAT_WEBAPP_DIR"`

               `exec sudo chown $TOMCAT_USER $TOMCAT_WEBAPP_DIR/*`
               `exec sudo chgrp $TOMCAT_USER $TOMCAT_WEBAPP_DIR/*`
		       `exec sudo chmod 644 $TOMCAT_WEBAPP_DIR/*.war`
		       `exec sudo chmod 755 $TOMCAT_WEBAPP_DIR`
		       echo $MD5 >> $DIR/run_log
		       echo $DATE 'UPDATED' $FILE  >> $ROOT_DIR/maintenance.log
		   fi
		 
		fi

        done
  fi

  ######################################
  ###  modules
  ########################################
  # if the folder is not empty
  if [ "$(ls -A $ROOT_DIR/openmrs_modules)" ]; then
        for FILE in $ROOT_DIR/openmrs_modules/* ; do

            if [[ "$FILE" == *.omod ]]; then
                MD5=`exec $DIR/calculateMD5.sh "$FILE"` 
                ALREADY_FOUND=`$DIR/previousRunCheck.sh $DIR/run_log "$MD5" | grep -o true`
                if [ "$ALREADY_FOUND" == "true" ]; then
		    echo $DATE $FILE 'does not need to be updated.'  >> $ROOT_DIR/maintenance.log
                else
                    #remove module with the same name
                    `exec sudo chmod 777 $OPENMRS_MODULES_DIR`
                    `exec sudo chown $USER $OPENMRS_MODULES_DIR/*`
                    `exec sudo chmod 777 $OPENMRS_MODULES_DIR/*`

                     FILE_ROOT=`exec echo "$FILE" | awk 'match($0,"-"){print substr($0,RLENGTH,RSTART-1)}' | awk 'match($0,"/..*../"){print substr($0,RLENGTH+1)}'`
                    `exec rm "$OPENMRS_MODULES_DIR/$FILE_ROOT-"*  > /dev/null`
                    #copy in the new file
                    `exec sudo cp -f "$FILE" "$OPENMRS_MODULES_DIR"`

                    `exec sudo chown $TOMCAT_USER $OPENMRS_MODULES_DIR/*`
                    `exec sudo chgrp $TOMCAT_USER $OPENMRS_MODULES_DIR/*`
                    `exec sudo chmod 644 $OPENMRS_MODULES_DIR/*`
                    `exec sudo chmod 755 $OPENMRS_MODULES_DIR`
                    echo $MD5 >> $DIR/run_log
                    echo $DATE 'UPDATED' $FILE  >> $ROOT_DIR/maintenance.log
                fi
             fi
        
        done
  fi

  #remove modules that aren't in drop folder
  
  for FILE in $OPENMRS_MODULES_DIR/* ; do
    if [[ "$FILE" == *.omod ]]; then
       MODULE_FILE_ROOT=`exec echo "$FILE" | awk 'match($0,"-"){print substr($0,RLENGTH,RSTART-1)}' | awk 'match($0,"/..*../"){print substr($0,RLENGTH+1)}'`
       if [ "$MODULE_FILE_ROOT" ]; then
           #FIND A MATCH IN THE DROP FOLDER:
           if [ "$(ls -A $ROOT_DIR/openmrs_modules/* | grep "/$MODULE_FILE_ROOT-")" ]; then
           	echo $DATE $MODULE_FILE_ROOT 'found in staging folder' >> $ROOT_DIR/maintenance.log
           else
               `exec sudo chmod 777 $OPENMRS_MODULES_DIR`
               `exec sudo chmod 777 $OPENMRS_MODULES_DIR/*`
               `exec rm "$FILE"  > /dev/null`
               `exec sudo chmod 644 $OPENMRS_MODULES_DIR/*`
               `exec sudo chmod 755 $OPENMRS_MODULES_DIR`
               echo $DATE $MODULE_FILE_ROOT 'not found in staging folder.  REMOVING OMOD FROM PRODUCTION.'>> $ROOT_DIR/maintenance.log
           fi
       fi
    fi
  done


  #######################################
  ###  trusted_sql
  ########################################
  if [ "$(ls -A $ROOT_DIR/trusted_sql)" ]; then
        for FILE in $ROOT_DIR/trusted_sql/* ; do
          
         # if the file being examined is not itself an md5
         if [[ "$FILE" == *.md5 ]]; then
          	echo 'skipping md5' > /dev/null
         else 
                MD5=`exec $DIR/calculateMD5.sh "$FILE"` 
                ALREADY_FOUND=`$DIR/previousRunCheck.sh $DIR/run_log "$MD5" | grep -o true`
                if [ "$ALREADY_FOUND" == "true" ]; then
		    echo $DATE $FILE 'does not need to be updated.'  >> $ROOT_DIR/maintenance.log
                else
		    ##  THIS READS IN THE OPENMRS RUNTIME PROPERTIES FILE FOR MYSQL CONNECTION STUFF	
                    echo -e "#!/bin/bash\n" >> $DIR/connect.tmp
                    `exec sudo chmod 644 "$OPENMRS_RUNTIME_PROPERTIES_FILE"`
                    while read line; do
                        STATUS=`echo $line | grep -o connection.password`
                        if [ $STATUS ]; then 
			  echo -e "$line" >> $DIR/connect.tmp
                        fi
                        STATUS=`echo $line | grep -o connection.username`
                        if [ $STATUS ]; then 
			  echo -e "$line" >> $DIR/connect.tmp
                        fi
		    done < "$OPENMRS_RUNTIME_PROPERTIES_FILE"
                    `exec sudo chmod 600 "$OPENMRS_RUNTIME_PROPERTIES_FILE"`
		    #this crap clears windows line carriages, builds .sh file that sets mysql username and passwd
                    `exec /usr/bin/dos2unix $DIR/connect.tmp`
                    `exec sed 's/connection.username=/MYSQL_USERNAME="/g' "$DIR/connect.tmp" > "$DIR/connect1.tmp"`
                    `exec sed 's/connection.password=/MYSQL_PASSWORD="/g' "$DIR/connect1.tmp" > "$DIR/connect2.tmp"`
                    #add end quotes to username and password lines
                    `exec sed '/^MYSQL_USERNAME=/ s/$/"/' "$DIR/connect2.tmp" > "$DIR/connect3.tmp"`
                    `exec sed '/^MYSQL_PASSWORD=/ s/$/"/' "$DIR/connect3.tmp" > "$DIR/connection.sh"`
                    source $DIR/connection.sh
                    rm $DIR/connect*
                    RESULT=`exec /usr/bin/mysql -u"$MYSQL_USERNAME" -p"$MYSQL_PASSWORD" $OPENMRS_DATABASE_NAME < "$FILE"`
                    echo $MD5 >> $DIR/run_log
                    echo $DATE 'EXECUTED' $FILE 'WITH CONTENTS:' >> $ROOT_DIR/maintenance.log
                    echo `exec cat "$FILE"`  >> $ROOT_DIR/maintenance.log
                    echo 'WITH RESULT ' >> $ROOT_DIR/maintenance.log
                    echo $RESULT >> $ROOT_DIR/maintenance.log
                fi
         fi
        done
  fi
    echo $DATE ' Restarting Tomcat'  >> $ROOT_DIR/maintenance.log
    `exec sudo service "$TOMCAT_SERVICE" restart`
  ## NOTE:  other_files require no action

fi
echo $DATE ' ENDING MASTER CHILD SCRIPT '  >> $ROOT_DIR/maintenance.log
exit 0


## NOTE:  it seems like openmrs.war and modules work fine if owned by someone else, as long as their permissions are 644  (read/write, read, read)




