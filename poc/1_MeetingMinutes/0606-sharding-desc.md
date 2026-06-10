# 2026-06-06 Schema 如何控制資料分散

## 總覽

| DB | 底層切分單位 | 主要切分邏輯 | 本 PoC 使用方式 | 重點 |
|---|---|---|---|---|
| TiDB | Region | Range-based key space | `SPLIT TABLE ... BY (...)` | 用明確 key boundary 切 3 regions |
| CockroachDB | Range | Range-based key space | `ALTER TABLE ... SPLIT AT VALUES (...)` | 用明確 key boundary 切 3 ranges |
| YugabyteDB | Tablet | Hash-based 為主 | `SPLIT INTO N TABLETS` | 指定 tablet 數，不指定 range boundary |

## TiDB：Range-based Region

TiDB 的資料底層放在 TiKV Region 裡。Region 是 key range，所以本質是 range-based sharding。

本 PoC 不是靠自動 split，而是在 prepare 後手動切：

```sql
SPLIT TABLE warehouse  BY (43), (86);
SPLIT TABLE district   BY (43, 1), (86, 1);
SPLIT TABLE customer   BY (43, 1, 1), (86, 1, 1);
SPLIT TABLE stock      BY (43, 1), (86, 1);
SPLIT TABLE item       BY (33334), (66667);
```

概念：

```text
warehouse
  Region 1: w_id < 43
  Region 2: 43 <= w_id < 86
  Region 3: w_id >= 86
```

適合用來明確控制 `1 shard` / `3 shards` 差異。

## CockroachDB：Range-based Range

CockroachDB 的資料切分單位是 Range，也是依 primary key / index key 的排序空間切開。

本 PoC 用：

```sql
ALTER TABLE warehouse SPLIT AT VALUES (43), (86);
ALTER TABLE district  SPLIT AT VALUES (43, 1), (86, 1);
ALTER TABLE customer  SPLIT AT VALUES (43, 1, 1), (86, 1, 1);
```

概念和 TiDB 接近：

```text
table keyspace
  Range 1
  Range 2
  Range 3
```

差別是 CockroachDB 的 range 還會牽涉 replica 與 leaseholder 分布，所以除了 shard count，也要看 replica / leaseholder placement。

## YugabyteDB：Hash-based Tablet 為主

YugabyteDB 的 YSQL table 常見預設是 hash-sharded tablet。PoC 這次不是指定 `(43), (86)` 這種 range boundary，而是在 schema pre-create 時指定 tablet 數：

```sql
CREATE TABLE warehouse (
  w_id INT PRIMARY KEY,
  ...
) SPLIT INTO 3 TABLETS;
```

概念：

```text
hash(primary key) -> tablet 1
hash(primary key) -> tablet 2
hash(primary key) -> tablet 3
```

所以 YugabyteDB 這次的控制點是「建立幾個 tablets」，不是「用哪幾個 key value 當切點」。

## 重要差異

| 問題 | TiDB | CockroachDB | YugabyteDB |
|---|---|---|---|
| 是 hash 還是 range？ | Range | Range | Hash 為主 |
| shard boundary 是否可見？ | 可見，`BY (...)` | 可見，`SPLIT AT VALUES` | 不指定 boundary，只指定 tablet 數 |
| 本 PoC 何時控制？ | prepare 後 split | prepare 後 split | prepare 前 pre-create schema |
| go-tpc prepare 是否會覆寫？ | 不會，split 在 prepare 後 | 不會，split 在 prepare 後 | 不會，因 `CREATE TABLE IF NOT EXISTS` |
| 主要風險 | split point 選錯、region 不足 | range / leaseholder 分布不均 | 不能只靠預設 shard 參數推論 tablet 數 |

## PoC 使用上的結論

這次三節點測項要比較：

| Cell | 意義 |
|---|---|
| `1s1r` | 1 shard + RF1 |
| `1s3r` | 1 shard + RF3 |
| `3s1r` | 3 shards + RF1 |
| `3s3r` | 3 shards + RF3 |

因此三家都必須明確鎖定 shard 數：

- TiDB / CockroachDB：用 range split 明確切 key space。
- YugabyteDB：用 `SPLIT INTO N TABLETS` 明確建立 tablet 數。
- 不依賴 auto split / auto rebalance / default shard 推論，避免結果混入背景行為。

## Scale-out 階段要面對的事

Scale-out 不是單純「新增節點」就完成。分散式資料庫新增節點後，資料是否會移動、leader 是否會重分布、write path 是否真的吃到新節點，都取決於 sharding 策略與 rebalancing 行為。

### 不同 sharding 策略下的操作重點

| 策略 | Scale-out 要做什麼 | 需要確認什麼 |
|---|---|---|
| Range split | 新增節點後，確認既有 range / region 是否搬移到新節點 | split point 是否合理、hot range 是否仍集中、leader 是否重分布 |
| Hash / tablet split | 新增節點後，確認 tablet 是否 rebalance 到新節點 | tablet 數是否足夠、leader 是否分散、搬移是否完成 |
| Auto split / auto rebalance | 讓系統背景自動切分與搬移 | 背景行為何時觸發、是否影響 benchmark、是否留下 compaction / raft backlog |
| Manual split / pre-split | 事前或 prepare 階段明確指定 shard 數 | shard 數是否符合預期、是否需要重新 split 或重新 prepare |

### TiDB：Range / Region scale-out

TiDB 新增 TiKV node 後，PD 會依照 scheduler 將 Region / leader 搬到新節點。若只是新增節點但沒有足夠 Region，或 leader 沒有搬移，新節點不一定會立即承擔 workload。

Scale-out 時需要確認：

- Region 是否從舊 TiKV 搬到新 TiKV。
- Leader 是否分布到新 TiKV。
- Hot Region 是否仍集中在少數節點。
- PD scheduler 是否被關閉、限速或尚未收斂。
- benchmark 是否在搬移尚未完成時就開始。

主要問題：

- Range split point 若不合理，可能產生 hot range。
- 新節點加入後需要等待 leader / region balance 收斂。
- 測試期間若發生 Region move，tpmC / p99 會混入搬移成本。

### CockroachDB：Range / Leaseholder scale-out

CockroachDB 新增 node 後，range replica 與 leaseholder 會逐步 rebalancing。吞吐是否提升，不只看 range 數，也要看 leaseholder 是否分散。

Scale-out 時需要確認：

- Range replica 是否分布到新節點。
- Leaseholder 是否仍集中在原節點。
- Zone config / constraints 是否允許資料搬到新節點。
- Range split / rebalance 是否仍在進行。
- Retry / contention 是否因跨節點或跨區延遲上升。

主要問題：

- Leaseholder 不均會讓新增節點沒有實際承擔主要流量。
- Range rebalancing 期間會影響 latency。
- Serializable / retry 行為可能放大 scale-out 過程中的不穩定。

### YugabyteDB：Hash / Tablet scale-out

YugabyteDB 的 scale-out 重點是 tablet 與 tablet leader 是否搬到新 tserver。若 tablet 數太少，即使新增節點，也沒有足夠切分單位可以分散。

Scale-out 時需要確認：

- Tablet 是否搬移到新 tserver。
- Tablet leader 是否重分布。
- `SPLIT INTO N TABLETS` 的 N 是否足以支撐新增節點。
- Load balancer 是否完成 tablet move。
- RF / placement 是否允許 tablet 分布到新節點。

主要問題：

- Tablet 數不足時，新增節點無法有效分攤 workload。
- 不能只靠 `ysql_num_shards_per_tserver × tserver 數` 推論實際 tablet 數。
- Tablet move / leader balance 未完成前，benchmark 會混入搬移成本。

### Scale-out 對 PoC 的影響

| 問題 | 對結果的影響 |
|---|---|
| shard / region / tablet 數不足 | 新節點閒置，scale-out ratio 被低估 |
| leader / leaseholder 未重分布 | 寫入仍集中在舊節點，吞吐不會線性提升 |
| rebalancing 在測試中發生 | tpmC 降低、p99 上升，數據混入搬移成本 |
| auto split 行為不一致 | 三家結果不可客觀比較 |
| placement / RF 設定不一致 | replication cost 與 availability 假設不同 |

因此 scale-out 測試前應先完成 gate：

- shard / range / tablet actual count 符合預期。
- replica / RF 符合預期。
- leader / leaseholder 分布已收斂。
- auto split / auto rebalance 狀態有明確紀錄。
- 若測試目標是觀察 rebalancing 本身，需把它標成獨立測項，不可混入 baseline。
