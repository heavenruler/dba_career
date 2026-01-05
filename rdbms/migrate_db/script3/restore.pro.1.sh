#!/bin/bash

HOST="172.30.35.221";
PORT="3306";
USER="wnlin";
UPWD=$(cat ../${USER}.txt);
EXPORT_PATH="../dump/pro";


ClientTool_8=$(mysql --version |grep -i "8.0");

if [ "${ClientTool_8}" != "" ];then
  VARIABLES_8="--set-gtid-purged=off --column-statistics=false";
fi

cd ${EXPORT_PATH}

# import db schema
echo "import alldb.schema.sql";
mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} -e "source ./alldb.schema.sql;"

# import db view
echo "import alldb.view.sql";
mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} -e "source ./alldb.view.sql;"

# import user
echo "import users.sql";
mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} -e "source ./users.sql;"

# db folder
for folder in $(find ./* -type d 2> /dev/null)
do
  echo "cd ${folder}";
  cd ${folder}

  for sql in $(find ./* -type f 2> /dev/null)
  do
   db=$(echo "${folder}" |sed 's/.\///g')

    echo "import ${sql}";
    mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} -e "use ${db};set sql_log_bin = 0;source ${sql};"
  done
  cd ..
done

# import trigger
echo "import alldb.triggers.sql";
mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} -e "source ./alldb.triggers.sql;"
