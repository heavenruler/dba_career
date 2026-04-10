# Operations Guide

常用操作：

```bash
make init
make doctor
make up SCENARIO=redis-standalone
make verify SCENARIO=redis-standalone
make up SCENARIO=mysql-standalone MYSQL_VERSION=8.4
make verify SCENARIO=mysql-standalone
make up SCENARIO=mariadb-standalone MARIADB_VERSION=10.11
make verify SCENARIO=mariadb-standalone
make up SCENARIO=mariadb-replication MARIADB_VERSION=10.11
make verify SCENARIO=mariadb-replication
make up SCENARIO=mariadb-proxysql MARIADB_VERSION=10.11 PROXYSQL_VERSION=2.6.6
make verify SCENARIO=mariadb-proxysql
make up SCENARIO=mariadb-galera MARIADB_VERSION=10.11
make verify SCENARIO=mariadb-galera
make up SCENARIO=mysql-replication MYSQL_VERSION=8.4
make verify SCENARIO=mysql-replication
make up SCENARIO=mysql-proxysql MYSQL_VERSION=8.4 PROXYSQL_VERSION=2.6.6
make verify SCENARIO=mysql-proxysql
make up SCENARIO=mysql-group-replication MYSQL_VERSION=8.4
make verify SCENARIO=mysql-group-replication
make up SCENARIO=mysql-innodb-cluster MYSQL_VERSION=8.4
make verify SCENARIO=mysql-innodb-cluster
make down SCENARIO=redis-standalone
make reset SCENARIO=redis-standalone
```

檢視 logs：

```bash
make logs SCENARIO=redis-standalone
```
