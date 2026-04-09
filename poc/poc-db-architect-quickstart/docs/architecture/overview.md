# Architecture Overview

本專案以「情境 scenario」作為主軸，而非綁定單一資料庫產品。

- `redis-standalone`: 單機節點
- `redis-replication`: 主從複寫
- `redis-sentinel`: 高可用哨兵
- `redis-cluster`: 分散式叢集
- `mysql-standalone`: 單機 MySQL
- `mysql-replication`: MySQL 非同步複寫
- `mysql-proxysql`: MySQL + ProxySQL
- `mysql-group-replication`: MySQL Group Replication
- `mysql-innodb-cluster`: MySQL InnoDB Cluster

已確認後續規劃的 MySQL HA 類別：

- `mysql-replication`
- `mysql-group-replication`
- `mysql-innodb-cluster`
- `mysql-proxysql`

請參考 `docs/architecture/mysql-ha-roadmap.md`。

擴充時請依相同目錄結構新增 `scenarios/<new-scenario>/`，並提供：

1. `kube.yaml`
2. `login.md`
3. `verify.sh`
