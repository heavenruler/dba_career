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
