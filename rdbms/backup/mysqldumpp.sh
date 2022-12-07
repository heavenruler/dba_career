#!/usr/bin/env bash

HOST=$1
USER=$2
PASS=$3
PORT=3306
DATABASE=$4
BACKUPPATH='/data/backup/mysqldump'
THREADS=8

DATE=`date "+%Y-%m-%d-%H%M"`
ZSTD=`type -P zstd`
PARALLEL=`type -P parallel`

DUMPPATH=${BACKUPPATH}/${HOST}
DESTINATION=${DUMPPATH}/${DATABASE-$DATE}

# Fetch all of the tables in the database.
TABLES=`mysql --batch --skip-column-names -u ${USER} --password="${PASS}" -h${HOST} -P${PORT} -e 'SHOW TABLES;' ${DATABASE}`

MYSQLDUMP_OPT="--compress --master-data=2 --max-allowed-packet=1G --comments=false --tz-utc=false --skip-add-drop-table  --skip-add-drop-database --skip-add-locks --lock-tables=false --single-transaction --default-character-set=utf8"

# purge backup path
mkdir -p ${DUMPPATH}
mkdir -p ${DESTINATION}

# Dump All Schema with Views by DBs
echo "Dumping All Schema with Views by DBs."
mysqldump -h${HOST} -u${USER} -p${PASS} -P${PORT} -B ${DATABASE} --no-data --routines=false --triggers=false ${MYSQLDUMP_OPT} | \
    ${ZSTD} -T${THREADS} -4 -f -o ${DESTINATION}/${DATABASE}_all_schema.sql.zst

# Dump All Routines by DBs
echo "Dumping Routines."
mysqldump -h${HOST} -u${USER} -p${PASS} -P${PORT} -B ${DATABASE} --no-data --routines --triggers=false --no-create-info ${MYSQLDUMP_OPT} | \
    ${ZSTD} -T${THREADS} -4 -f -o ${DESTINATION}/${DATABASE}_all_routines.sql.zst

# Dump All Triggers by DBs.
echo "Dumping Triggers."
mysqldump -h${HOST} -u${USER} -p${PASS} -P${PORT} -B ${DATABASE} --no-data --triggers --no-create-info ${MYSQLDUMP_OPT} | \
    ${ZSTD} -T${THREADS} -4 -f -o ${DESTINATION}/${DATABASE}_all_triggers.sql.zst

# Dump All Tables Data by DBs.
time echo ${TABLES} |
  $PARALLEL --no-notice -j${THREADS} -d ' ' --trim=rl -I ,  echo "Dumping table ,." \&\& mysqldump -u${USER} -p"'${PASS}'" -h${HOST} -P${PORT} ${MYSQLDUMP_OPT} ${DATABASE}  , \| ${ZSTD} -T${THREADS} -4 \> ${DESTINATION}/,.sql.zst
