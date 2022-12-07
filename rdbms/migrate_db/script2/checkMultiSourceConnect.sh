#!/bin/bash

HOST="172.30.34.208";
PORT="3306";
USER="user";
UPWD="pass";


channelList="
sh90-w
"

for channel in ${channelList}
do
  prefix=$(echo "${channel}" | cut -d '-' -f 1)

  if [[ "${prefix}" == "sh90" ]]; then
      replicate_do_db="sh00006,sh00008,sh00010,sh00011,sh00012"
  fi

  SlaveStatus=$(mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} -e "
    SET @@default_master_connection='${channel}';
    show slave status\G
  ");

  errorReconnectingToMaster=$(echo "${SlaveStatus}" |grep -i "error reconnecting to master");
  if [ "${errorReconnectingToMaster}" != "" ];then
    echo "execute [stop slave '${channel}';start slave '${channel}';]";
    mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} -e "
        SET @@default_master_connection='${channel}';
        stop slave '${channel}';
        SET GLOBAL replicate_do_Db='${replicate_do_db}';
        start slave '${channel}';";
  fi
done
