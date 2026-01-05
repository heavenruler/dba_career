#!/bin/bash

cd /data/migrate/script4

USER="wnlin";
UPWD=$(cat ../${USER}.txt);

SRV="
h=172.30.34.208,P=3306,u=${USER},p=${UPWD}
h=172.30.35.190,P=3306,u=${USER},p=${UPWD}
";

CRC="--crc";
DB="--databases=sh00006,sh00008,sh00010,sh00011,sh00012";
#TABLES="--tables=basic,language_skill,search_cat,search_cat_wish_city,search_cat_wish_job"
#TABLES="--tables=resume_wage_flag";

mk-table-checksum --count ${CRC} ${DB} ${TABLES} ${SRV}
