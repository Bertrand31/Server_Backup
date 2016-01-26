#!/bin/bash

# Ce script compresse la dernière sauvegarde journalière (backup.0/), télécharge la dernière
# sauvegarde hebdomadaire du serveur de dev, et envoie les deux archives sur le FTP de sauvegarde d'OVH

#COLORS
RED='\e[0;31m'
GREEN='\e[0;32m'
NC='\e[0m'
ARROW="${GREEN}==>${NC}"

#PLAYGROUND - LOCAL
LOCAL_BASE_DIR="/home/backup-user"
LOCAL_DAILY_DIR="${LOCAL_BASE_DIR}/daily"
LOCAL_HEBDO_DIR="${LOCAL_BASE_DIR}/weekly"

#MISC
SCP=/usr/bin/scp
TIME=`date +"%Y-%m-%d"`
LOGFILE=${LOCAL_BASE_DIR}/logs/backup-weekly.log

#COMPRESSION
TAR=/bin/tar
PLZIP=/usr/local/bin/plzip

#EMAIL
MAIL=/usr/bin/mail
SUBJECT="Sauvegarde hebdomadaire du serveur `hostname`, le ${TIME}"
RECIPIENT="admin@xxxxx.xx"
SENDER="Serveur `hostname` <root@`hostname`>"

#FTP
LFTP=/usr/local/bin/lftp
FTP_USER="xxxxxxxxx"
FTP_PASSWORD="*********"
FTP_HOST="xxxxxxx.xx"

#FONCTIONS
timestamp() { echo $(date +"%s"); }
elapsed() {
	ELAPSED=$(($(timestamp)-$1))
	echo "=> Temps écoulé : " `echo ${ELAPSED} | awk '{printf("%01d heures, %01d minutes et %01d secondes", ($1/3600), ($1%3600/60),($1%60))}'`
}

exec > >(tee ${LOGFILE})
exec 2> >(tee -a ${LOGFILE})

echo -e "\n${RED}*****************************${NC}\n" `date +"%a %d %b %Y, %H:%M:%S"` "\n${RED}*****************************${NC}\n"

echo -e "\n${ARROW} Nettoyages des précédents fichiers de sauvegarde"

test -e ${LOCAL_HEBDO_DIR}/backup.tar.lz && rm ${LOCAL_HEBDO_DIR}/backup.tar.lz || echo "Attention : backup.tar.lz n'existe pas";

echo -e "\n${ARROW} Compression de backup.0/ -" `date +"%H:%M:%S"`
CPBEGIN=$(timestamp)
nice -n 19 ${TAR} -c ${LOCAL_DAILY_DIR}/backup.0 | ${PLZIP} -2o ${LOCAL_HEBDO_DIR}/backup-.tar
echo $(elapsed $CPBEGIN)
echo -e "=> Taille du fichier de sauvegarde : " `du -h ${LOCAL_HEBDO_DIR}/backup.tar.lz | awk '{print $1}'` "\n"

echo -e "${ARROW} Téléversement des sauvegardes hebdomadaires du serveur `hostname` -" `date +"%H:%M:%S"` "\n"
${LFTP} ftp://${FTP_USER}:${FTP_PASSWORD}@${FTP_HOST} -e "set ftp:ssl-allow no; mkdir ${TIME}/; cd ${TIME}; put ${LOCAL_HEBDO_DIR}/backup.tar.lz; quit";

#Le fichier .banner sur le FTP contient le %age d'occupation de l'espace de sauvegarde
RATIO=`${LFTP} ftp://${FTP_USER}:${FTP_PASSWORD}@${FTP_HOST} -e "set ftp:ssl-allow no; cat .banner;  quit" | awk -F '[()]' '{print $2}'`

if [[ ${RATIO} > 80 ]]; then
	echo -e "\n=> ATTENTION l'espace FTP est utilisé à ${RATIO}"
	SUBJECT="ATTENTION : FTP de backup rempli à ${RATIO} - ${SUBJECT}"
    #Nettoyage automatique de l'espace FTP
    printf "\n${ARROW} Nettoyage du FTP de sauvegarde :"
    FTP_OLDEST_FILE=`${LFTP} ftp://${FTP_USER}:${FTP_PASSWORD}@${FTP_HOST} -e "set ftp:ssl-allow no; ls; exit;" | awk '{print $9}' | egrep -v "^\." | sort | head -n1`
    printf "\n=> Suppression du dossier ${FTP_OLDEST_FILE}/\n"
    ${LFTP} ftp://${FTP_USER}:${FTP_PASSWORD}@${FTP_HOST} -e "set ftp:ssl-allow no; rm -r ${FTP_OLDEST_FILE}/; exit;"
else
	printf "\n=> L'espace FTP est utilisé à ${RATIO}\n"
fi

echo "\n${ARROW} Sauvegarde terminée à" `date +"%H:%M:%S"`

sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" ${LOGFILE} | ${MAIL} -r "${SENDER}" -s "${SUBJECT}" ${RECIPIENT}

exit 0
