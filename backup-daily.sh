#!/bin/bash

# Ce script effectue une sauvegarde des fichiers incrémentale et un dump des bases de données chaque jour,
# et garde des sauvegardes des huit derniers jours

#COLORS
RED='\e[0;31m'
GREEN='\e[0;32m'
NC='\e[0m'
ARROW="${GREEN}==>${NC}"

#PLAYGROUND
BACKUP_HOME="/home/backup-user"
BACKUP_DEST="${BACKUP_HOME}/daily"

#RSYNC
RSYNC=/usr/bin/rsync
EXCLUDE_LIST="${BACKUP_HOME}/backup-exclude-list.txt" #Files and folders ignored by RSYNC

#MISC
BACKUP_USER="backup-user"
TIME=`date +"%Y-%m-%d"`
LOGFILE=${BACKUP_HOME}/logs/backup-daily.log

#COMPRESSION
GZIP=/bin/gzip

#MYSQL
MYSQL=/usr/bin/mysql
MYSQLDUMP=/usr/bin/mysqldump
MYSQL_USER="backupuser" #Readonly user
MYSQL_PASSWORD="********"
DATABASES_LIST=`${MYSQL} --user=${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)"`

#EMAIL
MAIL=/usr/bin/mail
SUBJECT="Rotation des sauvegardes du serveur `hostname`, le ${TIME}"
RECIPIENT="bertrandjun@gmail.com"
SENDER="Serveur `hostname` <admin@`hostname`>"

#FONCTIONS
timestamp() { echo $(date +"%s"); }
elapsed() {
	ELAPSED=$(($(timestamp)-$1))
	echo "=> Temps écoulé : " `echo ${ELAPSED} | awk '{printf("%01d heures, %01d minutes et %01d secondes", ($1/3600), ($1%3600/60),($1%60))}'`
}

exec > >(tee ${LOGFILE})
exec 2> >(tee -a ${LOGFILE})

echo -e "${RED}\n*****************************\n${NC}" `date +"%a %d %b %Y, %H:%M:%S"` "${RED}\n*****************************\n${NC}"

echo -e "${ARROW} Modification des permissions de la sauvegarde à J-8 -" `date +"%H:%M:%S"`

find ${BACKUP_DEST}/backup.7/ ! -writable -exec chmod u+w {} +

echo -e "${ARROW} Suppression de la sauvegarde à J-8 -" `date +"%H:%M:%S"`

rm -Rf ${BACKUP_DEST}/backup.7

echo -e "\n${ARROW} Rotation des sauvegardes existantes -" `date +"%H:%M:%S"`

for i in {7..1}
do
     mv ${BACKUP_DEST}/backup.$((${i}-1)) ${BACKUP_DEST}/backup.${i}
done

mkdir -p ${BACKUP_DEST}/backup.0/mysql

echo -e "\n${ARROW} Exportation des bases de données -" `date +"%H:%M:%S"` "\n"

for db in ${DATABASES_LIST}; do
    ${MYSQLDUMP} --force --opt --single-transaction --user=${MYSQL_USER} -p${MYSQL_PASSWORD} --databases ${db} | gzip > "${BACKUP_DEST}/backup.0/mysql/${db}.sql.gz"
	echo -e "=> ${db}.sql.gz -" `du -h ${BACKUP_DEST}/backup.0/mysql/${db}.sql.gz | awk '{print $1}'`
done

echo -e "\n${ARROW} Copie de dev/ et prod/ -" `date +"%H:%M:%S"` "\n"

${RSYNC} -rlpth --exclude-from "${EXCLUDE_LIST}" --stats --delete --safe-links --link-dest=${BACKUP_DEST}/backup.1 /home/dev /home/prod ${BACKUP_DEST}/backup.0/ | grep -v "File list" | awk 'length {printf "=> " $0 "\n"}' | sed -e 's/ bytes$/B/g' -e 's/ seconds/s/g' -e 's/M bytes/MB/g'

echo -e "\n${ARROW} Fin de la sauvegarde journalière -" `date +"%H:%M:%S"` "\n"

sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" ${LOGFILE} | ${MAIL} -r "${SENDER}" -s "${SUBJECT}" ${RECIPIENT}

exit 0
