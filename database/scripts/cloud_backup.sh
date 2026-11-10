#!/bin/bash

set -a
source config/.env
set +a

# fonction qui attend en paramètre le message à publier sur Tchap (API Matrix)
# Variables lues dans config/.env : RB_API_TCHAP_BASE_URL et RB_API_TCHAP_TOKEN (communes avec l'API)
# et RB_REMOTEBACKUP_TCHAP_ROOM_ID (identifiant Matrix du salon, de la forme !xxxx:serveur)
# Les retours à la ligne s'écrivent \n dans le message.
send_tchap_notification() {
    echo -e "$1"

    # une variable manquante est signalée explicitement : une alerte qui part dans le vide ne doit pas passer inaperçue
    if [[ -z "$RB_API_TCHAP_BASE_URL" || -z "$RB_API_TCHAP_TOKEN" || -z "$RB_REMOTEBACKUP_TCHAP_ROOM_ID" ]]; then
        echo "Notification Tchap impossible : RB_API_TCHAP_BASE_URL, RB_API_TCHAP_TOKEN ou RB_REMOTEBACKUP_TCHAP_ROOM_ID n'est pas renseignée dans config/.env" >&2
        return 1
    fi

    # les caractères ! et : de l'identifiant du salon doivent être encodés dans l'URL
    local room_id
    room_id=$(printf '%s' "$RB_REMOTEBACKUP_TCHAP_ROOM_ID" | sed -e 's/!/%21/g' -e 's/:/%3A/g')

    # seuls les guillemets sont à échapper : \n est déjà une séquence d'échappement JSON valide
    local text="${1//\"/\\\"}"

    # le jeton est transmis par l'entrée standard (--config -) pour ne pas apparaître dans la liste des processus
    printf 'header = "Authorization: Bearer %s"\n' "$RB_API_TCHAP_TOKEN" | curl --silent --show-error --fail --max-time 30 --output /dev/null \
        --config - \
        --request PUT \
        --header "Content-Type: application/json" \
        --data "{\"msgtype\":\"m.text\",\"body\":\"${text}\"}" \
        "${RB_API_TCHAP_BASE_URL%/}/_matrix/client/v3/rooms/${room_id}/send/m.room.message/$(date +%s%N)" \
        || echo "Échec de l'envoi de la notification Tchap (code HTTP en erreur ou serveur injoignable)" >&2
}

############################################
# Ce script doit être exécuté depuis la
# machine hôte de Docker
############################################

# on identifie le fichier de backup du jour le plus récent
DATE=$(date "+%Y-%m-%d")
BACKUP_FILE_PATH=$(docker exec -t rb_database_data sh -c "find $RB_REMOTEBACKUP_LOCAL_BACKUP_FOLDER -name \"$DATE-*\" -print0 | xargs -r -0 ls -1 -t | head -1")

if [[ -z "$BACKUP_FILE_PATH" ]]
then
    send_tchap_notification "Aucun fichier de backup trouvé pour la date du $DATE"
    exit 1
else
    echo "Le fichier suivant va être transféré : $BACKUP_FILE_PATH"
fi

# on génère le fichier de conf rclone
envsubst "$(printf '${%s} ' $(env | sed 's/=.*//'))" < "config/rclone.conf.template" > "config/rclone.conf"

## on copie le fichier de backup sur le bucket scaleway
BACKUP_FILE_NAME=$(basename -- ${BACKUP_FILE_PATH/$'\r'})
RCLONE_CONFIG_PATH="$(cd config;pwd)/rclone.conf"

docker run --rm -i -v rb_database_backups:/data -v ${RCLONE_CONFIG_PATH}:/config/rclone/rclone.conf --user $(id -u):$(id -g) rclone/rclone copy --progress --error-on-no-transfer /data/$BACKUP_FILE_NAME secret:/
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
    send_tchap_notification "La copie du fichier de backup $BACKUP_FILE_NAME vers le bucket a réussi."
    exit 0
else
    send_tchap_notification "La copie du fichier de backup $BACKUP_FILE_NAME vers le bucket a échoué !\nCode retour : ${RCLONE_RESULT} - ${ERROR}."
    exit 1
fi