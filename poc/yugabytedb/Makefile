.PHONY: help init wait health status logs sql query seed destroy destroy-all restart init-cluster wait-cluster health-cluster status-cluster logs-cluster query-cluster geo-cluster destroy-cluster destroy-cluster-all restart-cluster init-cluster-ha wait-cluster-ha configure-cluster-ha health-cluster-ha status-cluster-ha logs-cluster-ha query-cluster-ha geo-cluster-ha failover-test-ha destroy-cluster-ha destroy-cluster-ha-all restart-cluster-ha destroy-all-lab

PODMAN := podman
COMPOSE := $(PODMAN) compose
COMPOSE_FILE := compose.yml
CLUSTER_COMPOSE_FILE := compose.cluster.yml
CLUSTER_HA_COMPOSE_FILE := compose.cluster.ha.yml
DOCKER_CONFIG_DIR := /tmp/podman-docker-config
COMPOSE_ENV := DOCKER_CONFIG=$(DOCKER_CONFIG_DIR)
CONTAINER := yugabytedb-local
DB_HOST := yugabytedb
YSQL_CMD := $(PODMAN) exec -it $(CONTAINER) ysqlsh -h $(DB_HOST) -p 5433 -U yugabyte -d yugabyte
YSQL_BATCH := $(PODMAN) exec -i $(CONTAINER) ysqlsh -h $(DB_HOST) -p 5433 -U yugabyte -d yugabyte
CLUSTER_CONTAINER := yb-tserver-az1
CLUSTER_DB_HOST := yb-tserver-az1
CLUSTER_YSQL_CMD := $(PODMAN) exec -it $(CLUSTER_CONTAINER) ysqlsh -h $(CLUSTER_DB_HOST) -p 5433 -U yugabyte -d yugabyte
CLUSTER_YSQL_BATCH := $(PODMAN) exec -i $(CLUSTER_CONTAINER) ysqlsh -h $(CLUSTER_DB_HOST) -p 5433 -U yugabyte -d yugabyte
CLUSTER_HA_MASTER_ADDRS := yb-master-ha-1:7100,yb-master-ha-2:7100,yb-master-ha-3:7100
CLUSTER_HA_MASTER_CONTAINER := yb-master-ha-1
CLUSTER_HA_CONTAINER := yb-tserver-ha-1
CLUSTER_HA_FAIL_NODE := yb-tserver-ha-3
CLUSTER_HA_DB_HOST := yb-tserver-ha-1
CLUSTER_HA_YSQL_CMD := $(PODMAN) exec -it $(CLUSTER_HA_CONTAINER) ysqlsh -h $(CLUSTER_HA_DB_HOST) -p 5433 -U yugabyte -d yugabyte
CLUSTER_HA_YSQL_BATCH := $(PODMAN) exec -i $(CLUSTER_HA_CONTAINER) ysqlsh -h $(CLUSTER_HA_DB_HOST) -p 5433 -U yugabyte -d yugabyte
YB_ADMIN_HA := $(PODMAN) exec $(CLUSTER_HA_MASTER_CONTAINER) yb-admin --master_addresses=$(CLUSTER_HA_MASTER_ADDRS)
SEED_FILE := init.sql
GEO_FILE := geo-partition.sql
SQL ?= SELECT * FROM demo.accounts LIMIT 5;
CLUSTER_SQL ?= SELECT host, port, cloud, region, zone, public_ip FROM yb_servers() ORDER BY host LIMIT 5;
CLUSTER_HA_SQL ?= SELECT host, port, cloud, region, zone, public_ip FROM yb_servers() ORDER BY host LIMIT 6;

help:
	@printf '%s\n' \
	  '' \
	  '=== 單機 POC ===' \
	  'make init                 啟動單機 YugabyteDB POC 環境' \
	  'make wait                 等待單機 YSQL 就緒' \
	  'make health               檢查單機 YSQL、7000、9000 健康狀態' \
	  'make status               顯示單機 compose 與 port 狀態' \
	  'make logs                 追蹤單機 YugabyteDB logs' \
	  'make sql                  進入單機 ysqlsh' \
	  'make query                執行單機查詢，預設查 demo.accounts LIMIT 5' \
	  'make seed                 套用 init.sql 範例資料' \
	  'make restart              重建單機環境' \
	  'make destroy              停止單機環境' \
	  'make destroy-all          停止單機環境並刪除 volume' \
	  '' \
	  '=== 三區模擬叢集 ===' \
	  'make init-cluster         啟動 1 master + 3 tserver 三區模擬叢集' \
	  'make wait-cluster         等待三區模擬叢集 YSQL 就緒' \
	  'make health-cluster       檢查三區模擬叢集 YSQL 與 UI 健康狀態' \
	  'make status-cluster       顯示三區模擬叢集 compose 狀態' \
	  'make logs-cluster         追蹤三區模擬叢集 logs' \
	  'make query-cluster        查詢三區模擬叢集節點拓樸' \
	  'make geo-cluster          套用 geo-partition 範例 SQL 到三區模擬叢集' \
	  'make restart-cluster      重建三區模擬叢集' \
	  'make destroy-cluster      停止三區模擬叢集' \
	  'make destroy-cluster-all  停止三區模擬叢集並刪除 volumes' \
	  '' \
	  '=== HA 模擬叢集 ===' \
	  'make init-cluster-ha      啟動 3 master + 3 tserver HA 模擬叢集' \
	  'make wait-cluster-ha      等待 HA 模擬叢集 YSQL 就緒' \
	  'make configure-cluster-ha 對 HA 模擬叢集套用 RF=3 placement' \
	  'make health-cluster-ha    檢查 HA 模擬叢集 YSQL 與 UI 健康狀態' \
	  'make status-cluster-ha    顯示 HA 模擬叢集 compose 狀態' \
	  'make logs-cluster-ha      追蹤 HA 模擬叢集 logs' \
	  'make query-cluster-ha     查詢 HA 模擬叢集節點拓樸' \
	  'make geo-cluster-ha       套用 geo-partition 範例 SQL 到 HA 模擬叢集' \
	  'make failover-test-ha     模擬 HA 節點故障並驗證查詢仍可用' \
	  'make restart-cluster-ha   重建 HA 模擬叢集' \
	  'make destroy-cluster-ha   停止 HA 模擬叢集' \
	  'make destroy-cluster-ha-all 停止 HA 模擬叢集並刪除 volumes' \
	  '' \
	  '=== 全域清理 ===' \
	  'make destroy-all-lab      一次清掉單機、cluster、HA 全部實驗環境'

init:
	@mkdir -p "$(DOCKER_CONFIG_DIR)"
	@$(PODMAN) machine start >/dev/null 2>&1 || true
	@$(COMPOSE_ENV) $(COMPOSE) -f $(COMPOSE_FILE) up -d
	@$(MAKE) wait

wait:
	@i=1; \
	until $(PODMAN) exec $(CONTAINER) ysqlsh -h $(DB_HOST) -p 5433 -U yugabyte -d yugabyte -c 'select 1' >/dev/null 2>&1; do \
	  if [ $$i -gt 24 ]; then \
	    printf '%s\n' 'YugabyteDB is not ready after 120 seconds'; \
	    exit 1; \
	  fi; \
	  printf '%s\n' 'Waiting for YugabyteDB YSQL...'; \
	  i=$$((i + 1)); \
	  sleep 5; \
	done
	@printf '%s\n' 'YugabyteDB YSQL is ready'

health:
	@curl -fsS http://127.0.0.1:7000 >/dev/null
	@printf '%s\n' 'Master UI OK: http://127.0.0.1:7000'
	@curl -fsS http://127.0.0.1:9000 >/dev/null
	@printf '%s\n' 'TServer UI OK: http://127.0.0.1:9000'
	@$(PODMAN) exec $(CONTAINER) ysqlsh -h $(DB_HOST) -p 5433 -U yugabyte -d yugabyte -c 'select 1' >/dev/null
	@printf '%s\n' 'YSQL OK: 127.0.0.1:5433'

status:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(COMPOSE_FILE) ps
	@$(PODMAN) port $(CONTAINER)

logs:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(COMPOSE_FILE) logs -f yugabytedb

sql:
	@$(YSQL_CMD)

query:
	@$(MAKE) wait
	@$(PODMAN) exec -i $(CONTAINER) ysqlsh -h $(DB_HOST) -p 5433 -U yugabyte -d yugabyte -c "$(SQL)"

seed:
	@$(MAKE) wait
	@$(YSQL_BATCH) -f - < $(SEED_FILE)
	@printf '%s\n' 'Seed applied from $(SEED_FILE)'

destroy:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(COMPOSE_FILE) down

destroy-all:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(COMPOSE_FILE) down -v

restart: destroy init

init-cluster:
	@mkdir -p "$(DOCKER_CONFIG_DIR)"
	@$(PODMAN) machine start >/dev/null 2>&1 || true
	@$(COMPOSE_ENV) $(COMPOSE) -f $(CLUSTER_COMPOSE_FILE) up -d
	@$(MAKE) wait-cluster

wait-cluster:
	@i=1; \
	until $(PODMAN) exec $(CLUSTER_CONTAINER) ysqlsh -h $(CLUSTER_DB_HOST) -p 5433 -U yugabyte -d yugabyte -c 'select 1' >/dev/null 2>&1; do \
	  if [ $$i -gt 48 ]; then \
	    printf '%s\n' 'YugabyteDB cluster is not ready after 240 seconds'; \
	    exit 1; \
	  fi; \
	  printf '%s\n' 'Waiting for YugabyteDB cluster YSQL...'; \
	  i=$$((i + 1)); \
	  sleep 5; \
	done
	@printf '%s\n' 'YugabyteDB cluster YSQL is ready'

health-cluster:
	@curl -fsS http://127.0.0.1:17000 >/dev/null
	@printf '%s\n' 'Cluster Master UI OK: http://127.0.0.1:17000'
	@curl -fsS http://127.0.0.1:19000 >/dev/null
	@printf '%s\n' 'Cluster TServer AZ1 UI OK: http://127.0.0.1:19000'
	@curl -fsS http://127.0.0.1:19001 >/dev/null
	@printf '%s\n' 'Cluster TServer AZ2 UI OK: http://127.0.0.1:19001'
	@curl -fsS http://127.0.0.1:19002 >/dev/null
	@printf '%s\n' 'Cluster TServer AZ3 UI OK: http://127.0.0.1:19002'
	@$(PODMAN) exec $(CLUSTER_CONTAINER) ysqlsh -h $(CLUSTER_DB_HOST) -p 5433 -U yugabyte -d yugabyte -c 'select 1' >/dev/null
	@printf '%s\n' 'Cluster YSQL OK: 127.0.0.1:15433'

status-cluster:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(CLUSTER_COMPOSE_FILE) ps

logs-cluster:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(CLUSTER_COMPOSE_FILE) logs -f

query-cluster:
	@$(MAKE) wait-cluster
	@$(PODMAN) exec -i $(CLUSTER_CONTAINER) ysqlsh -h $(CLUSTER_DB_HOST) -p 5433 -U yugabyte -d yugabyte -c "$(CLUSTER_SQL)"

geo-cluster:
	@$(MAKE) wait-cluster
	@$(CLUSTER_YSQL_BATCH) -f - < $(GEO_FILE)
	@printf '%s\n' 'Geo-partition demo applied from $(GEO_FILE)'

destroy-cluster:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(CLUSTER_COMPOSE_FILE) down

destroy-cluster-all:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(CLUSTER_COMPOSE_FILE) down -v

restart-cluster: destroy-cluster init-cluster

init-cluster-ha:
	@mkdir -p "$(DOCKER_CONFIG_DIR)"
	@$(PODMAN) machine start >/dev/null 2>&1 || true
	@$(COMPOSE_ENV) $(COMPOSE) -f $(CLUSTER_HA_COMPOSE_FILE) up -d
	@$(MAKE) wait-cluster-ha
	@$(MAKE) configure-cluster-ha

wait-cluster-ha:
	@i=1; \
	until $(PODMAN) exec $(CLUSTER_HA_CONTAINER) ysqlsh -h $(CLUSTER_HA_DB_HOST) -p 5433 -U yugabyte -d yugabyte -c 'select 1' >/dev/null 2>&1; do \
	  if [ $$i -gt 60 ]; then \
	    printf '%s\n' 'YugabyteDB HA cluster is not ready after 300 seconds'; \
	    exit 1; \
	  fi; \
	  printf '%s\n' 'Waiting for YugabyteDB HA cluster YSQL...'; \
	  i=$$((i + 1)); \
	  sleep 5; \
	done
	@printf '%s\n' 'YugabyteDB HA cluster YSQL is ready'

configure-cluster-ha:
	@$(YB_ADMIN_HA) modify_placement_info cloud1.region1.az1:1,cloud1.region2.az2:1,cloud1.region3.az3:1 3 >/dev/null
	@printf '%s\n' 'HA cluster placement info configured with RF=3'

health-cluster-ha:
	@curl -fsS http://127.0.0.1:27000 >/dev/null
	@printf '%s\n' 'HA Master1 UI OK: http://127.0.0.1:27000'
	@curl -fsS http://127.0.0.1:27001 >/dev/null
	@printf '%s\n' 'HA Master2 UI OK: http://127.0.0.1:27001'
	@curl -fsS http://127.0.0.1:27002 >/dev/null
	@printf '%s\n' 'HA Master3 UI OK: http://127.0.0.1:27002'
	@curl -fsS http://127.0.0.1:29000 >/dev/null
	@printf '%s\n' 'HA TServer1 UI OK: http://127.0.0.1:29000'
	@curl -fsS http://127.0.0.1:29001 >/dev/null
	@printf '%s\n' 'HA TServer2 UI OK: http://127.0.0.1:29001'
	@curl -fsS http://127.0.0.1:29002 >/dev/null
	@printf '%s\n' 'HA TServer3 UI OK: http://127.0.0.1:29002'
	@$(PODMAN) exec $(CLUSTER_HA_CONTAINER) ysqlsh -h $(CLUSTER_HA_DB_HOST) -p 5433 -U yugabyte -d yugabyte -c 'select 1' >/dev/null
	@printf '%s\n' 'HA YSQL OK: 127.0.0.1:25433'

status-cluster-ha:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(CLUSTER_HA_COMPOSE_FILE) ps

logs-cluster-ha:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(CLUSTER_HA_COMPOSE_FILE) logs -f

query-cluster-ha:
	@$(MAKE) wait-cluster-ha
	@$(PODMAN) exec -i $(CLUSTER_HA_CONTAINER) ysqlsh -h $(CLUSTER_HA_DB_HOST) -p 5433 -U yugabyte -d yugabyte -c "$(CLUSTER_HA_SQL)"

geo-cluster-ha:
	@$(MAKE) wait-cluster-ha
	@$(CLUSTER_HA_YSQL_BATCH) -f - < $(GEO_FILE)
	@printf '%s\n' 'Geo-partition demo applied to HA cluster from $(GEO_FILE)'

failover-test-ha:
	@$(MAKE) wait-cluster-ha
	@printf '%s\n' 'Stopping HA node $(CLUSTER_HA_FAIL_NODE) to simulate failure...'
	@$(PODMAN) stop $(CLUSTER_HA_FAIL_NODE) >/dev/null
	@sleep 5
	@$(PODMAN) exec $(CLUSTER_HA_CONTAINER) ysqlsh -h $(CLUSTER_HA_DB_HOST) -p 5433 -U yugabyte -d yugabyte -c 'select 1' >/dev/null
	@printf '%s\n' 'HA query still works after one node failure'
	@printf '%s\n' 'Starting HA node $(CLUSTER_HA_FAIL_NODE) again...'
	@$(PODMAN) start $(CLUSTER_HA_FAIL_NODE) >/dev/null
	@sleep 5
	@curl -fsS http://127.0.0.1:29002 >/dev/null
	@printf '%s\n' 'HA failed node recovered: $(CLUSTER_HA_FAIL_NODE)'

destroy-cluster-ha:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(CLUSTER_HA_COMPOSE_FILE) down

destroy-cluster-ha-all:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(CLUSTER_HA_COMPOSE_FILE) down -v

restart-cluster-ha: destroy-cluster-ha init-cluster-ha

destroy-all-lab:
	@$(COMPOSE_ENV) $(COMPOSE) -f $(COMPOSE_FILE) down -v >/dev/null 2>&1 || true
	@$(COMPOSE_ENV) $(COMPOSE) -f $(CLUSTER_COMPOSE_FILE) down -v >/dev/null 2>&1 || true
	@$(COMPOSE_ENV) $(COMPOSE) -f $(CLUSTER_HA_COMPOSE_FILE) down -v >/dev/null 2>&1 || true
	@printf '%s\n' 'All lab environments removed'
