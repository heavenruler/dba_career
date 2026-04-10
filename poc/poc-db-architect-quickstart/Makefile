SHELL := /bin/bash

SCENARIO ?= redis-standalone
REDIS_VERSION ?= 7.2-alpine
MYSQL_VERSION ?= 8.4
MARIADB_VERSION ?= 10.11
PROXYSQL_VERSION ?= 2.6.6

.PHONY: help init doctor up down reset verify logs

help:
	@printf "Usage:\n"
	@printf "  Supported SCENARIO values:\n"
	@printf "    redis-standalone   - 單機 Redis\n"
	@printf "    redis-replication  - 主從複寫\n"
	@printf "    redis-sentinel     - Sentinel 高可用\n"
	@printf "    redis-cluster      - Redis Cluster\n"
	@printf "    mysql-standalone   - 單機 MySQL\n"
	@printf "    mysql-replication  - MySQL 非同步複寫\n"
	@printf "    mysql-proxysql     - MySQL + ProxySQL\n"
	@printf "    mysql-group-replication - MySQL Group Replication\n"
	@printf "    mysql-innodb-cluster    - MySQL InnoDB Cluster\n"
	@printf "    mariadb-standalone - 單機 MariaDB\n"
	@printf "    mariadb-replication - MariaDB 非同步複寫\n"
	@printf "    mariadb-proxysql   - MariaDB + ProxySQL\n"
	@printf "    mariadb-galera     - MariaDB Galera Cluster\n"
	@printf "\n"
	@printf "  Supported REDIS_VERSION examples:\n"
	@printf "    6.0-alpine\n"
	@printf "    7.0-alpine\n"
	@printf "    7.2-alpine   (default)\n"
	@printf "    8.0-alpine\n"
	@printf "\n"
	@printf "  Supported MYSQL_VERSION values:\n"
	@printf "    5.7\n"
	@printf "    8.0\n"
	@printf "    8.4   (default)\n"
	@printf "    9.6\n"
	@printf "\n"
	@printf "  Supported MARIADB_VERSION values:\n"
	@printf "    10.5\n"
	@printf "    10.6\n"
	@printf "    10.11   (default)\n"
	@printf "    11.4\n"
	@printf "    11.8\n"
	@printf "\n"
	@printf "  Supported PROXYSQL_VERSION values:\n"
	@printf "    2.6.6   (default)\n"
	@printf "\n"
	@printf "  make init\n"
	@printf "  make doctor\n"
	@printf "  make up SCENARIO=<name> [REDIS_VERSION=<version>] [MYSQL_VERSION=<version>] [MARIADB_VERSION=<version>] [PROXYSQL_VERSION=<version>]\n"
	@printf "  make down SCENARIO=<name>\n"
	@printf "  make reset SCENARIO=<name> [REDIS_VERSION=<version>] [MYSQL_VERSION=<version>] [MARIADB_VERSION=<version>] [PROXYSQL_VERSION=<version>]\n"
	@printf "  make verify SCENARIO=<name>\n"
	@printf "  make logs SCENARIO=<name>\n"

init:
	@./bin/init.sh

doctor:
	@./bin/doctor.sh

up:
	@REDIS_VERSION="$(REDIS_VERSION)" MYSQL_VERSION="$(MYSQL_VERSION)" MARIADB_VERSION="$(MARIADB_VERSION)" PROXYSQL_VERSION="$(PROXYSQL_VERSION)" ./bin/up.sh "$(SCENARIO)"

down:
	@./bin/down.sh "$(SCENARIO)"

reset:
	@REDIS_VERSION="$(REDIS_VERSION)" MYSQL_VERSION="$(MYSQL_VERSION)" MARIADB_VERSION="$(MARIADB_VERSION)" PROXYSQL_VERSION="$(PROXYSQL_VERSION)" ./bin/reset.sh "$(SCENARIO)"

verify:
	@./scenarios/$(SCENARIO)/verify.sh

logs:
	@./bin/up.sh --logs "$(SCENARIO)"
