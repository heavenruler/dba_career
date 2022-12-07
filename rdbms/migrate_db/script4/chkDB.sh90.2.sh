#!/bin/bash

cd /data/migrate/script4

USER="wnlin";
UPWD=$(cat ../${USER}.txt);

HOST="172.30.36.190";
DB="--databases=sh00006,sh00008,sh00010,sh00011,sh00012";
#TABLES="--tables=basic,language_skill,search_cat,search_cat_wish_city,search_cat_wish_job"
#TABLES="--tables=resume_wage_flag";

pt-table-checksum --user=${USER} --password="${UPWD}" --no-check-binlog-format --no-check-replication-filters --host=${HOST} ${DB}
