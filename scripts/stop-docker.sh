#!/bin/bash

cd ../docker

source .env

docker stop ${Site_Name}-tomcat
docker stop ${Site_Name}-db
