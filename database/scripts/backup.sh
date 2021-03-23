#! /bin/bash

# backup-postgresql.sh
# by Craig Sanders &lt;cas@taz.net.au&gt;
# This script is public domain.  feel free to use or modify
# as you like.

DUMPALL='/usr/bin/pg_dumpall'
PGDUMP='/usr/bin/pg_dump'
PSQL='/usr/bin/psql'

# directory to save backups in, must be rwx by postgres user
BASE_DIR='/var/backups/postgres'
YMD=$(date "+%Y-%m-%d")
DIR="$BASE_DIR/$YMD"
mkdir -p "$DIR"
cd "$DIR"

# get list of databases in system , exclude the tempate dbs
DBS=( $($PSQL --list --tuples-only |
          awk '!/template[01]/ && $1 != "|" {print $1}') )

# first dump entire postgres database, including pg_shadow etc.
$DUMPALL --column-inserts | gzip -9 > "$DIR/db.out.gz"

# next dump globals (roles and tablespaces) only
$DUMPALL --globals-only | gzip -9 > "$DIR/globals.gz"

# now loop through each individual database and backup the
# schema and data separately
for database in "${DBS[@]}" ; do
    SCHEMA="$DIR/$database.schema.gz"
    DATA="$DIR/$database.data.gz"
    INSERTS="$DIR/$database.inserts.gz"

    # export data from postgres databases to plain text:

    # dump schema
    $PGDUMP --create --clean --schema-only "$database" |
        gzip -9 > "$SCHEMA"

    # dump data
    $PGDUMP --disable-triggers --data-only "$database" |
        gzip -9 > "$DATA"

    # dump data as column inserts for a last resort backup
    $PGDUMP --disable-triggers --data-only --column-inserts \
        "$database" | gzip -9 > "$INSERTS"

done

# delete backup files older than 30 days
echo deleting old backup files:
find "$BASE_DIR/" -mindepth 1 -type d -mtime +30 -print0 |
    xargs -0r rm -rfv