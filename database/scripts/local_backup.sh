#!/bin/bash

############################################
# Ce script doit être exécuté depuis le
# container de la base de données PostgreSQL
############################################

BACKUP_ID=$(date "+%Y-%m-%d-%H:%M")

# create the backup folder, if necessary
echo "Creating the backup folder ${RB_DATABASE_LOCALBACKUP_FOLDER}..."
mkdir -p "$RB_DATABASE_LOCALBACKUP_FOLDER"

# generate the backup file
echo "Generating a global dump of the database cluster..."
pg_dumpall -U "$POSTGRES_USER" | gzip -9 > "$RB_DATABASE_LOCALBACKUP_FOLDER/$BACKUP_ID.gz"

# remove files older than 30 days
echo "Removing dumps older than 30 days..."
find "$RB_DATABASE_LOCALBACKUP_FOLDER" -type f -mtime +30 -print0 | xargs -0r rm -fv