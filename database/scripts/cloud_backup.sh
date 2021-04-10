#!/bin/bash

set -a
source config/.env
set +a

# fonction qui attend en paramètre le message à publier dans slack
send_slack_notification() {
    echo -e $1
    curl -X POST -H 'Content-type: application/json' --data "{\"text\": \"$1\"}" $RB_DATABASE_REMOTEBACKUP_SLACK_WEBHOOK
}

############################################
# Ce script doit être exécuté depuis la
# machine hôte de Docker
############################################

# on identifie le fichier de backup du jour le plus récent
DATE=$(date "+%Y-%m-%d")
BACKUP_FILE_PATH=$(docker exec -t rb_database_data sh -c "find $RB_DATABASE_LOCALBACKUP_FOLDER -name \"$DATE-*\" -print0 | xargs -r -0 ls -1 -t | head -1")

if [[ -z "$BACKUP_FILE_PATH" ]]
then
    send_slack_notification "Aucun fichier de backup trouvé pour la date du $DATE"
    exit 1
else
    echo "Le fichier suivant va être transféré : $BACKUP_FILE_PATH"
fi

# on génère le fichier de conf rclone
envsubst "$(printf '${%s} ' $(env | sed 's/=.*//'))" < "config/rclone.conf.template" > "config/rclone.conf"

## on copie le fichier de backup sur le bucket scaleway
BACKUP_FILE_NAME=$(basename -- ${BACKUP_FILE_PATH/$'\r'})
RCLONE_CONFIG_PATH="$(cd config;pwd)/rclone.conf"

docker run --rm -it -v rb_database_backups:/data -v ${RCLONE_CONFIG_PATH}:/config/rclone/rclone.conf --user $(id -u):$(id -g) rclone/rclone copy --progress --error-on-no-transfer /data/$BACKUP_FILE_NAME secret:/
RCLONE_RESULT=$?

# Traitement du résulat de l'opération
SUCCESS=0
ERROR=
case $RCLONE_RESULT in
    0)
        SUCCESS=1;;
    1)
        ERROR='Syntax or usage error';;
    2)
        ERROR='Error not otherwise categorised.';;
    3)
        ERROR='Directory not found.';;
    4)
        ERROR='File not found.';;
    5)
        ERROR='Temporary error (one that more retries might fix) (Retry errors).';;
    6)
        ERROR='Less serious errors (like 461 errors from dropbox) (NoRetry errors).';;
    7)
        ERROR='Fatal error (one that more retries won''t fix, like account suspended) (Fatal errors).';;
    8)
        ERROR='Transfer exceeded - limit set by --max-transfer reached.';;
    9)
        ERROR='Operation successful, but no files transferred';;
    *)
        ERROR='Unknown response code.';;
esac

if [[ "$SUCCESS" -eq 1 ]]
then
    send_slack_notification "La copie du fichier de backup $BACKUP_FILE_NAME vers le bucket a réussi."
    exit 0
else
    send_slack_notification "La copie du fichier de backup $BACKUP_FILE_NAME vers le bucket a échoué !\nCode retour : ${RCLONE_RESULT} - ${ERROR}."
    exit 1
fi