#!/bin/bash

# remove-liquibase-lock.sh <database> <password>
# ensures liquibasechangeloglock is not locked

DB="$1"
PW="$2"

[ -n "$DB" ] || exit 1
[ -n "$PW" ]

PW="--password=""$PW"

echo $DB
echo "USE $DB; UPDATE liquibasechangeloglock set locked=0;" | mysql -u root "$PW"

PW="xxx"
