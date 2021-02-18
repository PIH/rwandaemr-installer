#!/bin/bash
#/usr/bin/bash
#the two expected arguments are file, then text to search for
#use this to search in the run_log for existing md5 output

# ARGS:  FILE TEXT
# RETURN:  FOUND  if text string is found.

if [ -z "$2" ]; then
    exit
fi

if [ -e "$1" ]; then 
    count=`egrep -ic "$2" "$1"`
    echo $count
    if [ $count -gt 0 ]; then
	echo true
        exit
    fi
fi
echo false
