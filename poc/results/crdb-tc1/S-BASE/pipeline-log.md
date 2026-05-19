# CockroachDB TPC-C Pipeline Log — crdb-tc1 / S-BASE

> 本檔為 PoC v4.7 框架下的 CockroachDB baseline。舊版（cockroach-tc1）資料保留在 `cockroach-tc1/S-BASE/pipeline-log.md`，與本檔流程不同（手動部署、無 detached suite wrapper、無 DB-host 雙邊監控），不直接對比。

---

## vm-1node-rc — 2026-05-19（PoC v4.7 baseline，含 DB-host OS 監控）

> **本段目的**：在與 TiDB `vm-1node-rc` 相同的硬體 / 流程 / 監控條件下取得 CockroachDB v26.2 單節點 RC baseline，作為 vm-1node-rr / vm-1node-strict 與 vm-3node 對標的起點。

### 環境
- 節點：.32 (172.24.40.32) 單節點，CockroachDB v26.2.0，`start-single-node --insecure`
- 硬體：4 vCPU、15 GiB RAM、單 sda 盤（XFS）
- 部署：ansible playbook `cockroach-vm1.yml`
- CRDB cluster settings：
  - `sql.stats.automatic_collection.enabled = false`（對齊 TiDB 關閉 AUTO ANALYZE 設定）
  - `server.host_based_authentication.configuration = 'host all all all trust'`
  - `sql.txn.repeatable_read_isolation.enabled = true`（為 rr variant 預先啟用 preview RR）
- 連線入口：直連 172.24.40.32:26257
- 測試工具：go-tpc on .31（postgres driver，`--conn-params sslmode=disable&options=-c default_transaction_isolation=read\ committed`）
- Warehouses：128
- Warmup：20 min @ 64 threads
- Run：每組 5 round × 5 min
- Threads：16 / 32 / 64 / 128
- OS 監控：mpstat / iostat / vmstat / sar 同時在 client (`.31`) 與 db-host (`.32`) 採樣 1s 粒度
- TPCC_TS：`20260519T085346+0800`
- 結果目錄：`vm-1node-rc/crdb-vm-1node-rc-20260519T085346+0800/`

### Suite 階段時序

| Phase | 起 | 訖 | 耗時 |
|-------|-----|------|------|
| gate | 08:53 | 08:53 | <1min |
| prepare (128W + check-all + CREATE STATISTICS + EXPLAIN) | 08:53 | 09:36 | 43min |
| gate-isolation | — | 09:50 | <1min |
| run (4 thread × 5 round + 20min warmup) | 09:50 | 12:29 | 2h39min |
| collect | 12:30 | 12:30 | <1s |
| **total**（含中途修 bug + manual resume） | 08:53 | 12:30 | 3h37min |

> 本 suite 在 [3/4] run 起始時因 `gate-isolation.sh` 的 psql multi-stmt 輸出 bug 兩次 die，先後修了 db-gate / driver-verify 兩處後 manual resume 接續。詳見 `tests/common/gate-isolation.sh` 修 commit 與 `.suite.done` 的 `note=manual-resume-2-after-driver-verify-fix` 標記。資料品質：prepare 階段 idempotent 完成，run 階段重啟前已 cold-reset，無資料品質影響。

### Gate 結果
- `transaction_isolation = read committed`（prepare 前 + 後雙閘驗證一致）
- THP=`never`、`vm.swappiness=1`、`ulimit -n=65536`
- NTP drift < 1ms
- disk：sda3 已 growpart 至 100GB

### Prepare
- 時間：43m02s（128W，比 TiDB 52m05s 快 9min）
- check-all 128 warehouse 全條件通過
- CRDB CREATE STATISTICS 取代 TiDB ANALYZE TABLE，9 個統計集建立

### Execute 結果（5 round tpmC 平均；latency 為代表值）

> tpmC / tpmTotal / efficiency 為 5 round mean；NO p50 / p95 / p99 為 5 round latency 代表值。

| threads | tpmC mean | range/mean | tpmTotal mean | efficiency mean | NO p50 (ms) | NO p95 (ms) | NO p99 (ms) |
|---------|-----------|-----------|---------------|-----------------|------------|------------|------------|
| 16  | **9,034** | 9.1%  | 20,123 | 548.8% | 96  | 100 | 113 |
| 32  | 9,020 | 5.9% | 20,019 | 548.0% | 209 | 209 | 223 |
| 64  | 9,134 | 6.2% | 20,287 | 554.9% | 419 | 419 | 440 |
| 128 | 8,813 | 4.7% | 19,544 | 535.4% | 872 | 906 | 926 |

### Round-by-round tpmC

| Threads | r1 | r2 | r3 | r4 | r5 |
|---------|-----|-----|-----|-----|-----|
| 16  | 9303 | 9243 | 9398 | 8577 | 8650 |
| 32  | 9110 | 9215 | 8679 | 8973 | 9125 |
| 64  | 9071 | 9442 | 9233 | 8873 | 9053 |
| 128 | 8747 | 8972 | 8927 | 8861 | 8557 |

### DB-host (.32) IO 飽和分析 ★（與 TiDB 完全不同的瓶頸）

> **核心發現**：CockroachDB 單節點吞吐天花板 **= ~9000 tpmC**，加 thread 完全無 scaling。瓶頸成因為 **Raft log fsync 同步寫入 I/O 等待**（即使 RF=1 仍走 Raft commit 路徑）。

#### 1. mpstat-db.txt — 4 vCPU 使用率（round-3 mid-run，每組 305 個 1s 樣本）

| threads | %usr mean | %sys mean | **%iowait mean** | %idle mean | %idle min |
|---------|-----------|-----------|------------------|------------|-----------|
| 16  | 67.8% | 5.6% | **18.54%** | 5.77% | **0.00%** |
| 32  | 70.0% | 5.7% | **16.95%** | 4.99% | 0.00% |
| 64  | 69.5% | 5.7% | **17.30%** | 5.10% | 0.00% |
| 128 | 68.2% | 5.5% | **18.81%** | 4.99% | 0.00% |

#### 2. iostat-1s-db.txt — sda %util

| threads | disk %util |
|---------|-----------|
| 16  | 59.6% |
| 32  | 53.4% |
| 64  | 52.1% |
| 128 | 52.3% |

#### 3. 飽和歸因

| 假設 | 驗證 | 證據 |
|------|------|------|
| 飽和是 CPU | ❌ | %user mean 68-70%（未達天花板），未來可挪 CPU 給 IO 等待 |
| 飽和是 **IO**（CRDB Raft fsync 同步寫入） | ✓ | iowait **17-19% 全程**，比 TiDB 的 3% 高 5-6 倍 |
| 飽和是磁碟頻寬 | ❌ | %util 52-60% 未滿，I/O queue 因 sync write latency 而非吞吐撞牆 |
| t16/32/64/128 完全 flat | ✓ | tpmC 8813-9134 全在 ±2%，加 thread 只增 queue 長度，不增 throughput |

### vs TiDB vm-1node-rc 對標 ★

> 同硬體 / 同流程 / 同 5 round 平均，唯一變數 DB engine（TiDB pessimistic vs CRDB optimistic + Raft fsync）。

| threads | TiDB RC | CRDB RC | Δ tpmC | TiDB p99 | CRDB p99 | Δ p99 |
|---------|---------|---------|--------|----------|----------|-------|
| 16  | 10,074 | 9,034 | **-10.3%** | 94  | 113 | +20% |
| 32  | 11,728 | 9,020 | **-23.1%** | 163 | 223 | +37% |
| 64  | 12,744 | 9,134 | **-28.3%** | 305 | 440 | +44% |
| 128 | **13,064** | **8,813** | **-32.6%** | 597 | 926 | **+55%** |

| threads | TiDB DB %idle | CRDB DB %idle | TiDB %iowait | **CRDB %iowait** |
|---------|---------------|---------------|--------------|------------------|
| 16  | 9.45% | 5.77% | 4.6% | **18.5%** |
| 32  | 7.02% | 4.99% | 4.0% | **17.0%** |
| 64  | 6.56% | 5.10% | 3.4% | **17.3%** |
| 128 | 4.52% | 4.99% | 3.1% | **18.8%** |

**結論**：兩家在同硬體下天花板成因不同：
- TiDB：**CPU-bound**（%user 75-80%，iowait <5%），可加 thread 擠到 CPU 滿
- CRDB：**IO-bound**（%iowait 17-19%，%user 只 68-70%），瓶頸是 Raft log fsync 同步等待

CRDB 的 t16/t32/t64/t128 tpmC 完全持平 ~9000，是因為每個 NEW_ORDER commit 都必須等 Raft log fsync 落盤；加 thread 只是把 worker 排在 disk wait queue，吞吐不會上升。

### Saturation 分析

```
threads:  16 ───── 32 ───── 64 ───── 128
tpmC:    9034    9020    9134    8813
                 -0.2%   +1.3%   -3.5%      ← flat-line saturation

p99(ms):  113    223    440    926
                +97%    +97%   +110%        ← latency 翻倍

DB %iowait: 18.5%  17.0%  17.3%  18.8%     ← IO 等待持平高位
DB disk %util: 59.6% 53.4% 52.1% 52.3%     ← 磁碟未滿；queue 中
```

### 觀察

- **tpmC 完全 flat**：t16 / t32 / t64 / t128 全在 ±2%，沒有「sweet spot」可言——所有 thread level 都已撞同一個 IO 天花板。
- **latency 隨 thread 翻倍**：worker 排在 disk wait queue，throughput 不變但 wait time 累積。
- **CRDB 比 TiDB 慢的不是計算**：CPU 還有 30% 餘裕（%idle 5% + %iowait 18%），但 iowait 表示「CPU 在等 IO 而非閒置」。
- **磁碟頻寬未滿**：%util 52-60%，IOPS 1.5-2k 量級——CRDB 的限制是**每個 fsync 的延遲**，不是吞吐。
- **本輪修了 4 個 vm1-crdb-rc 路上的 ansible / script bug**（dnf module / SET CLUSTER SETTING / conn-params / psql multi-stmt），詳見 commit log。

### 結論

CockroachDB v26.2 vm-1node RC 在 4 vCPU + single disk 硬體下，**tpmC 硬天花板 ~9000，瓶頸為 Raft log fsync I/O wait**（即使 RF=1 仍走 Raft）。同硬體下 TiDB 因 TiKV WAL 寫入批量化更積極（iowait 僅 3-5%）能繼續榨 CPU，吞吐高 33%。

**業務啟示**：
- **單節點高 OLTP 寫入** → TiDB 同硬體贏 +33% 吞吐、+55% p99 latency 領先（在 t128 高壓下）
- **CRDB 強項在 multi-node**（Raft fsync 並行化到多節點 + 跨 zone 一致性），單節點吃虧
- **下一步驗證**：vm-3node-direct CRDB tpmC 應有顯著上升（IO 並行化）；但 PoC-DESIGN §5.4 警示 scale-out 不應預設為線性

本輪資料作為後續 `vm-1node-rr`（preview RR 已 enable）、`vm-1node-strict`（CRDB 預設 SSI）、以及 vm-3node 對標的 baseline。
