#!bin/bash

username=""
password=""

cd $(pwd)
wget --user=${username} --password=${password} https://url/data.zip
unzip data.zip
rm -rf ../data
mkdir ../data
mv data mysql
mv mysql ../data
