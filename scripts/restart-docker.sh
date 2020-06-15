#!/bin/bash

cd ../docker

source .env

docker stop ${Site_Name}-tomcat
docker stop ${Site_Name}-db
docker start ${Site_Name}-tomcat
docker start ${Site_Name}-db