# 2026-05-23 vm-3node-ybdb-1s1r-rc — cell 1 EXECUTE=1 result

**Cell**: `ybdb-vm-3node-1s1r-rc` （PoC-DESIGN §6.3.2 vm-3node first cell of 12）
**TPCC_TS**: `20260522T234345+0800`
**Suite duration**: 23:43:59 → 03:20:37（~3.6 hr）
**Status**: ✅ all 8 phase markers DONE (.dry-run / .gate / .gate-isolation / .prepare / .run / .collect / .db-config / .suite)
**Artifact path**: `results/yuga-tc1/S-BASE/vm-3node-1s1r-rc/ybdb-vm-3node-1s1r-rc-20260522T234345+0800/`
**Patches verified**: `commit 10db790`（P1 YBDB pre-create + P3 shard hard gate + 5 script topology-aware + Makefile detached）

---

## 1. Gate verification（PoC-DESIGN §6.3.2.3 / §7.4 / §7.5.4）

### 1.1 Dry-run gate（deploy 後 / prepare 前 anchor）

```json
{
  "rf_expected": "1", "rf_actual": "1",
  "iso_expected": "read committed", "iso_actual": "read committed",
  "yb_effective_iso": "read committed",
  "all_pass": true
}
```

### 1.2 Active isolation gate（兩層驗證 §7.4）

```json
{
  "isolation_expected": "read committed",
  "isolation_actual":   "read committed",
  "driver_actual":      "read committed",
  "yb_effective_db":     "read committed",
  "yb_effective_driver": "read committed"
}
```

> YB triple-gate（tserver `yb_enable_read_committed_isolation=true` + session + effective level）三層全 RC，無 silent SI fallback。

### 1.3 Shard hard gate（§7.5.4 — verifies P1 pre-create with SPLIT INTO 1 TABLETS）

```
table=warehouse  expected=1 actual=1 pass=true
table=district   expected=1 actual=1 pass=true
table=customer   expected=1 actual=1 pass=true
table=new_order  expected=1 actual=1 pass=true
table=orders     expected=1 actual=1 pass=true
table=order_line expected=1 actual=1 pass=true
table=stock      expected=1 actual=1 pass=true
table=item       expected=1 actual=1 pass=true
table=history    expected=1 actual=1 pass=true
overall_pass=true
```

---

## 2. Throughput matrix（5 round × 4 thread × 5 min run）

| threads | round-1 | round-2 | round-3 | round-4 | round-5 | **avg tpmC** | range |
|---:|---:|---:|---:|---:|---:|---:|---|
| 16  | 10797.2 | 10868.4 | 11360.7 | **8472.9** | 11195.4 | **10538.9** | 8472–11360 |
| 32  | 13351.2 | 14106.5 | 13861.6 | 13082.8 | 13405.4 | **13561.5** | 13082–14106 |
| 64  | **10592.0** | 13846.8 | 13478.2 | 13887.5 | 14136.2 | **13188.1** | 10592–14136 |
| 128 | 14060.1 | 13671.1 | 13787.2 | 12904.8 | 13458.7 | **13576.4** | 12904–14060 |

**異常 round**：
- threads=16 round-4 dip 8472.9（vs ~10500 avg；-19%）
- threads=64 round-1 dip 10592.0（vs ~13600 avg；-22%）

> 兩個異常都是該 thread count 的第 1 / 第 4 round；其餘 rounds 穩定。可能 round 之間 60s sleep 不足讓 cluster 完全 settle（ANALYZE 或 background compaction），跨 cell 共同模式要看後續才能判定。

---

## 3. vm-1node baseline 對照（key insight）

| threads | vm-1node tpmC | vm-3node-1s1r tpmC | ratio (1s1r / 1n) |
|---:|---:|---:|---:|
| 16  | 10652.6 | 10538.9 | 0.99x |
| 32  | 11436.5 | 13561.5 | **1.19x** |
| 64  | 11240.1 | 13188.1 | **1.17x** |
| 128 | 10884.9 | 13576.4 | **1.25x** |

> **反直覺**：vm-3node-1s1r（3 tservers, 1 tablet, RF=1）在 threads ≥ 32 比 vm-1node（單實例）快 17-25%。
>
> 可能假說：
> 1. `.32` 的 YSQL backend pool 經 RPC 把 work 分散到 3 tservers 的 raft/IO pipeline → background work 被分擔
> 2. vm-1node 單 process 在高並發 CPU/lock contention 飽和；3-tserver cluster 即使 1 tablet 也能利用多 CPU
> 3. 1 tablet 落在哪 tserver 可能影響：若落 .32（YSQL leader）→ local；若落 .33/.34 → +RTT。本 cell 未 instrument 但結果偏優，可能 placement 落 .32
>
> **不可下「1s1r > 1node」結論**，需 1s1r ↔ 1s3r ↔ 3s1r ↔ 3s3r 完整 4 cell 對照才能拆 RF + sharding 個別成本。

### Per-transaction (last round of threads=16, full Summary)

```
DELIVERY     TPM:    989.5  Avg(ms):  85.6  p99: 142.6
NEW_ORDER    TPM:  10797.2  Avg(ms):  58.4  p99: 100.7
ORDER_STATUS TPM:   1000.6  Avg(ms):  10.1  p99:  58.7
PAYMENT      TPM:  10326.7  Avg(ms):  21.1  p99:  41.9
STOCK_LEVEL  TPM:    948.6  Avg(ms):   8.7  p99:  15.7
```

- NEW_ORDER p99 = 100.7 ms（合理範圍）
- DELIVERY 最慢（Avg 85.6 ms，p99 142.6 ms）— DELIVERY 涉及多表 update，符合 TPC-C 預期
- 5 tx type mix proportion 接近 TPC-C 標準（45% NO / 43% PY / 4% OS / 4% DV / 4% SL）

---

## 4. Patch verification matrix

| Patch | 驗證 |
|---|---|
| **P1** YBDB pre-create SPLIT INTO 1 TABLETS | ✅ 9 表 shard count = 1（hard gate） + go-tpc INSERT 對齊 schema 成功 |
| **P2** TiDB/CRDB SPLIT post-prepare | n/a（1s1r 路徑 skip；待 3s\*r cell 驗）|
| **P3** Shard hard gate | ✅ overall_pass=true 9/9 |
| **gate/gate-isolation/db-config-dump --topology arg** | ✅ markers 全寫到 vm-3node-1s1r dir，無 stale vm-1node leftover |
| **Detached suite via launch-vm1-suite.sh** | ✅ Mac 多次 sleep 不中斷，suite 03:20 自完 |

> 1 個小 metadata bug：`.db-config.done` JSON 的 `"topology"` 還寫 vm-1node — `db-config-dump.sh` JSON body 內 hardcoded。下次 commit 一起修。

---

## 5. 後續 cells 預期觀察點

| Cell | 重點 |
|---|---|
| **ybdb-1s3r** | RF=3 cost：vs 1s1r tpmC 應降（Raft 3-replica 寫入成本） |
| **ybdb-3s1r** | sharding cost：vs 1s1r tpmC 應升（並行 disk/CPU）；驗 3 tablets / 表（cluster default） |
| **ybdb-3s3r** | RF×shard combined：複雜，但應 > 1s3r（並行）但 < 3s1r（複本成本） |
| **tidb / crdb 4 cells** | 三家共同 pattern；rank order 應 stable across DBs |
