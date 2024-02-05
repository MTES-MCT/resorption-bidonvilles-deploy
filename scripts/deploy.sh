#!/bin/bash

set -a
source config/.env
set +a

TARGET_BRANCH=$1
TARGET_DOCKER_IMAGE=$2
TARGET_SAFENAME=$(echo $TARGET_BRANCH | sed -e "s/\//-/g")

function clearArchive() {
    echo "🟦 [Clearing /tmp files]"
    rm -rf "/tmp/resorption-bidonvilles-$TARGET_SAFENAME"
    rm -f "/tmp/resorption-bidonvilles-$TARGET_SAFENAME.zip"
    echo "🔹 Done"
}

function clearBackup() {
    echo "🟦 [Clearing data/rb_database_tmp/* files]"
    rm -f data/rb_database_tmp/backup_*
    echo "🔹 Done"
}

function clearAll() {
    clearArchive
    clearBackup
}

function updateRbVersion() {
    sed -i'.bak' "s/RB_DEPLOY_VERSION=$1/RB_DEPLOY_VERSION=$2/g" config/.env
    rm config/.env.bak

    if [[ "$(cat config/.env | grep 'RB_DEPLOY_VERSION=' | grep -oE "[^=]+$")" != $2 ]];
    then
        return 1
    fi

    return 0
}

function restoreRbVersion() {
    echo "🔹 Restoring RB_DEPLOY_VERSION inside config/.env ..."
    updateRbVersion $TARGET_DOCKER_IMAGE $SOURCE_VERSION
    return $?
}

function restartServices() {
    echo "🔹 Restarting through docker-compose..."
    MAKE_RESPONSE=$(make prod "up -d" | grep 'error')

    if [[ ! -z $MAKE_RESPONSE ]]; then
        return 1
    fi

    return 0
}

function restoreDatabase() {
    echo "🔹 [Restoring database]"

    echo "🔹 Dropping database..."
    MAKE_RESPONSE=$(make sequelize-tty db:drop | grep 'dropped')
    if [[ -z $MAKE_RESPONSE ]]; then
        echo "🔸 Failed dropping the database"
        return 1
    fi

    echo "🔹 Creating an empty database..."
    MAKE_RESPONSE=$(make sequelize-tty db:create | grep 'created')
    if [[ -z $MAKE_RESPONSE ]]; then
        echo "🔸 Failed recreating the database"
        return 1
    fi

    echo "🔹 Restoring the backup..."
    docker exec -t rb_database_data sh -c "psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB < /tmp/$BACKUP_RAWFILE_NAME"

    return $?
}

function rollback() {
    restoreRbVersion
    if [[ $? -ne 0 ]];
    then
        echo "🟥 Failed restoring RB_DEPLOY_VERSION: please edit config/.env manually and set RB_DEPLOY_VERSION to $SOURCE_VERSION"
    fi

    restoreDatabase
    if [[ $? -ne 0 ]];
    then
        echo "🟥 Failed restoring the database : please restore manually the backup file data/rb_database_tmp/$BACKUP_RAWFILE_NAME"
    else
        clearBackup
    fi

    clearArchive
}

# do NOT clear all here: we might need the backup file
clearArchive

### Download target version
echo "🟦 [Downloading the zipfile of the target branch]"
{
    echo "🔹 Curling https://github.com/MTES-MCT/resorption-bidonvilles/archive/refs/heads/$TARGET_BRANCH.zip to /tmp..."
    curl -L --fail https://github.com/MTES-MCT/resorption-bidonvilles/archive/refs/heads/$TARGET_BRANCH.zip --output /tmp/resorption-bidonvilles-$TARGET_SAFENAME.zip
} || {
    echo "🔸 Failed to curl the target version"
    exit 1
}

{
    echo "🔹 Unzipping the zipfile"
    unzip /tmp/resorption-bidonvilles-$TARGET_SAFENAME.zip -d /tmp
} || {
    echo "🔸 Failed to unzip the target version"
    rm -f /tmp/resorption-bidonvilles-$TARGET_SAFENAME.zip
    exit 1
}

echo "🔹 Done"

### Fetch list of migrations
echo "🟦 [Fetching the list of source migrations]"
echo "🔹 Getting a migrate:status..."

SOURCE_MIGRATIONS=$(make sequelize-tty db:migrate:status | grep 'up' | grep -oE "[0-9]{6,}-.+\.js")

if [ $? -ne 0 ];
then
    echo "🔸 Failed to list current migrations"
    clearArchive
    exit 1
fi

echo "🔹 Done"

### Backup current version
echo "🟦 [Backing up the value of the source RB_DEPLOY_VERSION]"
echo "🔹 Parsing config/.env..."
SOURCE_VERSION=$(cat config/.env | grep 'RB_DEPLOY_VERSION=' | grep -oE "[^=]+$")

if [[ -z $SOURCE_VERSION ]];
then
    echo "🔸 Failed to find the current version"
    clearArchive
    exit 1
fi

echo "🔹 Source version is $SOURCE_VERSION"
echo "🔹 Done"

### Backup database
echo "🟦 [Backing up the database]"

echo "🔹 Generating a local backup..."
BACKUP_RESPONSE=$(docker exec -t rb_database_data local_backup)
if [[ -z ${BACKUP_RESPONSE//[$'\t\r\n ']} ]];
then
    echo "🔸 Failed generating a backup"
    clearArchive
    exit 1
fi

{
    echo "🔹 Parsing the name of the backup file..."
    BACKUP_FILE_PATH=$(docker exec -t rb_database_data sh -c "find $RB_DATABASE_LOCALBACKUP_FOLDER -print0 | xargs -r -0 ls -1 -t 2>/dev/null | head -1")
    BACKUP_FILE_PATH=${BACKUP_FILE_PATH//[$'\t\r\n ']}
    BACKUP_ZIPFILE_NAME="backup_$SOURCE_VERSION.gz"
    BACKUP_RAWFILE_NAME="backup_$SOURCE_VERSION"
} || {
    echo "🔸 Failed parsing the backup"
    clearArchive
    exit 1
}

echo "🔹 Moving the backup to a directory mounted on the host..."
BACKUP_RESPONSE=$(docker exec -t rb_database_data sh -c "rm -f /tmp/$BACKUP_ZIPFILE_NAME && mv $BACKUP_FILE_PATH /tmp/$BACKUP_ZIPFILE_NAME")
if [[ ! -z $BACKUP_RESPONSE ]];
then
    echo "🔸 Failed moving the backup to mounted directory"
    clearArchive
    exit 1
fi

echo "🔹 Unzipping the backup file..."
docker exec -t rb_database_data sh -c "rm -f /tmp/$BACKUP_RAWFILE_NAME && gunzip /tmp/$BACKUP_ZIPFILE_NAME"
if [[ $? -ne 0 ]]; then
    echo "🔸 Failed unzipping the backup"
    clearAll
    exit 1
fi

echo "🔹 Done"

### Let's deploy
echo "🟦 [Setting RB_DEPLOY_VERSION to $TARGET_DOCKER_IMAGE in config/.env]"
echo "🔹 Writing into config/.env..."
updateRbVersion $SOURCE_VERSION $TARGET_DOCKER_IMAGE

if [[ $? -ne 0 ]];
then
    echo "🔸 Failed updating RB_DEPLOY_VERSION"
    clearAll
    exit 1
fi

echo "🔹 Done"

echo "🟦 [Pulling the new images]"
echo "🔹 Pulling through docker-compose..."
MAKE_RESPONSE=$(make prod pull | grep 'error')

if [[ ! -z $MAKE_RESPONSE ]];
then
    echo "🔸 Failed fetching the docker images"
    restoreRbVersion
    if [[ $? -ne 0 ]];
    then
        echo "🟥 Failed restoring RB_DEPLOY_VERSION: please edit config/.env manually and set RB_DEPLOY_VERSION to $SOURCE_VERSION"
    fi

    clearAll
    exit 1
fi

echo "🔹 Done"

### Undo migrations
echo "🟦 [Undoing migrations that existed in the source version but not in the target version]"
FAILED=false
for name in $SOURCE_MIGRATIONS; do
    if [ ! -e /tmp/resorption-bidonvilles-$TARGET_SAFENAME/packages/api/db/migrations/$name ];
    then
        echo "🔹 Undoing $name..."
        MAKE_RESPONSE=$(make sequelize-tty "db:migrate:undo --name $name" | grep 'reverted')

        if [[ -z $MAKE_RESPONSE ]];
        then
            echo "🔸 Failed undoing migration $name"
            FAILED=true
            break
        fi
    fi
done

if $FAILED;
then
    rollback
    restartServices

    if [[ $? -ne 0 ]]; then
        echo "🟥 Failed restarting services, please manually run 'make prod \"up -d \"'"
    fi

    exit 1
fi

echo "🔹 Done"

echo "🟦 [Restarting services]"
restartServices

if [[ $? -ne 0 ]]; then
    echo "🟥 Failed to restart services, please manually run 'make prod \"up -d \"'"
    rollback
    exit 1
fi

echo "🔹 Waiting for https://${RB_PROXY_FRONTEND_HOST} to respond with a 200..."
timeout -s TERM 30 bash -c \
    'while [[ "$(curl -s -o /dev/null -L -w ''%{http_code}'' ${0})" != "200" ]]; do\
        echo "🔹 Next ping in 5 seconds";\
        sleep 5;\
    done' "https://${RB_PROXY_FRONTEND_HOST}"

echo "🔹 Waiting for https://app.${RB_PROXY_FRONTEND_HOST} to respond with a 200..."
timeout -s TERM 30 bash -c \
    'while [[ "$(curl -s -o /dev/null -L -w ''%{http_code}'' ${0})" != "200" ]]; do\
        echo "🔹 Next ping in 5 seconds";\
        sleep 5;\
    done' "https://app.${RB_PROXY_FRONTEND_HOST}"

echo "🔹 Waiting for https://${RB_PROXY_API_HOST} to respond with a 200..."
timeout -s TERM 30 bash -c \
    'while [[ "$(curl -s -o /dev/null -L -w ''%{http_code}'' ${0})" != "200" ]]; do\
        echo "🔹 Next ping in 5 seconds";\
        sleep 5;\
    done' "https://${RB_PROXY_API_HOST}"

echo "🔹 Done"

echo "🟦 [Running migrations]"
echo "🔹 Running db:migrate..."
MAKE_RESPONSE=$(make sequelize-tty db:migrate | grep 'ERROR')

if [[ ! -z $MAKE_RESPONSE ]]; then
    echo "🔸 Failed to run migrations"

    rollback
    restartServices

    if [[ $? -ne 0 ]]; then
        echo "🟥 Failed restarting services, please manually run 'make prod \"up -d \"'"
    fi

    exit 1
fi

clearAll