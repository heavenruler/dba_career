# poc-db-architect-quickstart

Scenario-driven 的本機資料庫架構 PoC 實驗室，專為 macOS + Podman 設計。

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
make up SCENARIO=<name>
make down SCENARIO=<name>
make reset SCENARIO=<name>
make verify SCENARIO=<name>
make logs SCENARIO=<name>
```

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

## Login Instructions

請直接看各 scenario 下的 `login.md`：

- `scenarios/redis-standalone/login.md`
- `scenarios/redis-replication/login.md`
- `scenarios/redis-sentinel/login.md`
- `scenarios/redis-cluster/login.md`

## Verify Commands

每個 scenario 都有獨立驗證腳本：

- `scenarios/redis-standalone/verify.sh`
- `scenarios/redis-replication/verify.sh`
- `scenarios/redis-sentinel/verify.sh`
- `scenarios/redis-cluster/verify.sh`

可透過 `make verify SCENARIO=<name>` 執行。

## 擴充新 Scenario 的標準步驟

1. 新增 `scenarios/<new-scenario>/kube.yaml`
2. 新增 `scenarios/<new-scenario>/login.md`
3. 新增 `scenarios/<new-scenario>/verify.sh`
4. 以 `make up/down/reset/verify SCENARIO=<new-scenario>` 驗證流程

建議下一步可新增：

- `mysql-standalone`
- `mysql-group-replication`
- `postgres-ha`
- `mongo-replica-set`
- `tidb-local`
