# CockroachDB TPC-C Pipeline Log — crdb-tc1 / S-BASE

> 本檔為 PoC v4.7 框架下的 CockroachDB baseline。舊版（cockroach-tc1）資料保留在 `cockroach-tc1/S-BASE/pipeline-log.md`，與本檔流程不同（手動部署、無 detached suite wrapper、無 DB-host 雙邊監控），不直接對比。

---

## TL;DR — vm-1node 三 isolation 矩陣完成（2026-05-19）

**核心結論**：CockroachDB v26.2 在 4 vCPU + single XFS disk 硬體下，**預設 SERIALIZABLE 最快**（違反「強 iso 較慢」直覺）；preview RR 是最慢的選項（retry storm 浪費 60% 吞吐）。

### tpmC 排行（t128, 5 round mean）

| 排名 | iso | tpmC | DB-host 瓶頸 | err / 5min |
|------|-----|------|--------------|------------|
| 🥇 | **strict (SSI, 預設)** | **10,456** | scale with threads（%idle 33→10%）| 125 |
| 🥈 | rc | 8,813 | fsync IO 立即觸頂（%idle 5% / %iowait 18%） | 0 |
| 🥉 | rr (preview) | 3,788 | retry storm（DB %idle 46%、CPU 浪費在 client 重送）| 127 |

### 三大發現

1. **Strict > RC 反直覺**：t32+ strict 比 RC 快 +10~19% tpmC、p99 約砍半（t128 5-round mean: 477 vs 926ms）。原因為 RC 從 t16 起即被 IO wait 卡死（%user 68% / %iowait 18%），strict 走 SERIALIZABLE read-refresh 路徑（細節以 [stable docs](https://www.cockroachlabs.com/docs/stable/architecture/transaction-layer) 為準）IO 更省，仍有 CPU headroom 可榨。
2. **RR=SI、但行為差 TiDB pessimistic 3.5x**：CockroachDB 文件明寫「REPEATABLE READ maps to SNAPSHOT」，採 first-committer-wins。同 TiDB RR（亦 SI）相比，TiDB pessimistic 拿鎖時 advance for-update-ts、不需 retry，跑出 13,874 vs CockroachDB 3,788 tpmC（**-72.7%**）。CockroachDB 無等效於 `tidb_txn_mode=pessimistic` 的全域開關。
3. **Starting-gun storm**：RR/strict 兩者皆在每 round 起始 30s-4.5min 內爆 retry（per-txn snapshot ts 同步觸發 hot row 衝突）。RC 因 per-statement snapshot 完全免疫。strict 的 err spread 比 RR 寬 3-5x，但**總 err count 接近**（strict 14/30/61/125 vs RR 15/31/63/127）— 推測與 SERIALIZABLE 的 read-refresh 重試路徑有關，需 CockroachDB trace / statement diagnostics 進一步佐證（[CockroachDB transaction-layer docs](https://www.cockroachlabs.com/docs/stable/architecture/transaction-layer)、[Transactions docs](https://www.cockroachlabs.com/docs/stable/transactions)）。

### 業務啟示

- CockroachDB 切 isolation 不要為了「降強度求性能」— 預設 SERIALIZABLE 在這硬體下既最快又最安全
- 若 app 必須 SI 語意，**不要選 preview RR**：強度同 SSI 但性能砍 60%；用 strict 才對
- 部署 / failover / pool warmup 等同步啟動情境會放大 RR 的 starting-gun 問題，需 client jittered backoff + 連線 warmup
- TiDB 在此硬體上 RR 仍勝 CockroachDB strict（13,874 vs 10,456，+33%），但設計成本上 CockroachDB 賺正確性 default-on 的工程穩定性

### 完整資料目錄

| iso | TPCC_TS | 5-round mean t128 | 詳細段落 |
|-----|---------|-------------------|----------|
| rc | 20260519T085346+0800 | 8,813 | [§ vm-1node-rc](#vm-1node-rc--2026-05-19poc-v47-baseline含-db-host-os-監控) |
| rr | 20260519T124506+0800 | 3,788 | [§ vm-1node-rr](#vm-1node-rr--2026-05-19poc-v47crdb-preview-rr) |
| strict | 20260519T164057+0800 | 10,456 | [§ vm-1node-strict](#vm-1node-strict--2026-05-19poc-v47crdb-serializable--ssi) |

vm-3node 5-cell（1s1r / 1s3r / 3s1r / 3s3r / haproxy-3s3r × RC）已於 2026-06-01/02 完成（5-round mean、N=1）；途中踩 F-E history SPLIT octal parse 後 resume；詳見下方 `vm-3node 系列` 與 [2026-06-02-crdb-vm3-5cell-suite-dispatch.md](../../dispatch-records/2026-06-02-crdb-vm3-5cell-suite-dispatch.md)。

下一步：三家 `haproxy-3s3r` 補 N=3 → 升級為對外可引用 baseline；跨區規劃見 [`1_MeetingMinutes/0602.md §10`](../../../1_MeetingMinutes/0602.md)。

---

## 取數來源（Data trace）

所有 tpmC / latency / error rate / DB-host 飽和指標皆可從 artifact 目錄逐步重現，避免「pipeline-log 數字 vs 實際 stdout」漂移。

| 數據類型 | 來源檔案 | 取數工具 / 計算口徑 |
|---------|----------|---------------------|
| `tpmC mean` / `NO p50/p95/p99 mean` / `tpmTotal mean` / `efficiency mean` | `runs/threads-<N>/round-<R>/go-tpc-stdout.txt`（5 round per thread group）| [`tests/common/summary-from-stdout.py`](../../../tests/common/summary-from-stdout.py) 解析 `[Summary] NEW_ORDER` 與 `tpmC: ...` 行，輸出 `summary.json`；本檔取 `thread_results.<N>.{tpmC_mean, NEW_ORDER.p50_mean_ms, ...}` 為 5-round mean |
| `range/mean` 穩定度 | 同上 | `(max(tpmC_per_round) - min(tpmC_per_round)) / tpmC_mean × 100%` |
| `error rate (all_txn)` | 同上 `[Summary] *_ERR` 行（5 transaction types） | `Σ *_ERR count / Σ (* + *_ERR) count × 100%`（per F-001 audit 口徑）；落地至 `summary.json.thread_results.<N>.all_txn.error_rate_pct` |
| `NEW_ORDER_ERR / round` 統計 | 同上 | `summary.json.thread_results.<N>.NEW_ORDER.error_count / 5 round` |
| DB-host 飽和指標（%user / %sys / %iowait / %idle / disk %util）| `runs/threads-<N>/round-<R>/{mpstat-db.txt, iostat-1s-db.txt}` | round-3 mid-run 1s 取樣，跨 round 計算 `mean(line[%idle], %iowait)`；指令範例：`awk '$2=="all" {usr+=$3; ...} END{...}'` |
| isolation gate 雙閘證據 | `gate/isolation-db.txt` + `gate/isolation-driver-verify.txt` + `.gate-isolation.done`（JSON marker）| `psql -c "SHOW transaction_isolation"`（CockroachDB 不需第二層 effective gate）|
| CockroachDB cluster setting dump | `db-config/effective-config.txt` + `db-config/cluster-settings.txt` | collect 階段 `db-config-dump.sh` 跑 `cockroach sql -e "SHOW ALL CLUSTER SETTINGS"` |
| Round 結構完整性驗證 | `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.suite.done` | 6 個 marker 全在 = phase chain 完整 |

重新計算 vm-1node-strict t64 5-round mean 範例：

```bash
jq '.thread_results."64".tpmC_mean,
    .thread_results."64".NEW_ORDER.p99_mean_ms,
    .thread_results."64".all_txn.error_rate_pct' \
  results/crdb-tc1/S-BASE/vm-1node-strict/crdb-vm-1node-strict-20260519T164057+0800/summary.json
```

---

## vm-1node-rc — 2026-05-19（PoC v4.7 baseline，含 DB-host OS 監控）

> **本段目的**：在與 TiDB `vm-1node-rc` 相同的硬體 / 流程 / 監控條件下取得 CockroachDB v26.2 單節點 RC baseline，作為 vm-1node-rr / vm-1node-strict 與 vm-3node 對標的起點。

### 環境
- 節點：.32 (172.24.40.32) 單節點，CockroachDB v26.2.0，`start-single-node --insecure`
- 硬體：4 vCPU、15 GiB RAM、單 sda 盤（XFS）
- 部署：ansible playbook `cockroach-vm1.yml`
- CockroachDB cluster settings：
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
- CockroachDB CREATE STATISTICS 取代 TiDB ANALYZE TABLE，9 個統計集建立

### Execute 結果（5 round tpmC 平均；latency 為 5 round mean）

> tpmC / tpmTotal / efficiency 為 5 round mean；NO p50 / p95 / p99 亦為 5 round latency mean（已驗算對齊）。

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

> **核心發現**：CockroachDB 單節點吞吐天花板 **= ~9000 tpmC**，加 thread 完全無 scaling。OS 層證據（iowait 17-19% / %user 不滿 / disk %util 52-60%）支持「**I/O wait bound**」結論；**推測**為 Raft / Pebble WAL fsync 同步寫入導致（RF=1 仍走 Raft commit 路徑），但本輪未採到 CockroachDB store metrics / wait events / Pebble fsync 直接指標，**Raft fsync 為因果推論而非直接量測**，建議後續用 `crdb_internal.node_statement_statistics` / store metrics / trace 補強。

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
| 飽和是 **IO wait**（推測為 Raft / Pebble WAL fsync 同步寫入；待 store-metric 佐證） | OS-level ✓ / 機制 ?  | iowait **17-19% 全程**，比 TiDB 的 3% 高 5-6 倍 |
| 飽和是磁碟頻寬 | ❌ | %util 52-60% 未滿，I/O queue 因 sync write latency 而非吞吐撞牆 |
| t16/32/64/128 完全 flat | ✓ | tpmC 8813-9134 全在 ±2%，加 thread 只增 queue 長度，不增 throughput |

### vs TiDB vm-1node-rc 對標 ★

> 同硬體 / 同流程 / 同 5 round 平均，唯一變數 DB engine（TiDB pessimistic vs CockroachDB optimistic + Raft fsync）。

| threads | TiDB RC | CockroachDB RC | Δ tpmC | TiDB p99 | CockroachDB p99 | Δ p99 |
|---------|---------|---------|--------|----------|----------|-------|
| 16  | 10,074 | 9,034 | **-10.3%** | 94  | 113 | +20% |
| 32  | 11,728 | 9,020 | **-23.1%** | 163 | 223 | +37% |
| 64  | 12,744 | 9,134 | **-28.3%** | 305 | 440 | +44% |
| 128 | **13,064** | **8,813** | **-32.6%** | 597 | 926 | **+55%** |

| threads | TiDB DB %idle | CockroachDB DB %idle | TiDB %iowait | **CockroachDB %iowait** |
|---------|---------------|---------------|--------------|------------------|
| 16  | 9.45% | 5.77% | 4.6% | **18.5%** |
| 32  | 7.02% | 4.99% | 4.0% | **17.0%** |
| 64  | 6.56% | 5.10% | 3.4% | **17.3%** |
| 128 | 4.52% | 4.99% | 3.1% | **18.8%** |

**結論**：兩家在同硬體下天花板成因不同：
- TiDB：**CPU-bound**（%user 75-80%，iowait <5%），可加 thread 擠到 CPU 滿
- CockroachDB：**IO-wait bound**（%iowait 17-19%，%user 只 68-70%）；推測瓶頸為 Raft / Pebble WAL fsync 同步等待，待 wait-event/store-metric 直接驗證

CockroachDB 的 t16/t32/t64/t128 tpmC 完全持平 ~9000，符合「每個 NEW_ORDER commit 等同步 fsync」的 IO-wait bound 形態；加 thread 只是把 worker 排在 disk wait queue，吞吐不會上升（具體 fsync 來源為 Raft 或 Pebble WAL 仍待 store-metric 確認）。

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
- **CockroachDB 比 TiDB 慢的不是計算**：CPU 還有 30% 餘裕（%idle 5% + %iowait 18%），但 iowait 表示「CPU 在等 IO 而非閒置」。
- **磁碟頻寬未滿**：%util 52-60%，IOPS 1.5-2k 量級——CockroachDB 的限制是**每個 fsync 的延遲**，不是吞吐。
- **本輪修了 4 個 vm1-crdb-rc 路上的 ansible / script bug**（dnf module / SET CLUSTER SETTING / conn-params / psql multi-stmt），詳見 commit log。

### 結論

CockroachDB v26.2 vm-1node RC 在 4 vCPU + single disk 硬體下，**tpmC 硬天花板 ~9000，IO-wait bound**（%iowait 17-19% / %user 68-70% / %idle 5%）；**推測**為 fsync 同步寫入瓶頸（Raft commit 路徑或 Pebble WAL，仍待直接量測）。同硬體下 TiDB 因 TiKV WAL 寫入批量化更積極（iowait 僅 3-5%）能繼續榨 CPU，吞吐高 33%。

**業務啟示**：
- **單節點高 OLTP 寫入** → TiDB 同硬體贏 +33% 吞吐、+55% p99 latency 領先（在 t128 高壓下）
- **CockroachDB 強項在 multi-node**（Raft fsync 並行化到多節點 + 跨 zone 一致性），單節點吃虧
- **下一步驗證**：vm-3node-direct CockroachDB tpmC 應有顯著上升（IO 並行化）；但 PoC-DESIGN §5.4 警示 scale-out 不應預設為線性

本輪資料作為後續 `vm-1node-rr`（preview RR 已 enable）、`vm-1node-strict`（CockroachDB 預設 SSI）、以及 vm-3node 對標的 baseline。

---

## vm-1node-rr — 2026-05-19（PoC v4.7，CockroachDB preview RR）

> **本段目的**：在同硬體 / 同流程下取得 CockroachDB v26.2 preview RR baseline，並與 TiDB RR (pessimistic) 對標 SI 機制差異。

### 環境（同 rc）
- 節點：.32 單節點，CockroachDB v26.2.0
- Cluster setting：`sql.txn.repeatable_read_isolation.enabled = true`
- go-tpc conn-params：`sslmode=disable&options=-c default_transaction_isolation=repeatable\ read`
- TPCC_TS：`20260519T124506+0800`
- Suite start：12:48:02；prepare done 13:31:08（43min，與 rc 一致）；gate-isolation 13:32:14 ✓ `repeatable read`

### RR=SI 機制差異 ★（同名不同實作）

> **核心發現**：CockroachDB 與 TiDB 雙方文件都明文 RR 內部 = Snapshot Isolation (SI)，但 conflict 處理機制不同 → TPC-C 觀測差異巨大。

**CockroachDB（v26.2 preview RR）** — 證據來源（複合）：
- **artifact 直接證據**：go-tpc 錯誤訊息含 `iso=Snapshot pri=...`（見 `vm-1node-rr/.../runs/threads-128/round-5/go-tpc-stdout.txt`）→ 本次實測 v26.2 preview RR 內部走 Snapshot
- **公開穩定文件**：CockroachDB stable docs 主要記錄 SERIALIZABLE 與 READ COMMITTED；preview RR 屬未進入 stable matrix 之 feature。SERIALIZABLE 透過 read refresh 維持 per-txn snapshot 的描述見 [transaction-layer docs](https://www.cockroachlabs.com/docs/stable/architecture/transaction-layer)
- **內部來源**（僅供參考、未 commit-pin，可能漂移）：`pkg/kv/kvserver/concurrency/isolation` package godoc

> "The system also exposes **REPEATABLE READ, which maps to SNAPSHOT**"（內部 godoc 描述）
> "A transaction ... is prevented from writing to data that has changed since the transaction began (**'first committer wins'**), preventing lost updates."
> "When a read refresh fails validation, **the transaction must restart**."

> **規格穩定性 caveat**：以上引文取自 CockroachDB source 內部 package godoc，非 stable 公開文件。**preview feature 行為可能在後續版本變動**；若要在報告 / 決策層引用，建議 pin 到 v26.2 source commit SHA 或 release-note URL。

**TiDB** — 來源：[TiDB Transaction Isolation Levels](https://docs.pingcap.com/tidb/stable/transaction-isolation-levels/)
> "TiDB implements **Snapshot Isolation (SI) consistency, which it advertises as `REPEATABLE-READ`** for compatibility with MySQL."
> Pessimistic 模式："the updating transaction can be successful"；後到 update "**wait for the lock** until the transaction holding the lock commits or rolls back"。

| 維度 | CockroachDB RR | TiDB RR (pessimistic) |
|------|---------|---------------------|
| 內部 iso | SNAPSHOT ✓ | SNAPSHOT (SI) ✓ |
| 寫衝突 | first committer wins → `WriteTooOldError` → **client retry** | **row lock 排隊**（後者 wait） |
| `SELECT FOR UPDATE` | 取 unreplicated lock，**不 advance read ts** | 取 pessimistic lock，**advance for-update-ts** |
| TPC-C 觀感 | NEW_ORDER_ERR 升、retry storm | 無 retry，latency 增 |
| 全域 pessimistic toggle | ❌ 無等效於 `tidb_txn_mode=pessimistic` | ✓ |
| 規避 retry 手段 | 切 SERIALIZABLE（仍有 refresh restart） | 用 pessimistic mode |

### 實測現象（run 進行中觀察）
- go-tpc TPC-C 的 NEW_ORDER 路徑 `SELECT d_next_o_id, d_tax FROM district ... FOR UPDATE` 即使顯式 FOR UPDATE，仍在 CockroachDB RR 下持續觸發 `TransactionRetryWithProtoRefreshError: WriteTooOldError`
- 錯誤訊息含 `iso=Snapshot pri=...` 直接證實內部 = SI
- NEW_ORDER_ERR 樣本 18 TPM 級（~1% 錯誤率）
- 推測 final tpmC 會比 rc 低（retry 吃 CPU + 部分 NEW_ORDER 無法計入有效 tpmC）

### CockroachDB pessimistic 工具集（補充）

CockroachDB 無 TiDB `tidb_txn_mode=pessimistic` 等效全域開關，只能在語句層用：

| 工具 | 範圍 | 對 RR/SI 效果 |
|------|------|--------------|
| `SELECT ... FOR UPDATE` | 語句層 | 取 lock，**不改 txn read ts** |
| `enable_implicit_select_for_update` / `sql.defaults.implicit_select_for_update.enabled` | UPDATE/UPSERT 內部讀 | 自動為 mutation 內部讀加 FOR UPDATE（go-tpc TPC-C 不依賴此） |

**結論**：CockroachDB RR 在 SI 語意下，read snapshot 凍結於 BEGIN，**鎖也不能 advance**，本質就是 optimistic-with-FOR-UPDATE-hint，無法等價於 TiDB pessimistic 的 lock-wait 語意。

### Suite 階段時序

| Phase | 起 | 訖 | 耗時 |
|-------|-----|------|------|
| gate | 12:47 | 12:48 | <1min |
| prepare (128W + check-all + CREATE STATISTICS + EXPLAIN) | 12:48 | 13:31 | 43min |
| gate-isolation | 13:31 | 13:32 | <1min |
| run (4 thread × 5 round + 20min warmup) | 13:32 | 16:12 | 2h40min |
| collect | 16:12 | 16:12 | <1s |
| **total** | 12:47 | 16:12 | 3h25min |

### Execute 結果（5 round tpmC + latency 均為 mean）

> tpmC / latency 均為 **5-round mean**（已對齊 RC 段落口徑；歷史版本曾使用 r5 代表值已重算）。

| threads | tpmC mean | range/mean | NO p50 (ms) | NO p95 (ms) | NO p99 (ms) | NEW_ORDER_ERR / 5min | err TPM |
|---------|-----------|------------|-------------|-------------|-------------|----------------------|---------|
| 16  | **3,229** | 18.0% | 14.2 | 35.0  | 54.1  | 15  | 3.0  |
| 32  | 3,577 | 22.2% | 15.5 | 65.4  | 102.4 | 31  | 6.2  |
| 64  | 3,594 | 28.7% | 16.6 | 133.4 | 216.4 | 63  | 12.6 |
| 128 | **3,788** | 21.2% | 17.6 | 303.7 | 486.5 | 127 | 25.4 |

> 錯誤量 ≈ 0.2 err/sec/thread（線性增長：t16=3.0, t32=6.2, t64=12.6, t128=25.4 err TPM）。

### Round-by-round tpmC

| Threads | r1 | r2 | r3 | r4 | r5 |
|---------|-----|-----|-----|-----|-----|
| 16  | 3142 | 3353 | 3542 | 3144 | 2961 |
| 32  | 3488 | 3499 | 3999 | 3692 | 3204 |
| 64  | 3400 | 3334 | 3488 | 3384 | 4363 |
| 128 | 3976 | 3502 | 4305 | 3644 | 3515 |

### DB-host (.32) 飽和分析 ★（與 rc / 與 TiDB rr 完全不同）

| threads | %usr mean | %sys mean | %iowait mean | %idle mean | %idle min | sda %util |
|---------|-----------|-----------|--------------|------------|-----------|-----------|
| 16  | 30.6% | 3.5% | 10.13% | **54.09%** | 2.54% | 48.0% |
| 32  | 32.6% | 3.6% | 11.36% | **50.70%** | 0.00% | 51.4% |
| 64  | 31.3% | 3.7% | 10.36% | **53.06%** | 0.00% | 46.2% |
| 128 | 35.9% | 4.0% | 12.37% | **45.94%** | 0.00% | 53.0% |

> **核心發現**：CockroachDB rr 與 rc / TiDB rr 都不同——**DB 機器同時 idle 大量 CPU + 適度 iowait**，卻只跑出 RC 約 40% 的吞吐。瓶頸不在 OS 層，而在 **transaction 協調層（retry storm）**。

| 假設 | 驗證 | 證據 |
|------|------|------|
| 飽和是 CPU | ❌ | %user 30-36%，%idle mean **46-54%** |
| 飽和是 IO | ❌ | iowait 10-12%（比 rc 17-19% 還低）；sda %util 46-53% |
| 飽和是 **retry storm**（SI 寫衝突 → WriteTooOldError → client restart） | ✓ | err TPM 線性隨 thread 加倍；DB 工作量被 retry 浪費；DB host 反而沒在「做正事」的時候少 |

### Error 時序分布 ★ — starting-gun storm（每 round 起始爆發、自動收斂）

實測：錯誤**不是均勻分布**在整 round，而是高度集中在 **round 啟動後 30-50 秒**內，之後 4 分鐘幾乎零錯。每個 round 都重複這個 pattern。

| round | 時長 | 第一個 err | 最後一個 err | err 集中窗口 | 剩餘時段 err |
|-------|------|-----------|--------------|-------------|--------------|
| t16 r1 (300s) | 5min | +2s | +35s | 0-35s (15 errs) | 0 |
| t128 r5 (300s) | 5min | +0s | +50s 主峰 / +90s 尾段 | 0-50s (114 errs) | 1 stray |

#### 機制（同步衝突期 → 自然 desync）

**round 啟動 0-50 秒（synchronization storm）**：
1. go-tpc 在 round start 瞬間放 N 個 worker thread 同時發第一筆 NEW_ORDER
2. district PK 空間僅 128W × 10D = 1280 row，且每筆 NEW_ORDER 必 `UPDATE d_next_o_id`（hot row）
3. N 個 txn 的 BEGIN ts 落在毫秒級窗口 → snapshot 高度重疊
4. **first committer wins**：第一個 commit 贏，剩 N-1 個全 `WriteTooOldError` → restart
5. pq driver 預設 retry 無 jitter，restart 後又同步打 → 第二波碰撞

**50 秒後（natural desync）**：
- TPC-C cycle = NEW_ORDER + PAYMENT + DELIVERY (25-90ms 變異) + ORDER_STATUS + STOCK_LEVEL
- DELIVERY 延遲變異把 worker cycle 完成時間散開
- 幾個完整 cycle 後 worker 進入不同 phase，hit district 時間錯開
- snapshot ts 分散到秒級窗口，碰撞機率掉 1 個量級

**為何每 round 都重複**：`run.sh` 在 round 間 sleep 60 秒，下個 round 是新的 "starting gun"，desync 重新累積 → 同 pattern 重來。

#### 業務含義

- TPC-C round-restart 是 worst-case 同步啟動模擬，**真實流量穩態進入時碰撞會更少**
- 但部署 / failover / connection-pool 預熱、pod rolling restart 後流量灌回、failover 切換瞬間 — 這些情境會重現 starting-gun pattern
- CockroachDB SI 對「同步啟動」極為敏感，緩解需要：
  1. **client 端 jittered backoff**（pq driver 預設 retry 無 jitter）
  2. **connection 漸進 warmup**（spread connect 時間）
  3. **app 層 rate limiter** 限制 cold start 突發
- TiDB pessimistic 因「拿鎖時 advance for-update-ts」，starting gun 來 N 個 worker 只是排隊等鎖、**慢但不錯**；CockroachDB SI 則 N-1 個 reject + 重來，total work = `N+(N-1)+(N-2)+...`

#### RC 對照 — 同硬體同 starting-gun，**RC 完全零錯誤**

實測 RC artifacts (`vm-1node-rc/crdb-vm-1node-rc-20260519T085346+0800/`) 20 個 round 全 grep：

| 檢測項 | RC（20 rounds） | RR（20 rounds） |
|--------|----------------|----------------|
| `WriteTooOldError` | **0** | 412 |
| `TransactionRetryWithProtoRefreshError` | **0** | 412 |
| `execute run failed` | **0** | 412 |
| `[Summary] NEW_ORDER_ERR` 行存在 | **不存在** | 每 round 都有 |

| 機制 | RC | RR/SI |
|------|-----|-------|
| Snapshot 範圍 | **per-statement**（每句 SQL 取 latest committed） | **per-txn**（BEGIN 時凍結） |
| `SELECT FOR UPDATE` 拿鎖後 | 後續 SQL 用 latest ts 讀，**自動看到別人新寫的版本** | snapshot 不變，看不到新版本 |
| N 個 worker 同步打 hot row | 排隊 → 第一個 commit → 下個拿 latest ts 看到新值 → 正常 UPDATE → **零碰撞** | 第一個贏 → 其他 N-1 個 snapshot < latest commit ts → 全 abort |
| 結果 | **lock-wait queue**（慢但無錯）→ 瓶頸是 Raft fsync IO | **retry storm**（錯且慢）→ 瓶頸是 SI 衝突 |

**強化結論**：RR 的 starting-gun storm **不是「starting-gun」造成的，是「SI + starting-gun」造成的**。同 pattern 在 RC 下完全不發生。RC 因 per-statement snapshot + FOR UPDATE lock 組合，行為近似 TiDB pessimistic。

### vs CockroachDB rc 對比

| threads | RC tpmC | RR tpmC | Δ tpmC | RC p99 | RR p99 | Δ p99 | RR err / 5min |
|---------|---------|---------|--------|--------|--------|-------|---------------|
| 16  | 9,034 | 3,229 | **-64.3%** | 112 | 54  | **-52%** (less stress) | 15 |
| 32  | 9,020 | 3,577 | **-60.3%** | 223 | 102 | -54% | 31 |
| 64  | 9,134 | 3,594 | **-60.6%** | 440 | 216 | -51% | 63 |
| 128 | 8,813 | 3,788 | **-57.0%** | 926 | 487 | -47% | 127 |

> p99 均為 5-round mean（已對齊 F-002 統一口徑）。

> RR latency 反而比 RC 低，因為 RR 跑不滿（throughput 砍 60%，queue 短），但每個成功 NEW_ORDER 還要把先前 retry 失敗的時間納進來；real-world latency 體感更差因為使用者看到的是「我這筆訂單從第一次嘗試到最後成功」的端到端時間，包含中間 retry。

### vs TiDB rr 對比 ★

| threads | TiDB RR tpmC | CockroachDB RR tpmC | Δ | TiDB RR err | CockroachDB RR err |
|---------|--------------|--------------|---|-------------|-------------|
| 16  | 11,196 | 3,229 | **-71.2%** | 0 | 15 |
| 32  | 12,831 | 3,577 | **-72.1%** | 0 | 31 |
| 64  | 13,743 | 3,594 | **-73.8%** | 0 | 63 |
| 128 | 13,874 | 3,788 | **-72.7%** | 0 | 127 |

| DB-host | TiDB RR %user | CockroachDB RR %user | TiDB RR %idle | CockroachDB RR %idle |
|---------|---------------|---------------|---------------|---------------|
| t16  | 73.9% | 30.6% | 7.48% | **54.09%** |
| t128 | 80.8% | 35.9% | 4.47% | **45.94%** |

→ **同 RR 名稱、同 SI 語意，TiDB pessimistic 模式跑出 CockroachDB 的 3.5x 吞吐**，且零 NEW_ORDER_ERR。確認 [RR=SI 機制差異] 段論述：CockroachDB 走 retry，TiDB 走 lock-wait。

### 結論

CockroachDB v26.2 preview RR 在 vm-1node 4 vCPU 硬體下：
- **吞吐天花板 ~3,600 tpmC**（比 rc 9,000 砍 60%、比 TiDB rr 13,000 少 72%）
- **err rate 線性隨 thread**：0.2 err/sec/thread（t128 達 25 err TPM）
- **DB-host 不飽和**：%idle 46-54%、iowait 10-12%、disk %util 46-53%
- 瓶頸 = **retry storm**（SI 寫衝突 + client retry）

**業務啟示**：
- CockroachDB 在 SI（RR/SNAPSHOT）下若有 hot row（district / warehouse），**retry 會吃掉大量 CPU/IO 預算**且實際吞吐遠不如 RC
- 若需要 SI 行為，建議：
  1. 切回 **SERIALIZABLE**（CockroachDB 預設；refresh 機制比純 retry 高效）
  2. 用 RC + 應用層 idempotency 補強讀一致性需求
- **不要把 CockroachDB RR 視為 TiDB RR pessimistic 的等價替代** — 表象同名，行為差 3x

---

## vm-1node-strict — 2026-05-19（PoC v4.7，CockroachDB SERIALIZABLE / SSI）

> **本段目的**：完成 CockroachDB v26.2 三組 isolation 矩陣（rc / rr / strict）。CockroachDB 預設即 SERIALIZABLE，本段量化 SSI vs RC vs RR 在同硬體下的吞吐 / latency / DB 資源差異。

### 環境（同 rc / rr）
- 節點：.32 單節點，CockroachDB v26.2.0
- go-tpc conn-params：`sslmode=disable&options=-c default_transaction_isolation=serializable`
- TPCC_TS：`20260519T164057+0800`
- Suite start：16:43:31；prepare done ~17:27；run 17:28 → 20:06；total 3h24min
- 結果目錄：`vm-1node-strict/crdb-vm-1node-strict-20260519T164057+0800/`

### Execute 結果（5 round tpmC + latency 均為 mean）

> tpmC / latency 均為 **5-round mean**（已對齊 RC 段落口徑；歷史版本曾使用 r5 代表值已重算）。

| threads | tpmC mean | range/mean | NO p50 (ms) | NO p95 (ms) | NO p99 (ms) | NEW_ORDER_ERR / 5min | err TPM |
|---------|-----------|------------|-------------|-------------|-------------|----------------------|---------|
| 16  | 7,878  | 14.7% | 15.5 | 39.8  | 54.1  | 14  | 2.9  |
| 32  | 9,935  | 22.2% | 18.2 | 74.7  | 105.7 | 30  | 6.0  |
| 64  | **10,830** | 15.0% | 29.8 | 154.4 | 219.8 | 61  | 12.2 |
| 128 | 10,456 | 7.3%  | 42.8 | 322.1 | 476.5 | 125 | 25.1 |

### Round-by-round tpmC

| Threads | r1 | r2 | r3 | r4 | r5 |
|---------|-----|-----|-----|-----|-----|
| 16  | 7463  | 8450  | 7868  | 8321  | 7288  |
| 32  | 10383 | 10886 | 9239  | 8680  | 10485 |
| 64  | 10195 | 11715 | 10089 | 11338 | 10813 |
| 128 | 10046 | 10679 | 10729 | 10792 | 10033 |

### DB-host (.32) 飽和分析

| threads | %usr mean | %sys mean | %iowait mean | %idle mean | %idle min | sda %util |
|---------|-----------|-----------|--------------|------------|-----------|-----------|
| 16  | 50.7% | 4.9% | 8.88%  | **33.48%** | 0.00% | 37.3% |
| 32  | 53.1% | 5.2% | 11.99% | 27.49% | 0.00% | 43.5% |
| 64  | 58.8% | 5.5% | 14.40% | 18.93% | 0.00% | 45.9% |
| 128 | 64.2% | 6.0% | 17.25% | 9.99%  | 0.00% | 50.2% |

> strict 的 CPU 隨 thread 線性爬升（50→64%），不像 RC 一開始就被 fsync IO 卡在 68%。表示 SSI 對 IO 路徑更省 — 同樣 IO 預算下能跑更多 txn。

### 三 iso 對比 ★（CockroachDB 同硬體）

| threads | RC tpmC | strict tpmC | RR tpmC | strict vs RC | strict vs RR | RC p99 | strict p99 | RR p99 |
|---------|---------|-------------|---------|--------------|--------------|--------|------------|--------|
| 16  | 9,034 | 7,878 | 3,229 | **-12.8%** | +144% | 112 | **54**  | 54  |
| 32  | 9,020 | **9,935**  | 3,577 | **+10.1%** | +178% | 223 | **106** | 102 |
| 64  | 9,134 | **10,830** | 3,594 | **+18.6%** | +201% | 440 | **220** | 216 |
| 128 | 8,813 | **10,456** | 3,788 | **+18.6%** | +176% | 926 | **477** | 487 |

> 所有 p99 均為 5-round mean（F-002 統一口徑）；strict t128 mean 477ms 略低於 RR 487ms，但本表已捨棄 r5 代表值版的「strict 487ms < RR 604ms」過大差距宣告。

| iso | snapshot | 寫衝突處理 | client retry 義務 | DB-host saturate 模式 |
|-----|----------|-----------|------------------|----------------------|
| **RC** | per-statement | row lock 排隊 | 無 | fsync IO 立即天花板（%iowait 18%, %idle 5%） |
| **RR/SI** | per-txn 凍結 | WriteTooOldError | **必須**（client 完整重送） | DB idle 50%、retry storm 浪費 throughput |
| **Strict/SSI** | per-txn + read refresh | 衝突可能走 read-refresh 路徑（細節以 [CockroachDB v26.2 transaction-layer docs](https://www.cockroachlabs.com/docs/stable/architecture/transaction-layer) 為準） | 偶爾外漏為 errors | scale with threads（%idle 33→10%） |

### Error 時序分布 ★ — 與 RR 對比

實測 strict 也有 starting-gun storm，但 **error spread 比 RR 廣 3-5x**（strict t16 集中於 89s 內，RR t16 集中於 33s 內；strict t128 跨 4.5min，RR t128 跨 0.8min）。

#### 實證數據

| round | iso | 第一個 err | 最後一個 err | err 總時長 | 集中度（前 50s 占比）|
|-------|-----|-----------|-------------|-----------|---------------------|
| t16 r1 | RR | +2s | +35s | 33s | ~100% |
| t16 r1 | **strict** | +5s | +94s | **89s** | ~70% |
| t128 r5 | RR | +0s | +90s | 90s（主峰前 50s） | 90% |
| t128 r5 | **strict** | +0s | +274s | **274s（4.5min）** | 75% |

#### strict t128 r5 error 時序（10s buckets）

```
0-10s:  15 errs  ████████████████
10-20s:  8       ████████
20-30s: 16       ████████████████
30-40s: 13       █████████████
40-50s: 20       ████████████████████ ← 高峰
50-60s: 11       ███████████
60-70s:  8       ████████
70-80s:  5       █████
80-90s: 11       ███████████
... 第二波遞減
110s:    4
130s:    1
140s:    4
150s:    3
160s:    1
170s:    2
180s:    1
... 至 274s 才完全停止
```

#### 機制差異（為何 strict err spread 比 RR 廣）

| 維度 | RR (SI) | strict (SSI) |
|------|---------|--------------|
| client 看到 err 時機 | **第一次** WriteTooOldError 就立即外漏 | err spread 較廣，疑似多次內部嘗試後才外漏 |
| 內部 retry 機制（推測） | 無 | SERIALIZABLE read-refresh 路徑可能涉及重試（未直接量測，待 trace 佐證） |
| err 速度 | 快速宣告失敗（concentration 高） | 持續嘗試（spread 廣） |
| 用戶觀感 | "錯了重來"（明確） | "好像有時 retry 有時不"（混亂） |
| 真實 retry 次數 | = NEW_ORDER_ERR count | ≥ NEW_ORDER_ERR count（server-internal 部分需 statement diagnostics 才能量化）|

> **機制說明的限制**：本表 server-internal 細節為**推論**，artifact 僅能支持「strict t32+ throughput 高於 RC/RR、err count 接近 RR」這兩項結論。內部 retry 機制的細節差異建議以 [CockroachDB v26.2 transaction-layer docs](https://www.cockroachlabs.com/docs/stable/architecture/transaction-layer) + [transactions docs](https://www.cockroachlabs.com/docs/stable/transactions) 為主，加 trace/statement diagnostics 直接驗證。

#### error 類型統計（strict）

| round | WriteTooOldError | TransactionRetryWithProtoRefreshError | SerializationFailure |
|-------|------------------|-----------------------------------|----------------------|
| t16 r1 | 28（=14 unique × 2 echo lines） | 28 | 0 |
| t128 r1 | 254（=127 × 2） | 254 | 0 |
| t128 r5 | 254（=127 × 2） | 254 | 0 |

> strict 完全沒有 `SerializationFailure`（CockroachDB SSI 的另一種衝突類型）：所有衝突都被 WriteTooOldError 早期 catch；refresh 路徑沒走到 commit-time validation 失敗。
> grep 出來的 raw count 是 NEW_ORDER_ERR 的 2x，因為 go-tpc 同 error 印兩行（一行有 timestamp prefix、一行裸印 err）。實際 unique error 件數以 [Summary] NEW_ORDER_ERR Count 為準。

### 關鍵發現

1. **Strict 在 t32+ 反超 RC 10-19% tpmC**：違反「越強 isolation 越慢」直覺；原因為 RC fsync IO 立即觸頂（%idle 5%），strict 仍有資源頭可榨
2. **Strict 比 RR 快 3x，但 err count 接近**（strict 14/30/61/125 vs RR 15/31/63/127）：兩者都被 snapshot 寫衝突影響，推測差異與 SERIALIZABLE 的 read-refresh / retry 路徑有關（artifact 可證 throughput 與 err 數，內部機制細節需 CockroachDB trace 進一步驗證）
3. **Strict p99 latency 比 RC 約低一半**（t128 5-round mean: 477 vs 926ms）：RC throughput 被 IO wait 卡死，worker queue 拉長 latency；strict 跑得快，queue 短
4. **Starting-gun storm 仍存在但形態不同**：
   - RR: err 集中於前 33s（t16）/ 90s（t128），快速宣告失敗
   - strict: err spread 至 89s（t16）/ 274s（t128），server 持續內部 retry 後才外漏
   - 只有 RC 用 per-statement snapshot 完全免疫

### 業務啟示

- CockroachDB 預設 SERIALIZABLE 不只是「正確性最強」，**在 4 vCPU + single disk 硬體上同時也是最快**（中高並發）
- **不要為了「降 isolation 提升性能」而切 RC**：strict 反而更快、p99 更低
- 若 app 必須 RR/SI 語意，CockroachDB 的 preview RR 在本 workload 上不是好選項 — 同硬體 strict（SSI）跑出 3x 吞吐且 SSI 強度涵蓋 SI 保證
- 與 TiDB rr 比，CockroachDB strict 仍落後：strict t128 10,456 vs TiDB rr t128 13,874（-25%）；TiDB pessimistic lock 路徑對 hot row 的處理仍最有效率

### 結論

CockroachDB v26.2 vm-1node 三 isolation 排序（4 vCPU + single disk）：

```
strict  10,456 tpmC  ← 最快 + 最強 isolation
RC       8,813 tpmC  ← fsync IO bound 早早撞牆
RR       3,788 tpmC  ← retry storm 浪費吞吐
              ↑
        (t128 mean)
```

CockroachDB 設計層面**強烈鼓勵用 SERIALIZABLE**，硬體預算下也最划算。RR 是為 PostgreSQL 兼容性而存在的 preview feature，不應作為性能取捨選項。

---

## vm-3node 系列（4 sub-topology × RC，PoC-DESIGN §6.3.2）

> 本段為 CockroachDB v26.2 在 vm-3node 拓樸 / `READ COMMITTED` 隔離級下的 4 個 sub-topology baseline 規劃。資料填寫前以 `dry-run` anchor 確認 cluster topology / RF / iso preset 與設計一致，再由人工放行 `EXECUTE=1` 進入 prepare/run/collect。

### 共同元件分配（3 顆 VM）

```
            client (.31)
              │  go-tpc → :26257 (cockroach SQL)
              ▼
   ┌──────────┴──────────┐
   │     172.24.40.32    │  ← client 入口 / cockroach init node
   │  cockroach :26257   │
   │  + http :8080       │
   └─────────┬───────────┘
             │ KV multi-Raft (range / lease holder)
   ┌─────────┴────────────────────────┐
   │                                  │
┌──┴──────────────┐         ┌─────────┴────────┐
│  172.24.40.33   │         │   172.24.40.34   │
│  cockroach      │         │   cockroach      │
└─────────────────┘         └──────────────────┘
```

3 個 cockroach node 互為 peer（無 leader 概念，只有 per-range lease holder）；`cockroach init` 一次性 on .32；client 統一 .32:26257 進入。

### vm-3node-1s1r-rc

> 1 shard × 1 replica：3-node cluster + `num_replicas=1`、無 SPLIT。對照 vm-1node-rc 量化「cluster framework + remote coord」純成本。

#### 拓樸示意

```
cockroach cluster (3 nodes, KV peer)
.32 [tpcc ranges leader, RF=1]   .33 (no replicas)   .34 (no replicas)
                ▲ all reads / writes 終究路由到 .32
client .31:go-tpc → .32:26257  (gateway routes; lease holder on .32 for all ranges)
```

#### 關鍵 DB 設定

| 維度 | 設定 | 來源 |
|---|---|---|
| `ALTER DATABASE tpcc CONFIGURE ZONE USING num_replicas` | `1` | prepare 階段（tpcc DB 建好後）|
| `SET CLUSTER SETTING kv.range_split.by_load_enabled` | `false` | `cockroach-vm3.yml` |
| `range_max_bytes` / `range_min_bytes` | `128 GB` / `64 MB` | 防 size split（§7.5.2）|
| Range SPLIT policy | 無 SPLIT；natural 1 range/table |
| `sql.txn.read_committed_isolation.enabled` | `true`（v26.2 預設）| §7.2 |
| `sql.stats.automatic_collection.enabled` | `false` | benchmark control |
| conn-params (RC) | `options=-c default_transaction_isolation=read committed` | §7.2 |

#### Dry-run 預期

- `cluster-topology.txt` ≥ 3 node Up（`cockroach node status`）
- `replication-factor.txt`（default range zone）顯示 `num_replicas = N` — dry-run 階段 tpcc DB 尚未建，僅讀 default zone（系統預設 5），實際 num_replicas=1 由 prepare 階段 ALTER 設定。
- `iso-preset.txt` = `read committed`
- `cluster-health.txt` = `SELECT 1` 回 1

> ⚠️ CRDB dry-run 的 `replication-factor.txt` 讀的是 `RANGE default`（系統預設），不是 tpcc DB 的實際 zone。tpcc DB zone 在 prepare 階段設定，hard gate 由 `crdb_internal.ranges` 計數驗。

#### Execute 結果（2026-06-01，TS=20260601T105859+0800）

5-round mean tpmC（4 thread × 5 round = 20 取樣）：

| threads | tpmC mean | range/mean | NO p99 mean (ms) |
|--------:|----------:|-----------:|-----------------:|
| 16 | 12,954 | 4.1% | 90 |
| 32 | **14,564** | 2.6% | 175（sweet spot）|
| 64 | 14,057 | 22.1% ⚠️ | 389 |
| 128 | 14,260 | 4.8% | 779 |

代表點 = **t=32 / 14,564 tpmC / NO_p99 = 175 ms**。對照 vm-1node-rc（**8,813 tpmC**）→ **+65.3% throughput**（3-node Raft 並行寫入 + leaseholder 分散解單機 fsync 瓶頸；對應 vm-1node §saturation 推測獲得驗證）。t=64 stddev 22% 偏高、t=128 latency 翻倍但 tpmC 邊際 +1.4%。詳見 [5-cell suite dispatch](../../dispatch-records/2026-06-02-crdb-vm3-5cell-suite-dispatch.md)。

### vm-3node-1s3r-rc

> 1 shard × 3 replica：Raft 3-replica leader+2 follower 寫入成本。對照 1s1r 量化「KV Raft replication 成本」。

#### 拓樸示意

```
cockroach cluster (3 nodes)
.32 [tpcc range leaseholder, RF=3]
.33 [tpcc range follower]      ←─┐ Raft majority commit
.34 [tpcc range follower]      ←─┘
client → .32:26257 (gateway 可能路由到任一 leaseholder)
```

#### 關鍵 DB 設定

| 維度 | 設定 |
|---|---|
| `ALTER DATABASE tpcc CONFIGURE ZONE USING num_replicas` | `3` |
| Range SPLIT policy | 無 SPLIT；natural 1 range/table |
| 其餘 | 同 1s1r |

#### Dry-run 預期

- 同 1s1r（注意：dry-run 階段讀的是 default zone，實際 tpcc num_replicas=3 由 prepare 設定）。

#### Execute 結果（2026-06-01，TS=20260601T142702+0800）

5-round mean tpmC：

| threads | tpmC mean | range/mean | NO p99 mean (ms) |
|--------:|----------:|-----------:|-----------------:|
| 16 | 9,432 | 16.2% ⚠️ | 126 |
| 32 | **10,911** | 2.8% | 222（sweet spot）|
| 64 | 10,768 | 22.0% ⚠️ | 493 |
| 128 | 10,381 | 4.4% | 1,007 |

代表點 = **t=32 / 10,911 tpmC / NO_p99 = 222 ms**。對照 1s1r（同 1-shard、RF=1）→ **−25.1% throughput / +26% NO_p99**，量化 Raft 3-replica 寫入 quorum amplification（與 YugabyteDB 1s3r 量到的 -25.5% 高度吻合）。t=16 / t=64 stddev 偏高（16-22%），表示 1s3r 在低或中併發下 Raft commit 路徑波動較大；t=32 / t=128 較穩。

### vm-3node-3s1r-rc

> 3 shard × 1 replica：每 table 3 range 分散到 3 node。對照 1s1r 量化「sharding 對 OLTP 效應」。

#### 拓樸示意

```
cockroach cluster (3 nodes, RF=1)
.32 [t.range-A leaseholder]   .33 [t.range-B leaseholder]   .34 [t.range-C leaseholder]
client → .32:26257 (gateway 路由 leaseholder)
```

#### 關鍵 DB 設定

| 維度 | 設定 |
|---|---|
| `ALTER DATABASE tpcc CONFIGURE ZONE USING num_replicas` | `1` |
| Range SPLIT policy | prepare 階段對 9 張表 `ALTER TABLE ... SPLIT AT VALUES (...)` |
| Hard gate | `crdb_internal.ranges` 9 表 `index_name='primary'` 計數 = 3 |
| 其餘 | 同 1s1r |

#### Dry-run 預期

- 同 1s1r（shard SPLIT 由 prepare 執行 + hard gate 驗）

#### Execute 結果（2026-06-01，TS=20260601T221341+0800 — F-E resume PASS）

> ⚠️ **F-E history SPLIT octal parse**：原 `prepare.sh:156` 用 `'00000086'` 字串字面量，CockroachDB v26.2.0 `strconv.ParseInt(s, 0, 64)` 把前導零視為八進位，digit 8 不合法 → SQLSTATE 22P02、cell 在 prepare SPLIT 階段炸出。修補 commit `0ac53da` 改用裸 int `(1280000), (2560000)` 鏡像 TiDB `_tidb_rowid` 切點；resume batch 從 3s1r 接續成功。失敗 trial TS=`20260601T175625+0800`（不入 canonical）。詳 [dispatch record](../../dispatch-records/2026-06-02-crdb-vm3-5cell-suite-dispatch.md)。

5-round mean tpmC：

| threads | tpmC mean | range/mean | NO p99 mean (ms) |
|--------:|----------:|-----------:|-----------------:|
| 16 | 11,971 | 6.5% | 96 |
| 32 | 13,469 | 8.8% | 191 |
| 64 | **14,051** | 10.7% | 379（sweet spot）|
| 128 | 13,254 | 17.1% ⚠️ | 832 |

代表點 = **t=64 / 14,051 tpmC / NO_p99 = 379 ms**。對照 1s1r（同 RF=1）→ **−3.5% throughput**（CockroachDB sharding 純成本約 4%，遠低於 YugabyteDB 的 -13%；推測 CockroachDB range-leaseholder gateway routing 比 tablet 協調更有效率）。t=128 stddev 17% 偏高，表示 128 thread 撞到 leaseholder 路由協調瓶頸。

### vm-3node-3s3r-rc

> 3 shard × 3 replica：完整 sharded + replicated cluster。對照 1s3r 量化「sharding 在 RF=3 下的攤平效益」；與 3s1r 比 → replication overhead in sharded cluster。

#### 拓樸示意

```
cockroach cluster (3 nodes, RF=3)
.32 [A-leaseholder / B-follower / C-follower]
.33 [A-follower    / B-leaseholder / C-follower]
.34 [A-follower    / B-follower    / C-leaseholder]
client → .32:26257 (gateway 路由 leaseholder for each range)
```

#### 關鍵 DB 設定

| 維度 | 設定 |
|---|---|
| `ALTER DATABASE tpcc CONFIGURE ZONE USING num_replicas` | `3` |
| Range SPLIT policy | prepare 階段對 9 張表 `ALTER TABLE ... SPLIT AT VALUES (...)` |
| 其餘 | 同 3s1r |

#### Dry-run 預期

- 同 1s1r。

#### Execute 結果（2026-06-02，TS=20260602T014253+0800）

5-round mean tpmC：

| threads | tpmC mean | range/mean | NO p99 mean (ms) |
|--------:|----------:|-----------:|-----------------:|
| 16 | 8,873 | 14.7% ⚠️ | 138 |
| 32 | 10,631 | 2.9% | 233 |
| 64 | **11,132** | 3.8% | 473（sweet spot）|
| 128 | 10,931 | 2.7% | 953 |

代表點 = **t=64 / 11,132 tpmC / NO_p99 = 473 ms**。對照 3s1r（同 3-shard）→ **−20.8% throughput**，量化 RF=3 寫入 quorum 成本（與 1s1r→1s3r 量到的 -25% 接近，但 sharded 路徑略低）。對照 1s3r（同 RF=3）→ **+2.0% throughput**（sharding 在 RF=3 下有小幅攤平效益）。CockroachDB 3s3r 的 t=64-128 stddev ≤4%（遠優於 YugabyteDB 3s3r t=16-128 stddev 1,400-2,615 的極不穩），表示 CockroachDB Raft 在 4 vCPU 3-node + 3-shard 仍可穩定運作。

### vm-3node-haproxy-3s3r-rc

> 3 shard × 3 replica + 3 CockroachDB nodes 並接 HAProxy frontend：在 3s3r 基礎上把 client 入口從單 .32 改成 HAProxy 在 .20:26257 round-robin 分流到 .32/.33/.34:26257。量化「分散 SQL 入口」紅利。

#### 拓樸示意

```
                     client (.31)
                       │  go-tpc → 172.24.47.20:26257
                       ▼
            ┌──────────────────────┐
            │  HAProxy on .20:26257 │
            │  balance roundrobin   │
            │  mode tcp             │
            └─────┬────┬────┬───────┘
                  │    │    │
        .32:26257 │    │    │  .34:26257
         cockroach│    │    │   cockroach
                  │ .33:26257│
                  │  cockroach│
   底層 cluster：3-node KV peer，RF=3，per-range leaseholder
```

#### 關鍵 DB 設定（與 3s3r 完全相同；唯一變因是 SQL frontend）

| 維度 | 設定 |
|---|---|
| `ALTER DATABASE tpcc CONFIGURE ZONE USING num_replicas` | `3` |
| `kv.range_split.by_load_enabled` | `false` |
| `range_max_bytes` | `128 GB` |
| HAProxy timeout | client/server 各 1800s |
| HAProxy balance | `roundrobin` `mode tcp` |
| client `--db-host` | `172.24.47.20:26257`（HAProxy frontend） |

#### Dry-run 預期

- `actual-rf` 同 3s3r = 3
- HAProxy backend health：3 個 server check OK（cfg 中 `check inter 2s`）
- F-A-v2 / F-D / F-E 修補後 dry-run-confirm 全程 PASS

#### Execute 結果（2026-06-02，TS=20260602T051500+0800）

5-round mean tpmC：

| threads | tpmC mean | range/mean | NO p99 mean (ms) |
|--------:|----------:|-----------:|-----------------:|
| 16 | 10,113 | 5.4% | 114 |
| 32 | 11,922 | 6.3% | 203 |
| 64 | 13,444 | 8.9% | 376 |
| 128 | **15,033** | 6.9% | 718（sweet spot at scale）|

代表點 = **t=128 / 15,033 tpmC / NO_p99 = 718 ms**。對照 direct 3s3r（同 RF=3、同 3-shard）→ **+37.5% throughput @ t=128**（CockroachDB direct 模式 client 已連 .32，gateway 已具備內部 lease 路由能力，故 HAProxy 收益 +37.5% 比 TiDB / YugabyteDB 的 +78% 小；CockroachDB 真正能釋放 multi-node 並行的場景需要在 single-entry 與 round-robin 之間多測拓樸變數）。Stability：t=16-128 range/mean ≤8.9%，遠優於 direct 3s3r 在 t=128 的 17.1%。

跨 cell 詳細分析 → [`dispatch-records/2026-06-02-crdb-vm3-5cell-suite-dispatch.md`](../../dispatch-records/2026-06-02-crdb-vm3-5cell-suite-dispatch.md)。

