#!/bin/sh 
/sbin/route delete 10.64.64.64 ppp0 
/sbin/route delete default gw 10.64.64.64 ppp0 
/sbin/route add -net 10.138.0.0 netmask 255.255.255.0 dev ppp0 
