# Architecture Overview

本專案以「情境 scenario」作為主軸，而非綁定單一資料庫產品。

- `redis-standalone`: 單機節點
- `redis-replication`: 主從複寫
- `redis-sentinel`: 高可用哨兵
- `redis-cluster`: 分散式叢集

擴充時請依相同目錄結構新增 `scenarios/<new-scenario>/`，並提供：

1. `kube.yaml`
2. `login.md`
3. `verify.sh`
