#!/usr/bin/env bash

DB_NAME=example_db      # Replace with target database
DB_USER=example_user    # Replace with user to authenticate as
DB_PASS=example_pass    # Replace with password to authenticate as
BACKUP_DIR=/path/to/dir # Replace with backup directory

# Create a folder for the database
mkdir -p "$BACKUP_DIR/$DB_NAME"

# Retrieve the list of table names from the information_schema tables
TABLE_NAMES=$(mysql --user=$DB_USER --password=$DB_PASS -D $DB_NAME -s -N -e "SELECT table_name FROM information_schema.tables WHERE table_schema = '$DB_NAME'" 2>/dev/null)

# Loop through the table names and execute the SELECT statement for each table
for table_name in $TABLE_NAMES; do
    mysql --user=$DB_USER --password=$DB_PASS -D $DB_NAME -e "SELECT * FROM $table_name" --batch 2>/dev/null | tr '\t' ',' >"$BACKUP_DIR/$DB_NAME/$table_name.csv"
done

# Create a compressed backup file from the folder
tar -czvf "$BACKUP_DIR/$DB_NAME.tar.gz" "$BACKUP_DIR/$DB_NAME" &>/dev/null

# Remove the folder
rm -rf "$BACKUP_DIR/$DB_NAME" &>/dev/null
