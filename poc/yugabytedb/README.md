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

[!](https://docs.yugabyte.com/images/architecture/layered-architecture.png)
[Reference](https://docs.yugabyte.com/stable/architecture/)

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

## JOIN 與 FK 對分散式資料庫的影響

### 核心概念

在 YugabyteDB 這類分散式 SQL 資料庫中：

- `JOIN` 與 `FK` 不只是 SQL 語法問題
- 本質上是查詢與驗證是否需要跨 tablet、跨節點、跨 zone
- schema 結構會直接影響延遲、吞吐、交易衝突與擴展性

簡單說：

- `JOIN` 主要影響查詢成本
- `FK` 主要影響寫入成本
- schema key 設計不對時，系統雖然能跑，但會付出跨網路與分散式交易的代價

### JOIN 的影響

`JOIN` 成本主要取決於：

- join key 是否對齊
- 資料是否落在相近的 shard / tablet
- 是否跨 zone

常見情況：

#### 1. Join key 對齊

例如 parent / child 都用相同業務 key 與相同 geo key：

```sql
accounts(account_id, geo_partition)
bank_txn(account_id, geo_partition, ...)
```

優點：

- 查詢比較容易命中相近資料位置
- distributed join 成本較低
- 網路搬移較少

#### 2. Join key 不對齊

例如：

- parent 用 `account_id HASH`
- child 用 `txn_id HASH`
- 查詢卻常用 `JOIN account_id`

可能結果：

- 系統要從多個 tablet 拉資料再 join
- 查詢 latency 上升
- 大查詢容易放大 hash join / sort join 成本

#### 3. 跨 zone join

若一張表的資料主要落在 `az1`，另一張表的資料在 `az2`：

- join 時可能產生跨 zone 存取
- WAN / cross-zone RTT 會直接反映在查詢時間上
- 小查詢變慢，大查詢更明顯

### FK 的影響

`FK` 主要影響寫入與刪除。

每次 `INSERT` / `UPDATE` child 時，系統要驗證：

- parent key 是否存在
- parent 被 `DELETE` / `UPDATE` 時是否有 child 依賴

在單機 PostgreSQL：

- 通常只是本機索引檢查

在分散式資料庫：

- 這個檢查可能是一次分散式讀取
- 若 parent / child 不在同 shard 或同 zone，會增加網路往返
- 高併發下更容易形成 contention

實務上：

- `FK` 很有價值，但不是零成本
- 核心交易表可以保留 FK
- 大量事件流、流水明細表要評估是否全部都需要 FK

### Schema 結構最關鍵的地方

#### 1. 主鍵與 distribution key

主鍵不只影響唯一性，也影響：

- shard 分布
- join 局部性
- FK 驗證成本

不理想例子：

```sql
CREATE TABLE accounts (
  account_id bigint PRIMARY KEY
);

CREATE TABLE bank_txn (
  txn_id bigint PRIMARY KEY,
  account_id bigint NOT NULL REFERENCES accounts(account_id)
);
```

問題：

- `accounts` 與 `bank_txn` 很可能分布在不同 tablet
- `JOIN` 與 `FK` 驗證都可能跨節點

較佳例子：

```sql
CREATE TABLE accounts (
  account_id bigint NOT NULL,
  geo_partition text NOT NULL,
  account_name text NOT NULL,
  PRIMARY KEY (account_id HASH, geo_partition)
);

CREATE TABLE bank_txn (
  txn_id bigint NOT NULL,
  account_id bigint NOT NULL,
  geo_partition text NOT NULL,
  amount numeric(12,2) NOT NULL,
  PRIMARY KEY (account_id HASH, txn_id, geo_partition),
  FOREIGN KEY (account_id, geo_partition)
    REFERENCES accounts(account_id, geo_partition)
);
```

優點：

- parent / child 使用相同業務 key 與 geo key
- join 條件與資料分布方向較一致
- FK 驗證比較有機會在相近資料位置完成

#### 2. 是否把 geo key 放進 PK / FK

在多區場景，這非常重要。

若沒放：

- 系統無法保證 parent / child 同區
- 邏輯上屬於 `AZ1` 的資料，驗證可能跑去 `AZ2`

若有放：

- schema 本身就表達了區域邊界
- parent / child 關係更容易在同區完成
- 比較符合 geo-partition 的設計目標

#### 3. 分區方式是否對齊查詢模式

如果常見查詢是：

```sql
SELECT *
FROM bank_txn
WHERE geo_partition = 'AZ1'
  AND account_id = 10001;
```

那 schema 最好讓：

- `geo_partition`
- `account_id`

成為主要定位條件。

否則即使功能正確，查詢路徑也可能很分散。

### 在 YugabyteDB 上的具體影響

#### 對 JOIN

- key 對齊：查詢較穩定
- key 不對齊：distributed join 成本升高
- 跨 zone：查詢 latency 增加
- 大表 join：更容易放大 network shuffle 與記憶體使用

#### 對 FK

- parent / child 同 key、同 zone：寫入成本較低
- parent / child 分散：每次 child 寫入都可能遠端驗證
- delete parent：若 child 多且分散，成本更高

#### 對交易

- 單筆交易若碰到多 tablet、多 zone
- 兩階段提交成本更高
- 衝突、重試與延遲都更明顯

#### 對擴展性

- 若 schema 天然造成 cross-shard join / FK
- 節點變多不一定更快
- 有時只是把查詢壓力分散到更多網路 hops

### 設計建議

#### 1. 先以 access pattern 設計 schema

先回答：

- 最常查什麼
- 最常寫什麼
- 哪些資料必須同區
- 哪些關聯真的需要 FK

不要只照傳統 ERD 直接搬進分散式資料庫。

#### 2. Parent / child 盡量共用 distribution key

最佳做法通常是：

- child FK 包含 parent 的 distribution key
- 多區時把 `geo_partition` 納入 FK

#### 3. 常 join 的表要對齊 join key

避免這種情況：

- parent hash by `account_id`
- child hash by `txn_id`
- 卻常常 `JOIN account_id`

這通常代表查詢模式與資料分布方向不一致。

#### 4. FK 用在重要一致性，不要全部濫用

建議：

- 核心主資料、交易資料可保留 FK
- 高吞吐明細、事件流資料要評估寫入成本

#### 5. Geo-partition 是資料放置，不是自動流量導向

即使 partition 已經放到 `az1`：

- client 若一直連 `az3`
- driver 若不支援 topology-aware

仍然可能發生跨區流量。

所以正式環境還需要：

- topology-aware driver
- 合理的 service discovery / load balancer
- 與資料落點一致的應用部署策略

### 一句話總結

如果 schema 讓：

- join key 不一致
- FK 沒帶 geo key
- parent / child 跨區隨機分布

那 YugabyteDB 會能跑，但通常會變成：

- 查詢更慢
- 寫入更慢
- 交易更重

如果 schema 讓：

- parent / child 用同一組分布 key
- geo key 進 PK / FK
- 常用 join 與資料放置方向一致

那分散式結構才會真正發揮效果。

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
