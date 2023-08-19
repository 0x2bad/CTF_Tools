#!/usr/bin/env bash

DB_NAME=example_db      # Replace with target database
DB_USER=example_user    # Replace with user to authenticate as
DB_PASS=example_pass    # Replace with password to authenticate as

# Retrieve the list of table names from the information_schema tables
TABLE_NAMES=$(mysql --user=$DB_USER --password=$DB_PASS -D $DB_NAME -s -N -e "SELECT table_name FROM information_schema.tables WHERE table_schema = '$DB_NAME'" 2>/dev/null)

# Loop through the table names and execute the SELECT statement for each table
for table_name in $TABLE_NAMES; do
    # Execute the SELECT statement and output TSV data
    mysql --user=$DB_USER --password=$DB_PASS -D $DB_NAME -e "SELECT * FROM $table_name" --batch 2>/dev/null | tr '\t' ',' > "$table_name.csv"
done
