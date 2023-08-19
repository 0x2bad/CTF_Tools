#!/usr/bin/env bash

DB_NAME=example_db      # Replace with target database
DB_USER=example_user    # Replace with user to authenticate as
DB_PASS=example_pass    # Replace with password to authenticate as

TABLE_NAMES=$(mysql --user=$DB_USER --password=$DB_PASS -D $DB_NAME -s -N -e "SELECT table_name FROM information_schema.tables WHERE table_schema = '$DB_NAME'" 2>/dev/null)

SELECT_STATEMENTS=""

for table_name in $TABLE_NAMES; do
    SELECT_STATEMENTS="$SELECT_STATEMENTS SELECT * FROM $DB_NAME.$table_name;"
done

mysql --user=$DB_USER --password=$DB_PASS -D $DB_NAME -e "$SELECT_STATEMENTS" 2>/dev/null > db-dump_$DB_NAME
