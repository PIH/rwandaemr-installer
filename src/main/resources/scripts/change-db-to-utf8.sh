#!/bin/bash

# change-db-to-utf8.sh <database> <password>
# updates charset and collation for one database - all tables and all columns in all tables

DB="$1"
PW="$2"
CHARSET="utf8"
COLL="utf8_general_ci"

[ -n "$DB" ] || exit 1
[ -n "$PW" ]

PW="--password=""$PW"

echo $DB
echo "ALTER DATABASE $DB CHARACTER SET $CHARSET COLLATE $COLL;" | mysql -u root "$PW"

echo "USE $DB; SHOW TABLES;" | mysql -s "$PW" | (
    while read TABLE; do
        echo $DB.$TABLE
        echo "ALTER TABLE $TABLE CONVERT TO CHARACTER SET $CHARSET COLLATE $COLL;" | mysql "$PW" $DB
        echo "ALTER TABLE $TABLE DEFAULT CHARACTER SET $CHARSET COLLATE $COLL;" | mysql "$PW" $DB
    done
)

PW="xxx"
