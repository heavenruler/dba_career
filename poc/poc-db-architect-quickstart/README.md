# poc-db-architect-quickstart

Scenario-driven 的本機資料庫架構 PoC 實驗室，專為 macOS + Podman 設計。

目前支援 Redis、MySQL standalone 與 4 類 MySQL HA scenario。

## Quick Start (5 分鐘內)

```bash
git clone <your-repo-url> poc-db-architect-quickstart
cd poc-db-architect-quickstart

brew install podman
podman machine init
podman machine start

make init
make up SCENARIO=redis-standalone
make verify SCENARIO=redis-standalone

make up SCENARIO=mysql-standalone MYSQL_VERSION=8.4
make verify SCENARIO=mysql-standalone
```

驗證成功後可直接登入：

```bash
redis-cli -h 127.0.0.1 -p 6379
```

## Prerequisites

- macOS (Apple Silicon 或 Intel)
- Podman 4.x 以上
- `make`
- (可選) host 端 `redis-cli`，若無可用 `podman exec` 進容器
- (可選) host 端 `mysql` client，若無可用 `podman exec` 進容器

## 專案目錄

```text
poc-db-architect-quickstart/
├── README.md
├── Makefile
├── .env.example
├── bin/
│   ├── init.sh
│   ├── up.sh
│   ├── down.sh
│   ├── reset.sh
│   └── doctor.sh
├── docs/
│   ├── architecture/
│   │   └── overview.md
│   ├── login/
│   │   └── README.md
│   └── operations/
│       └── README.md
├── scenarios/
│   ├── redis-standalone/
│   │   ├── kube.yaml
│   │   ├── login.md
│   │   └── verify.sh
│   ├── redis-replication/
│   │   ├── kube.yaml
│   │   ├── login.md
│   │   └── verify.sh
│   ├── redis-sentinel/
│   │   ├── kube.yaml
│   │   ├── login.md
│   │   └── verify.sh
│   ├── mysql-standalone/
│   │   ├── kube.yaml
│   │   ├── login.md
│   │   └── verify.sh
│   ├── mysql-replication/
│   │   ├── kube.yaml
│   │   ├── login.md
│   │   └── verify.sh
│   ├── mysql-proxysql/
│   │   ├── kube.yaml
│   │   ├── login.md
│   │   └── verify.sh
│   ├── mysql-group-replication/
│   │   ├── kube.yaml
│   │   ├── login.md
│   │   └── verify.sh
│   ├── mysql-innodb-cluster/
│   │   ├── kube.yaml
│   │   ├── login.md
│   │   └── verify.sh
│   └── redis-cluster/
│       ├── kube.yaml
│       ├── login.md
│       └── verify.sh
└── volumes/
```

## Scenario 操作

### 啟動

```bash
make up SCENARIO=redis-standalone
make up SCENARIO=redis-replication
make up SCENARIO=redis-sentinel
make up SCENARIO=redis-cluster

make up SCENARIO=redis-standalone REDIS_VERSION=6.0-alpine
make up SCENARIO=redis-standalone REDIS_VERSION=7.0-alpine
make up SCENARIO=redis-standalone REDIS_VERSION=8.0-alpine

make up SCENARIO=mysql-standalone MYSQL_VERSION=5.7
make up SCENARIO=mysql-standalone MYSQL_VERSION=8.0
make up SCENARIO=mysql-standalone MYSQL_VERSION=8.4
make up SCENARIO=mysql-standalone MYSQL_VERSION=9.6

make up SCENARIO=mysql-replication MYSQL_VERSION=8.4
make up SCENARIO=mysql-proxysql MYSQL_VERSION=8.4 PROXYSQL_VERSION=2.6.6
make up SCENARIO=mysql-group-replication MYSQL_VERSION=8.4
make up SCENARIO=mysql-innodb-cluster MYSQL_VERSION=8.4
```

### 停止

```bash
make down SCENARIO=redis-standalone
```

### 重置 (刪除情境資料夾 volume 後重建)

```bash
make reset SCENARIO=redis-standalone
```

### 驗證

```bash
make verify SCENARIO=redis-standalone
make verify SCENARIO=redis-replication
make verify SCENARIO=redis-sentinel
make verify SCENARIO=redis-cluster
```

### Logs

```bash
make logs SCENARIO=redis-standalone
```

## Makefile 介面

```bash
make up SCENARIO=<name> [REDIS_VERSION=<version>] [MYSQL_VERSION=<version>] [PROXYSQL_VERSION=<version>]
make down SCENARIO=<name>
make reset SCENARIO=<name> [REDIS_VERSION=<version>] [MYSQL_VERSION=<version>] [PROXYSQL_VERSION=<version>]
make verify SCENARIO=<name>
make logs SCENARIO=<name>
```

目前 `make` 可啟用的 `SCENARIO` 如下：

- `redis-standalone`: 單機 Redis
- `redis-replication`: Redis 主從複寫
- `redis-sentinel`: Redis Sentinel 高可用
- `redis-cluster`: Redis Cluster 分散式叢集
- `mysql-standalone`: 單機 MySQL
- `mysql-replication`: MySQL 非同步複寫
- `mysql-proxysql`: MySQL + ProxySQL
- `mysql-group-replication`: MySQL Group Replication
- `mysql-innodb-cluster`: MySQL InnoDB Cluster

例如：

```bash
make up SCENARIO=redis-standalone
make up SCENARIO=redis-replication
make up SCENARIO=redis-standalone REDIS_VERSION=6.0-alpine
make up SCENARIO=redis-standalone REDIS_VERSION=7.0-alpine
make up SCENARIO=redis-standalone REDIS_VERSION=8.0-alpine
make up SCENARIO=mysql-standalone MYSQL_VERSION=8.4
make up SCENARIO=mysql-standalone MYSQL_VERSION=9.6
```

版本指定規則：

- 預設是 `REDIS_VERSION=7.2-alpine`
- 可在 `make up` 時覆蓋，例如 `6.0-alpine`、`7.0-alpine`、`8.0-alpine`
- 預設是 `MYSQL_VERSION=8.4`
- MySQL 可指定 `5.7`、`8.0`、`8.4`、`9.6`
- 預設是 `PROXYSQL_VERSION=2.6.6`
- `reset` 若要維持同版本，請一併帶上對應版本變數
- `down/verify/logs` 仍以 `SCENARIO` 為主，不需要重複指定版本

## 架構拓樸圖

### 1) redis-standalone

```text
+--------------------+
| redis-standalone-1 |
| port: 6379         |
+--------------------+
```

### 2) redis-replication

```text
redis-replication-master-1 (6380)
            |
   +--------+--------+
   |                 |
redis-replication- redis-replication-
replica-1 (6381)    replica-2 (6382)
```

### 3) redis-sentinel

```text
redis-sentinel-node-1 (26379)
redis-sentinel-node-2 (26380)  ---> monitor mymaster(6390)
redis-sentinel-node-3 (26381)

mymaster: redis-sentinel-master-1 (6390)
replicas: redis-sentinel-replica-1 (6391), redis-sentinel-replica-2 (6392)
```

### 4) redis-cluster

```text
redis-cluster-node-1 (7001)
redis-cluster-node-2 (7002)
redis-cluster-node-3 (7003)  -> masters
redis-cluster-node-4 (7004)
redis-cluster-node-5 (7005)
redis-cluster-node-6 (7006)  -> replicas
```

### 5) mysql-standalone

```text
+-----------------+
| mysql-standalone|
| port: 3306      |
+-----------------+
```

### 6) mysql-replication

```text
mysql-replication-master-1 (3307)
            |
    +-------+-------+
    |               |
mysql-replication mysql-replication
replica-1 (3308)   replica-2 (3309)
```

### 7) mysql-proxysql

```text
clients -> proxysql (6033)
             |
     +-------+-------+
     |               |
  writer (3310)   readers (3311, 3312)
```

### 8) mysql-group-replication

```text
mysql-group-replication-node-1 (3320)
mysql-group-replication-node-2 (3321)
mysql-group-replication-node-3 (3322)
```

### 9) mysql-innodb-cluster

```text
mysql-router (6446)
      |
  InnoDB Cluster nodes (3330, 3331, 3332)
```

## MySQL HA 說明

- `mysql-replication`
- `mysql-group-replication`
- `mysql-innodb-cluster`
- `mysql-proxysql`

目前專案已加入上述 4 類 scenario。

驗證狀態：

- `mysql-replication`: 已實測通過 `up/reset/verify/down`
- `mysql-proxysql`: 已實測通過 `up/reset/verify/down`
- `mysql-group-replication`: 已完成 scenario 與 bootstrap，但 `8.4` 仍在調整加入第 3 節點穩定性
- `mysql-innodb-cluster`: 已完成 scenario 骨架，依賴 group replication 穩定後再做完整驗證

版本規劃原則：

- `mysql-standalone`: `5.7`、`8.0`、`8.4`、`9.6`
- `mysql-replication`: 優先評估 `8.0`、`8.4`、`9.6`
- `mysql-group-replication`: 優先評估 `8.0`、`8.4`、`9.6`
- `mysql-innodb-cluster`: 優先評估 `8.0`、`8.4`、`9.6`
- `mysql-proxysql`: ProxySQL 版本需獨立定版，不直接跟 `MYSQL_VERSION` 綁定

風險說明：

- `MySQL 5.7` 已 EOL，較適合做升級與相容性 PoC
- `group replication` 與 `innodb cluster` 在 `5.7` 的維運價值較低，建議主力放在 `8.0+`
- `innodb cluster` 會額外依賴 `mysqlsh` / `mysql-router`，版本相容性需個別驗證
- `proxysql` 屬於資料庫前代理層，驗證項目會與 replication 狀態聯動

## Login Instructions

請直接看各 scenario 下的 `login.md`：

- `scenarios/redis-standalone/login.md`
- `scenarios/redis-replication/login.md`
- `scenarios/redis-sentinel/login.md`
- `scenarios/redis-cluster/login.md`
- `scenarios/mysql-standalone/login.md`
- `scenarios/mysql-replication/login.md`
- `scenarios/mysql-proxysql/login.md`
- `scenarios/mysql-group-replication/login.md`
- `scenarios/mysql-innodb-cluster/login.md`

## Verify Commands

每個 scenario 都有獨立驗證腳本：

- `scenarios/redis-standalone/verify.sh`
- `scenarios/redis-replication/verify.sh`
- `scenarios/redis-sentinel/verify.sh`
- `scenarios/redis-cluster/verify.sh`
- `scenarios/mysql-standalone/verify.sh`
- `scenarios/mysql-replication/verify.sh`
- `scenarios/mysql-proxysql/verify.sh`
- `scenarios/mysql-group-replication/verify.sh`
- `scenarios/mysql-innodb-cluster/verify.sh`

可透過 `make verify SCENARIO=<name>` 執行。

## 擴充新 Scenario 的標準步驟

1. 新增 `scenarios/<new-scenario>/kube.yaml`
2. 新增 `scenarios/<new-scenario>/login.md`
3. 新增 `scenarios/<new-scenario>/verify.sh`
4. 以 `make up/down/reset/verify SCENARIO=<new-scenario>` 驗證流程

建議下一步可新增：

- `mysql-group-replication`
- `postgres-ha`
- `mongo-replica-set`
- `tidb-local`
