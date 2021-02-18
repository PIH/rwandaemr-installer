#!/bin/sh
# Mobile Broadband Autoconnect Service script v2.0 alpha by The Fan Club - May 2012
# acts as startup service script for nmcli to autoconnect Mobile Broadband Connections
# NOTE: use the name of the Mobile Connection in the Network Manager as the 'id' 
# USAGE: start|stop|status
#
### BEGIN INIT INFO 
# Provides: mobile-broadband-connect 
# Required-Start: $remote_fs $syslog
# Required-Stop: $remote_fs $syslog
# Should-Start: $network
# Should-Stop: $network
# Default-Start: 3 4 5 
# Default-Stop: 0 1 6 
# Short-Description: Autoconnect 3G GSM
### END INIT INFO

NAME="mobile-broadband-connect"
DESC="Autoconnect 3G/4G GSM USB modem at startup"

test -x $DAEMON || exit 0

case "$1" in
	start)
	   echo "[MBC] *** Starting Mobile Broadband Connection."  
	   while true; do
 	      # Waiting for GSM modem adaptor...
          LC_ALL=C nmcli -t -f TYPE,STATE dev | grep -q "^gsm:disconnected$"
          if [ $? -eq 0 ]; then 	 
	         # now gsm detected, run the script
             echo "[MBC] GSM Modem Detected - attempting auto connect" 
		     nmcli -t con up id MTN_OpenMRS
	         echo "[MBC] GSM Modem connecting ....."
             # we want the script to loop forever and 
             # check if the connection is down
             # but we need to give it a chance to connect or 
             # the modem will attempt to connect in an endless loop so we 
             # give a 30 second break to make sure it is not connected	
	         echo "[MBC] Hopefully connected now... sleeping for 30sec"            
	         sleep 30
	      else
	         # GSM device not detected yet or GMS device already connected - sleep 
	       #  echo "[MBC] MBC still running - sleeping for 10....." 
	         sleep 10
 	      fi
       done
	;;
	stop)
       echo "[MBC] Stopping Mobile Broadband Connection."  
       nmcli -t con down id MTN_OpenMRS
       ps aux | grep "mobile-connection-connect-2.0.sh start" | grep -v grep | awk '{print $2}' | xargs kill -9
       #nmcli -t nm wwan off 
	;;
	status)
       # Check network status with nmcli 
       nmcli -p dev
	;;
	
	*)
	   echo "[MBC] Mobile Broadband Startup Service"
       echo $"Usage: $0 {start|stop|status}"
       exit 1
esac
exit 0
