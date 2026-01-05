#!/bin/bash

USER="wnlin";
UPWD=$(cat ../${USER}.txt);

SRV="
h=172.30.36.190,P=3306,u=${USER},p=${UPWD},D=sh00012,t=ac_user_login_log h=172.30.35.190,P=3306,u=${USER},p=${UPWD}
";

pt-table-sync --execute --print --sync-to-master --verbose ${SRV} 
