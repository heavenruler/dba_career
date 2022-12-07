#!/bin/bash

HOST="172.30.34.208";
PORT="3306";
USER="user";
UPWD="pass";
PREFIX="pro";
DBNAME="sh00006|sh00008|sh00010|sh00011|sh00012";
EXPORT_PATH="../dump/$PREFIX";

ClientTool_8=$(mysql --version |grep -i "8.0");

if [ "${ClientTool_8}" != "" ];then
  VARIABLES_8="--set-gtid-purged=off --column-statistics=false";
fi

rm -rf ${EXPORT_PATH}
mkdir -p ${EXPORT_PATH}

# master info
mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} -e "show master status\G" > ${EXPORT_PATH}/binlog.info

# dump user & priv
cat /dev/null > ${EXPORT_PATH}/users.sql
userList=$(mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} --column-names=false -e "
  select concat(user,'@',host) from mysql.user
    where (user like '${PREFIX}%' or user regexp '${DBNAME}')
  order by user asc
")
for uh in ${userList}
do
  u=$(echo ${uh} |cut -d '@' -f1)
  h=$(echo ${uh} |cut -d '@' -f2)

  mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} -N -e "show grants for '${u}'@'${h}';" |sed 's/$/;/g' >> ${EXPORT_PATH}/users.sql
  echo "" >> ${EXPORT_PATH}/users.sql
done

# dump db
dbList=$(mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} --column-names=false -e "
  select distinct table_schema from information_schema.tables
    where table_schema not in('information_schema','performance_schema','sys','mysql') and table_schema regexp '${DBNAME}'
");

strDB="";
#cat /dev/null > ${EXPORT_PATH}/alldb.schema.sql
for db in ${dbList}
do
  strDB="${strDB} ${db}";

  mkdir -p ${EXPORT_PATH}/${db}

  # dump db data
  tableList=$(mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} --column-names=false -e "
    select table_name from information_schema.tables where table_schema = '${db}' and table_type = 'BASE TABLE';
  ");
  for table in ${tableList}
  do
    mysqldump -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} \
      --single-transaction --no-create-db --no-create-info --skip-add-locks --skip-lock-tables --skip-triggers \
      --complete-insert --compress=true --quick ${VARIABLES_8} \
      --databases ${db} --tables ${table} --result-file=${EXPORT_PATH}/${db}/${table}.data.sql
  done
done

# dump db schema
mysqldump -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} \
  --single-transaction --skip-triggers --quick --routines --no-data ${VARIABLES_8} \
  --databases ${strDB} --result-file=${EXPORT_PATH}/alldb.schema.sql

# dump trigger
mysqldump -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} \
  --single-transaction --no-create-db --no-create-info --triggers --quick --no-data ${VARIABLES_8} \
  --databases ${strDB} --result-file=${EXPORT_PATH}/alldb.triggers.sql

# dump view
cat /dev/null > ${EXPORT_PATH}/alldb.view.sql
viewList=$(mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} --column-names=false -e "
  select concat(table_schema,'.',table_name) from information_schema.tables
    where table_type = 'VIEW' and table_schema not in('information_schema','performance_schema','sys','mysql')
    and table_schema regexp '${DBNAME}';
")
for view in ${viewList}
do
  d=$(echo ${view} |cut -d '.' -f1)
  t=$(echo ${view} |cut -d '.' -f2)

  mysql -u ${USER} -p"${UPWD}" -h ${HOST} -P ${PORT} -E -e "show create view ${d}.${t};" |grep -i "Create View:" |awk -F ":" '{print $2}' |sed 's/ //' >> ${EXPORT_PATH}/alldb.view.sql
  echo ";" >> ${EXPORT_PATH}/alldb.view.sql
  echo "" >> ${EXPORT_PATH}/alldb.view.sql
done
