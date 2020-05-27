#!/bin/bash

cd ../docker

source .env

docker-compose -p $Site_Name up -d --no-deps