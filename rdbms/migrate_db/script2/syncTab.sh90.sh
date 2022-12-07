#!/bin/bash

USER="wnlin";
UPWD=$(cat ../${USER}.txt);

SRV="
h=sh90-w.104.com.tw,P=3306,u=${USER},p=${UPWD},D=sh00010,t=verify_company_attachment h=172.30.34.208,P=3306,u=${USER},p=${UPWD}
";

pt-table-sync --print ${SRV}
