#!/usr/bin/env bash
TOKEN="$YANDEX_TOKEN"

# Директория для временного хранения бекапов, которые удаляются после отправки на Яндекс.Диск
BACKUP_DIR='/tmp/git-temp-backups'
mkdir -p "$BACKUP_DIR"

# Название проекта, используется в логах и именах архивов
PROJECT='git-backup'

# Максимальное количество хранимых на Яндекс.Диске бекапов (0 - хранить все бекапы):
MAX_BACKUPS='5'
DATE=`date '+%Y-%m-%d-%H%M%S'`

# Имя лог-файла, хранится в директории, указанной в $BACKUP_DIR
LOGFILE='backup.log'

function logger() {
    echo "["`date "+%Y-%m-%d %H:%M:%S"`"] File $BACKUP_DIR: $1" >> $BACKUP_DIR/$LOGFILE
}

function parseJson() {
    local output
    regex="(\"$1\":[\"]?)([^\",\}]+)([\"]?)"
    [[ $2 =~ $regex ]] && output=${BASH_REMATCH[2]}
    echo $output
}

function checkError() {
    echo $(parseJson 'error' "$1")
}

function getUploadUrl() {
    json_out=`curl -s -H "Authorization: OAuth $TOKEN" https://cloud-api.yandex.net:443/v1/disk/resources/upload/?path=app:/$backupName&overwrite=true`
    json_error=$(checkError "$json_out")
    if [[ $json_error != '' ]];
    then
        logger "$PROJECT - Yandex.Disk error: $json_error"
    echo ''
    else
        output=$(parseJson 'href' $json_out)
        echo $output
    fi
}

function uploadFile {
    local json_out
    local uploadUrl
    local json_error
    uploadUrl=$(getUploadUrl)
    if [[ $uploadUrl != '' ]];
    then
    echo $UploadUrl
        json_out=`curl -s -T $1 -H "Authorization: OAuth $TOKEN" $uploadUrl`
        json_error=$(checkError "$json_out")
    if [[ $json_error != '' ]];
    then
        logger "$PROJECT - Yandex.Disk error: $json_error"

    else
        logger "$PROJECT - Copying file to Yandex.Disk success"
    fi
    else
    	echo 'Some errors occured. Check log file for detail'
    fi
}

function backups_list() {
    curl -s -H "Authorization: OAuth $TOKEN" "https://cloud-api.yandex.net:443/v1/disk/resources?path=app:/&sort=created&limit=100" \
        | tr "{},[]" "\n" \
        | grep "name[[:graph:]]*.tar.gz" \
        | cut -d: -f 2 \
        | tr -d '"'
}

function backups_count() {
    backups_list | wc -l
}

function remove_old_backups() {
    bkps=$(backups_count)
    old_bkps=$((bkps - MAX_BACKUPS))
    if [ "$old_bkps" -gt "0" ];then
        logger "Delete old backups from Yandex Disk"
        for i in `eval echo {1..$((old_bkps * 2))}`; do
            curl -X DELETE -s -H "Authorization: OAuth $TOKEN" "https://cloud-api.yandex.net:443/v1/disk/resources?path=app:/$(backups_list | awk '(NR == 1)')&permanently=true"
        done
    fi
}

read -r -a REPOSITORIES <<< "aliasme\
    ansible-playbooks\
    api-crawler\
    assistant\
    auto-launcher\
    backup-tool\
    blog-notifier\
    budget-app\
    crypto-watch\
    daily-dashboard\
    deposit-watcher\
    diary\
    dotfiles\
    exercises-everyday\
    formatter\
    go-task-config\
    knowledge-map\
    misc\
    noter\
    papers-map\
    pdf-picker\
    pet-projects\
    study-monitoring"

logger "--- $PROJECT START BACKUP $DATE ---"
logger "Download git repositories"
mkdir $BACKUP_DIR/$DATE
for GIT_PROJECT in "${REPOSITORIES[@]}"; do
    git clone "https://github.com/ant1k9/$GIT_PROJECT" "$BACKUP_DIR/$DATE/$GIT_PROJECT"
done

logger "Make archive"
cd "$BACKUP_DIR/$DATE"
tar -czf $BACKUP_DIR/$DATE-$PROJECT.tar.gz .
rm -rf $BACKUP_DIR/$DATE

FILENAME=$DATE-$PROJECT.tar.gz
logger "Load archive $BACKUP_DIR/$DATE-$PROJECT.tar.gz to Yandex Disk"
backupName=$DATE-$PROJECT.tar.gz
uploadFile $BACKUP_DIR/$DATE-$PROJECT.tar.gz

if [ $MAX_BACKUPS -gt 0 ]; then remove_old_backups; fi

logger "Finalizing..."
rm -rf "$BACKUP_DIR/$DATE"
rm "$BACKUP_DIR/*.gz"
