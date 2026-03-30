# YugabyteDB Local Test (Podman)

Compose file: `compose.yml`

## Make Targets

```bash
=== 單機 POC ===
make init                 啟動單機 YugabyteDB POC 環境
make wait                 等待單機 YSQL 就緒
make health               檢查單機 YSQL、7000、9000 健康狀態
make status               顯示單機 compose 與 port 狀態
make logs                 追蹤單機 YugabyteDB logs
make sql                  進入單機 ysqlsh
make query                執行單機查詢，預設查 demo.accounts LIMIT 5
make seed                 套用 init.sql 範例資料
make restart              重建單機環境
make destroy              停止單機環境
make destroy-all          停止單機環境並刪除 volume

=== 三區模擬叢集 ===
make init-cluster         啟動 1 master + 3 tserver 三區模擬叢集
make wait-cluster         等待三區模擬叢集 YSQL 就緒
make health-cluster       檢查三區模擬叢集 YSQL 與 UI 健康狀態
make status-cluster       顯示三區模擬叢集 compose 狀態
make logs-cluster         追蹤三區模擬叢集 logs
make query-cluster        查詢三區模擬叢集節點拓樸
make geo-cluster          套用 geo-partition 範例 SQL 到三區模擬叢集
make restart-cluster      重建三區模擬叢集
make destroy-cluster      停止三區模擬叢集
make destroy-cluster-all  停止三區模擬叢集並刪除 volumes

=== HA 模擬叢集 ===
make init-cluster-ha      啟動 3 master + 3 tserver HA 模擬叢集
make wait-cluster-ha      等待 HA 模擬叢集 YSQL 就緒
make configure-cluster-ha 對 HA 模擬叢集套用 RF=3 placement
make health-cluster-ha    檢查 HA 模擬叢集 YSQL 與 UI 健康狀態
make status-cluster-ha    顯示 HA 模擬叢集 compose 狀態
make logs-cluster-ha      追蹤 HA 模擬叢集 logs
make query-cluster-ha     查詢 HA 模擬叢集節點拓樸
make geo-cluster-ha       套用 geo-partition 範例 SQL 到 HA 模擬叢集
make failover-test-ha     模擬 HA 節點故障並驗證查詢仍可用
make restart-cluster-ha   重建 HA 模擬叢集
make destroy-cluster-ha   停止 HA 模擬叢集
make destroy-cluster-ha-all 停止 HA 模擬叢集並刪除 volumes

=== 全域清理 ===
make destroy-all-lab      一次清掉單機、cluster、HA 全部實驗環境
```

## 架構說明

本目錄提供 3 種 YugabyteDB POC 拓樸：

### 1. 單機 POC

- Compose: `compose.yml`
- 角色：`yugabyted`
- 用途：本機快速驗證 YSQL / UI / seed data
- 對外 port：`5433`、`7000`、`9000`、`9042`

### 2. 三區模擬叢集

- Compose: `compose.cluster.yml`
- 角色：`1 master + 3 tserver`
- Zone：`region1/az1`、`region2/az2`、`region3/az3`
- 用途：模擬多地資料分布、geo-partition、基本拓樸查詢
- 對外 port：
  - Master UI: `17000`
  - TServer UI: `19000`、`19001`、`19002`
  - YSQL: `15433`、`15434`、`15435`

### 3. HA 模擬叢集

- Compose: `compose.cluster.ha.yml`
- 角色：`3 master + 3 tserver`
- Zone：`region1/az1`、`region2/az2`、`region3/az3`
- 用途：模擬 RF=3 placement、節點故障測試、geo-partition on HA cluster
- 對外 port：
  - Master UI: `27000`、`27001`、`27002`
  - TServer UI: `29000`、`29001`、`29002`
  - YSQL: `25433`、`25434`、`25435`

### 資料放置與 geo-partition

- `geo-partition.sql` 透過 `TABLESPACE ... replica_placement` 指定資料放置 zone
- `PARTITION BY LIST (geo_partition)` 決定哪類資料進哪個 partition
- `PARTITION ... TABLESPACE ts_azX` 把 partition 綁到對應 zone 的 tablespace
- 這表示「資料放在哪裡」，不代表應用程式流量會自動導到對應 zone

## 指令速查表

### 單機 POC

```bash
make init
make health
make seed
make query
make sql
make destroy
```

### 三區模擬叢集

```bash
make init-cluster
make health-cluster
make query-cluster
make geo-cluster
make destroy-cluster
```

### HA 模擬叢集

```bash
make init-cluster-ha
make health-cluster-ha
make query-cluster-ha
make geo-cluster-ha
make failover-test-ha
make destroy-cluster-ha
```

### 全域清理

```bash
make destroy-all-lab
```

## Start

```bash
podman machine start
mkdir -p /tmp/podman-docker-config
DOCKER_CONFIG=/tmp/podman-docker-config podman compose up -d
```

## Check

```bash
make health
DOCKER_CONFIG=/tmp/podman-docker-config podman compose ps
DOCKER_CONFIG=/tmp/podman-docker-config podman compose logs -f yugabytedb
```

## Seed

```bash
make seed
```

Seed file:

- `init.sql`
- Creates schema `demo`
- Creates table `demo.accounts`
- Upserts sample rows

## Query

Default query:

```bash
make query
```

Custom query:

```bash
make query SQL="SELECT * FROM demo.accounts LIMIT 5;"
```

## Cluster Simulation

Purpose:

- Simulate a multi-site YSQL cluster on one laptop
- 1 master + 3 tservers
- 3 zones: `region1/az1`, `region2/az2`, `region3/az3`

Commands:

```bash
make init-cluster
make status-cluster
make health-cluster
make query-cluster
make destroy-cluster
```

Ports:

- Master UI: `17000`
- TServer AZ1 UI: `19000`
- TServer AZ2 UI: `19001`
- TServer AZ3 UI: `19002`
- YSQL AZ1: `15433`
- YSQL AZ2: `15434`
- YSQL AZ3: `15435`

Notes:

- This is a local simulation for PoC only, not a production-grade HA control plane.
- Local resource usage is higher than single-node mode; if startup is slow, increase Podman machine memory first.

## Geo Partition Demo

Apply on the 3-zone cluster:

```bash
make geo-cluster
```

SQL file:

- `geo-partition.sql`
- Creates 3 tablespaces: `ts_az1`, `ts_az2`, `ts_az3`
- Creates `demo_geo.bank_txn` list partition table
- Binds partitions to per-zone tablespaces
- Inserts sample rows and prints placement/result summary

## HA Cluster Simulation

Purpose:

- Simulate `3 master + 3 tserver` YSQL HA cluster on one laptop
- 3 master zones: `region1/az1`, `region2/az2`, `region3/az3`
- 3 tserver zones: `region1/az1`, `region2/az2`, `region3/az3`

Commands:

```bash
make init-cluster-ha
make status-cluster-ha
make health-cluster-ha
make query-cluster-ha
make geo-cluster-ha
make failover-test-ha
make destroy-cluster-ha
```

Ports:

- Master1 UI: `27000`
- Master2 UI: `27001`
- Master3 UI: `27002`
- TServer1 UI: `29000`
- TServer2 UI: `29001`
- TServer3 UI: `29002`
- YSQL TServer1: `25433`
- YSQL TServer2: `25434`
- YSQL TServer3: `25435`

Notes:

- `make init-cluster-ha` includes `yb-admin modify_placement_info ... RF=3`.
- `make failover-test-ha` 會暫停 `yb-tserver-ha-3`，驗證查詢仍可執行，再自動拉回節點。
- Local resource usage is significantly higher than the single-master cluster mode.
- If startup fails, stop older lab environments first: `make destroy` and `make destroy-cluster`.

## Full Cleanup

```bash
make destroy-all-lab
```

功能：

- 停止並刪除單機環境
- 停止並刪除 1 master + 3 tserver cluster
- 停止並刪除 3 master + 3 tserver HA cluster
- 刪除對應 volumes

## 已知問題

### 執行環境

- 本機 `podman compose` 目前會呼叫外部 compose provider，因此需保留 `DOCKER_CONFIG=/tmp/podman-docker-config`，避免卡在不存在的 `docker-credential-desktop`。
- `make wait`、`make wait-cluster`、`make wait-cluster-ha` 以實際 `YSQL select 1` 為 ready 條件，因此會比單純看容器 `Up` 更慢，這是預期行為。

### Compose 與容器狀態

- `make destroy-cluster` 後若仍有單機版 `yugabytedb-local` 在跑，可能看到 `Network ... Resource is still in use` 或 orphan container 警告；通常不影響使用。
- `make status-cluster` / `make status-cluster-ha` 在目前 compose project 設定下，可能同時看到其他 lab 容器，不一定只顯示單一拓樸。

### Geo-partition 與資料放置

- `geo-partition.sql` 的 tablespace 使用 `num_replicas=1`，用途是展示資料落點，不代表正式多區高可用配置。
- `TABLESPACE ... replica_placement` 只控制資料放置位置，不會自動把應用程式流量導到對應 zone；若要流量在地化，仍需搭配 client/driver 的 topology-aware 設定。
- 多區 schema 若 `JOIN` / `FK` 沒有把 `geo_partition` 或相同 distribution key 納入設計，查詢與寫入可能出現跨 zone 延遲。

### HA 測試限制

- `make failover-test-ha` 是單節點故障模擬，驗證的是查詢可用性，不等同正式 production failover 測試或完整 SLA 驗證。

UI:

- Master UI: http://localhost:7000
- TServer UI: http://localhost:9000

Connect:

```bash
podman exec -it yugabytedb-local ysqlsh -h yugabytedb -p 5433 -U yugabyte -d yugabyte
```

## Stop

```bash
DOCKER_CONFIG=/tmp/podman-docker-config podman compose down
```

Remove data volume:

```bash
DOCKER_CONFIG=/tmp/podman-docker-config podman compose down -v
```

## Notes

- Local test only; the image is intentionally left as `latest` for quick setup.
- For repeatable tests, pin the image tag before sharing with others.
- This host currently uses an external compose provider under `podman compose`, so `DOCKER_CONFIG=/tmp/podman-docker-config` avoids the missing `docker-credential-desktop` helper.
- `advertise_address` uses container hostname `yugabytedb` so host-side port forwarding for `7000/9000` works correctly.
