#!/bin/bash
sleep $(( $RANDOM % 5 ))

. "/104/include/_config.sh"
. "/104/include/_function.sh"

MONGODB_PATH='/104/mongodb'
NDATE=`date +%Y%m%d`;
NHOUR=`date +%H`;
NDATETIME=`date +"%Y-%m-%d %H:%M:%S"`;
LOG="${MONGODB_PATH}/log/chkLive.${NDATE}.log.adam";

# DBNAME DBIP DBPORT SPACE DBCPU DBSWAP
dbList="${MONGODB_PATH}/tmp/_dbList.txt"
MONGO_CLI='/usr/bin/mongo'
dbArr=()
errArr=()

function read_dbList() {
  while IFS='' read -r line || [[ -n "$line" ]]; do
    # except comment line into arr
    if [[ ! "$line" =~ ^#  ]];then
      dbArr+=("$line")
    fi
  done < "$dbList"
}

function checkdb() {
  DBNAME=$1
  DBIP=$2
  DBPORT=$3
  portStatus=$(${MONGO_CLI} ${DBIP}:${DBPORT}/admin --eval "{ ping: \"PONG\" }" |tail -n1 2>> ${LOG})
  if [ "PONG" != "${portStatus}" ] ; then
    echo "${NTIME} ${DBNAME}(${DBIP}) ${DBPORT} FAIL AT $(date --iso-8601=seconds)" >> ${LOG};
    echo 1
  else
    echo 0
  fi
}

function checkLoop() {
  for(( i=0;i<${#dbArr[@]};i++ ))
  do
  #  echo ${dbArr[${i}]}
    status=$(checkdb ${dbArr[${i}]})
    if [ ${status} -ne 0 ]; then
      errArr+=(${i})
    fi
  done
}

function doubleCheckLoop() {
  declare -i count=0
  for(( i=0;i<3;i++ ))
  do
    for db in ${!errArr[@]}
    do
      status=$(checkdb ${dbArr[${errArr[${db}]}]})
      if [ ${status} -eq 0 ]; then
        unset errArr[${db}]
      fi
    done
    count+=1
    sleep .3
  done
}

function sendError() {
  DBNAME=$1
  DBIP=$2
  DBPORT=$3
  echo "${NTIME} ${DBNAME}(${DBIP}) ${DBPORT} FAIL (DBA-NewStaging-Restore:/104/mongodb/tmp/chkAlive.sh.adam)" >> ${LOG};
#  _sendErrorMESSAGE "${NTIME} ${DBNAME}(${DBIP}) ${DBPORT} is FAIL.";
}

function sendErrorLoop() {
  for db in ${!errArr[@]}
  do
    sendError ${dbArr[${errArr[${db}]}]}
  done
}

function main()
{
  echo -e "${NDATETIME}" >> ${LOG};
  read_dbList
  checkLoop
  if [ ${#errArr[@]} -gt 0 ]; then
    doubleCheckLoop
    sendErrorLoop
  fi
  echo "--------------------------------------------------------------------------------"  >> ${LOG};
}

main

#root@DBA-NewStaging-Restore:/104/mongodb/tmp# cat _dbList.txt
## DBNAME DBIP DBPORT SPACE DBCPU DBSWAP
#mdb0a-S1 mdb0a-s.104-staging.com.tw 27017 /:/data 30 30
#mdb0c-S1 mdb0c-s.104-staging.com.tw 27017 /:/data 30 30
#mdb0d-S1 mdb0d-s.104-staging.com.tw 27017 /:/data 30 30
#mdb0f-S1 mdb0f-s.104-staging.com.tw 27017 /:/data 30 30
#mdb0g-S1 mdb0g-s.104-staging.com.tw 27017 /:/data 30 30
#mdb0h-S1 mdb0h-s.104-staging.com.tw 27017 /:/data 30 30
