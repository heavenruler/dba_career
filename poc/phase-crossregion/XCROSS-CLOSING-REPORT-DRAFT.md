# X-CROSS 階段結案報告（雛形）— IDC↔GCP Cross-Region 3-DB W=128 正式測試

> 狀態：**雛形（draft）**。所有數字取自實際執行的四份 W=128 採樣，無任何模擬/示範資料。
> 每項參數與結論均以連結指向原始採樣檔案。產出日：2026-07-12（07-13 補逐 DB 連結）。

採樣目錄縮寫（下文連結均出自這四個 suite 目錄）：

| 縮寫 | 採用 | Suite 目錄 |
|---|---|---|
| **TiDB#1**（首輪） | ❌ 備查（t128 CV 102.2%，§6） | [tidb-vm-6node-P-A-rc-20260711T215200+0800](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/) |
| **CRDB** | ✅ | [crdb-vm-6node-P-A-rc-20260711T215200+0800](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/) |
| **YBDB** | ✅ | [ybdb-vm-6node-P-A-rc-20260711T215200+0800](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/) |
| **TiDB#4**（重跑） | ✅ | [tidb-vm-6node-P-A-rc-20260712T164221+0800](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/) |

## 1. 目的與範圍

驗證 TiDB / CockroachDB / YugabyteDB 三家分散式 SQL 在 6-node cross-region
（3 IDC + 3 GCP）拓樸、P-A placement（leader/lease pin IDC、GCP 就近讀）下，
以正式口徑 TPC-C W=128 量測吞吐與延遲，作為 X-CROSS 階段的結案數據。

不在本報告範圍：P-B placement 變體、failover 演練、跨家正式排名
（X-CROSS 於 phase registry 為 `baseline_eligible=false`，僅作 cross-region
framework / 相對量級證據；見 [results/PHASES.md](../results/PHASES.md)）。

## 2. 各 suite 證據檔索引

### 2.1 機器可讀彙整（primary 取數來源）

- TiDB#1: [summary.json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/summary.json)
- CRDB: [summary.json](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/summary.json)
- YBDB: [summary.json](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/summary.json)
- TiDB#4: [summary.json](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/summary.json)

### 2.2 每輪原始 go-tpc 輸出（`runs/threads-{16,32,64,128}/round-{1..5}/go-tpc-stdout.txt`）

- TiDB#1: [runs/](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/runs/)（例：[threads-128/round-2/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/runs/threads-128/round-2/go-tpc-stdout.txt)＝腰斬首輪證據）
- CRDB: [runs/](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/runs/)（例：[threads-128/round-1/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/runs/threads-128/round-1/go-tpc-stdout.txt)）
- YBDB: [runs/](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/runs/)（例：[threads-128/round-1/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/runs/threads-128/round-1/go-tpc-stdout.txt)）
- TiDB#4: [runs/](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/runs/)（例：[threads-128/round-2/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/runs/threads-128/round-2/go-tpc-stdout.txt)＝重跑同輪位對照）

### 2.3 Placement gate（prepare 後驗收，四份全 PASS、gcp_leader_count=0）

- TiDB#1: [prepare/placement-gate-P-A.json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)（idc=19/19）
- CRDB: [prepare/placement-gate-P-A.json](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)（idc=11/11）
- YBDB: [prepare/placement-gate-P-A.json](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)（idc=3/3）
- TiDB#4: [prepare/placement-gate-P-A.json](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/prepare/placement-gate-P-A.json)（idc=19/19）

### 2.4 就近讀設定快照

- TiDB#1: [prepare/near-read-vars.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/prepare/near-read-vars.txt)（`tidb_replica_read=closest-replicas`）
- CRDB: [prepare/near-read-vars.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/prepare/near-read-vars.txt)（`follower_reads.enabled=t`）
- YBDB: [prepare/near-read-vars.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/prepare/near-read-vars.txt)（`yb_read_from_followers=on`, staleness 30000ms）
- TiDB#4: [prepare/near-read-vars.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/prepare/near-read-vars.txt)

### 2.5 跑後 leader/lease 分布快照

- TiDB#1: [leader-snapshot/tidb-region-leaders.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/tidb-region-leaders.txt)（⚠ 舊查詢無 tpcc 過濾，含系統 region 雜訊，§6）
- CRDB: [leader-snapshot/crdb-lease-holders.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/crdb-lease-holders.txt)（lease 全在 IDC node 1/4/5）＋ [crdb-nodes.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/crdb-nodes.txt)（6 node locality/版本）
- YBDB: [leader-snapshot/ybdb-leader-counts.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/ybdb-leader-counts.txt)＋[ybdb-tservers.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/ybdb-tservers.txt)＋[ybdb-universe-config.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/ybdb-universe-config.txt)（liveReplicas=idc RF3 + readReplicas=gcp）
- TiDB#4: [leader-snapshot/tidb-region-leaders.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/leader-snapshot/tidb-region-leaders.txt)（修正後 tpcc-scoped：IDC 3 store 8/8/3，0 GCP）

### 2.6 Scheduler/balancer 凍結證據（`freeze-state/`）

- TiDB#1 / TiDB#4：**無 `freeze-state/` dump**——w128 鏈的 TiDB freeze 由 Makefile 直呼 PD API 執行，未落 dump 檔（smoke 鏈才有 `pd-config-before.json`）。屬證據缺口，列 §7。
- CRDB: [freeze-state/crdb-lease-rebal-before.tsv](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/freeze-state/crdb-lease-rebal-before.tsv)＋[crdb-split-load-before.tsv](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/freeze-state/crdb-split-load-before.tsv)
- YBDB: [freeze-state/yb-lb-state-before.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/freeze-state/yb-lb-state-before.txt)＋[yb-universe-before.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/freeze-state/yb-universe-before.txt)

### 2.7 環境 gate（chrony / OS / disk / 隔離）

- TiDB#1: [gate/](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/gate/)（[chrony-gate.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/gate/chrony-gate.txt)）
- CRDB: [gate/](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/gate/)（[chrony-gate.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/gate/chrony-gate.txt)）
- YBDB: [gate/](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/gate/)（[chrony-gate.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/gate/chrony-gate.txt)）
- TiDB#4: [gate/](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/gate/)（[chrony-gate.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/gate/chrony-gate.txt)）

### 2.8 WAN 探測（RTT / 頻寬 / 時鐘；warmup 級，round 級在各 round 目錄）

- TiDB#1: [runs/wan-probe-warmup.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/runs/wan-probe-warmup.txt)
- CRDB: [runs/wan-probe-warmup.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/runs/wan-probe-warmup.txt)（iperf3 rtt=8504-8539µs、191-227 Mbps）
- YBDB: [runs/wan-probe-warmup.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/runs/wan-probe-warmup.txt)
- TiDB#4: [runs/wan-probe-warmup.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/runs/wan-probe-warmup.txt)

### 2.9 DB 有效設定 dump（`db-config/`）

- TiDB#1: [db-config/effective-config.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/db-config/effective-config.txt)
- CRDB: [db-config/cluster-settings.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/db-config/cluster-settings.txt)＋[effective-config.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/db-config/effective-config.txt)
- YBDB: [db-config/cluster-settings.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/db-config/cluster-settings.txt)＋[effective-config.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/db-config/effective-config.txt)
- TiDB#4: [db-config/effective-config.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/db-config/effective-config.txt)

### 2.10 OS/主機環境（`env/`）與批次完整性

- TiDB#1: [env/db-host-snapshot.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/env/db-host-snapshot.txt)・[env/kernel.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/env/kernel.txt)
- CRDB: [env/db-host-snapshot.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/env/db-host-snapshot.txt)・[env/kernel.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/env/kernel.txt)
- YBDB: [env/db-host-snapshot.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/env/db-host-snapshot.txt)・[env/kernel.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/env/kernel.txt)
- TiDB#4: [env/db-host-snapshot.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/env/db-host-snapshot.txt)・[env/kernel.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/env/kernel.txt)
- 批次級（每 TS 一份）：VM 重建證明 [07-11 批](../results/x-cross/baseline/w128/20260711T215200+0800/vm-rebuild-proof-20260711T215200+0800.json)／[07-12 批](../results/x-cross/baseline/w128/20260712T164221+0800/vm-rebuild-proof-20260712T164221+0800.json)；fetch 完整性收據 [07-11 批](../results/x-cross/baseline/w128/20260711T215200+0800/fetch-receipt.json)／[07-12 批](../results/x-cross/baseline/w128/20260712T164221+0800/fetch-receipt.json)

## 3. 測試環境

| 項目 | 值 | 佐證 |
|---|---|---|
| 拓樸 | 6 DB node = 3 IDC（172.24.40.32-34, vSphere）+ 3 GCP（10.160.152.11-13, asia-east1-a/b/c）；client/driver = .31（IDC） | §2.10 `env/db-host-snapshot.txt` 各 DB 連結 |
| OS / kernel | AlmaLinux 8.10，4.18.0-553.124.1.el8_10（DB hosts） | §2.10 `env/kernel.txt` 各 DB 連結 |
| DB 版本 | TiDB v8.5.2 / CRDB v26.2.0 / YBDB 2025.2.2.2-b11 | ansible playbook version vars；CRDB 另見 §2.5 `crdb-nodes.txt` build 欄 |
| WAN RTT（IDC↔GCP） | ~8.5 ms | §2.8 各 DB `wan-probe-warmup.txt` iperf3 tcp_info |
| WAN 頻寬（探測值） | ~191-227 Mbps | 同上 |
| 時鐘同步 | chrony 10-host gate PASS，offset µs 級 | §2.7 各 DB `chrony-gate.txt` |
| VM 潔淨度 | 每 TS 全 VM 重建，boot_id 留證 | §2.10 vm-rebuild-proof 兩批連結 |

## 4. 測試口徑（參數 → 佐證）

| 參數 | 值 | 佐證 |
|---|---|---|
| Workload | go-tpc TPC-C | §2.2 各 DB go-tpc-stdout 連結 |
| WAREHOUSES | 128 | §2.1 各 DB `summary.json` `warehouses` 欄 |
| Threads 檔位 | 16 / 32 / 64 / 128 | 同上 `threads_list` 欄 |
| Rounds | 每檔 5 輪 × 300 s | 同上 `rounds_per_thread_group`；§2.2 round 目錄 |
| Warmup | 1200 s（每檔位前） | 各 suite `runs/warmup.log`；[Makefile `WARMUP_SEC=1200`](Makefile) |
| Primary estimator | tpmC_mean = R1-R5 mean（per [PHASES.md](../results/PHASES.md) §5） | §2.1 `thread_results.<t>.tpmC_mean`、`skip_rounds: 0` |
| Placement | P-A（leader/lease pin IDC），gcp_leader_count=0 | §2.3 各 DB placement-gate 連結 |
| 就近讀設定 | TiDB closest-replicas / CRDB follower_reads / YBDB read_from_followers | §2.4 各 DB near-read-vars 連結 |
| Scheduler/balancer 凍結 | 量測前 freeze、量測後 unfreeze | §2.6（CRDB/YBDB 有 dump；TiDB w128 鏈缺 dump，§7） |
| Client zone | idc（.31，不跨區打流量） | [Makefile](Makefile) hard contract `CLIENT_ZONE=idc` |
| 執行入口 | [`make phase-crossregion-w128-suite`](Makefile)（07-11 批）；TiDB#4 為同 knobs 之 TiDB-only 鏈 | [SESSION-HISTORY.md](SESSION-HISTORY.md) 2026-07-11/12 節 |

**YBDB 拓樸語意差異（必讀）**：YBDB 採 live_replicas=IDC-only RF=3 + GCP 3 台
read_replica（`phase4-ybdb-fix6n` Plan B），GCP 不參與 quorum；TiDB/CRDB 則為
6-voter、以 placement policy/zone config 將 leader/lease pin 在 IDC。跨家比較時
YBDB 寫入路徑天生少一段跨區複製，屬設計選項差異而非量測誤差。
佐證：§2.5 YBDB `ybdb-universe-config.txt`。

## 5. 主結果（採用 cell：TiDB#4、CRDB、YBDB）

tpmC_mean（R1-R5）；CV = `tpmC_range_mean_pct`；延遲 = NEW_ORDER p50/p95/p99 mean (ms)。
逐輪原始值：§2.1 各 `summary.json` `thread_results.<t>.tpmC_per_round`；
逐輪完整輸出：§2.2 各 round `go-tpc-stdout.txt`。

| threads | TiDB tpmC (CV) | CRDB tpmC (CV) | YBDB tpmC (CV) |
|---:|---:|---:|---:|
| 16 | 2077.1 (3.6%) | 8776.9 (6.6%) | 7836.8 (2.9%) |
| 32 | 3820.8 (28.0%*) | 9963.9 (5.8%) | 8991.4 (9.3%) |
| 64 | 7681.8 (4.6%) | 10249.7 (2.0%) | 9727.0 (8.9%) |
| **128（主水位）** | **13251.6 (4.0%)** | **10453.5 (5.2%)** | **9581.4 (8.6%)** |

| t128 延遲 | p50 | p95 | p99 |
|---|---:|---:|---:|
| TiDB | 332.2 | 479.8 | 630.8 |
| CRDB | 379.2 | 765.1 | 993.2 |
| YBDB | 493.2 | 771.8 | 1060.3 |

- 交易錯誤：三家四檔全程 **0 error**（TiDB 1,490,296 / CRDB 2,189,931 /
  YBDB 2,000,524 筆；§2.1 `thread_results.<t>.all_txn.error_count`）。
- \* TiDB t32 CV 28.0% 來自單輪 dip（R2=3048.1，其餘 3965-4119），非持續性；
  原始輪值見 TiDB#4 [summary.json](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/summary.json) `thread_results.32.tpmC_per_round`
  與 [runs/threads-32/round-2/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/runs/threads-32/round-2/go-tpc-stdout.txt)。
- 低 thread 檔位形狀差異：TiDB t16 明顯低於 CRDB/YBDB（跨區 TSO/2PC 延遲敏感，
  隨並發放大而攤平）；t128 反超為三家最高。efficiency% 欄為無 think/keying 口徑，
  依既有慣例忽略（見 [pipeline-log.md](../results/x-cross/pipeline-log.md) §2.3 效度邊界）。

## 6. TiDB 首輪 t128 異常與重跑驗證（TiDB#1 → TiDB#4）

- TiDB#1 t128 五輪 tpmC = 13601.5 / 6513.7 / 6030.0 / 5855.2 / 5879.5，CV 102.2%
  ——R2 起腰斬盤整，全程 0 error、無 retry/warn。
  原始值：TiDB#1 [summary.json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/summary.json) `thread_results.128.tpmC_per_round`；
  腰斬起點輪：[runs/threads-128/round-2/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/runs/threads-128/round-2/go-tpc-stdout.txt)。
- 排查中同時抓到量測腳本舊 bug：post-run leader-snapshot SQL 缺 `DB_NAME='tpcc'`
  過濾，把系統 schema region 的 leader 算進 GCP，一度誤判為「P-A leader 漂移」
  （誤導性快照：TiDB#1 [leader-snapshot/tidb-region-leaders.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/tidb-region-leaders.txt)）。
  以 tpcc-scoped gate 查詢（跑完首次輪詢即 100% IDC）證偽後修正
  [Makefile](Makefile) snapshot 查詢（commit `621f24f1`）。
- TiDB#4 重跑同 knobs：t128 五輪 13188.2 / 13087.6 / 13268.1 / 13099.1 / 13614.8，
  CV 4.0%；修正後快照顯示 tpcc leader 只在 3 台 IDC store（8/8/3）、0 GCP：
  TiDB#4 [leader-snapshot/tidb-region-leaders.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/leader-snapshot/tidb-region-leaders.txt)。
- 判定：首輪異常為單次環境雜訊（不可重現；首輪 VM 已拆無法回溯 TiKV metrics），
  **採用 TiDB#4、TiDB#1 保留備查不採用**。詳細過程：
  [SESSION-HISTORY.md](SESSION-HISTORY.md) 2026-07-11/12 兩節；commits `621f24f1`、`5c4a9bcc`。

## 7. 效度邊界與未竟事項

1. **批次差**：CRDB/YBDB（07-11 批）與採用的 TiDB#4（07-12 批）非同一 VM
   生命週期；三家「同批次」數據僅存在於 07-11 批（但其 TiDB t128 無效）。
   若結案要求嚴格同批次，需再跑一輪三家 suite（~11 hr）。
2. **TiDB freeze dump 缺口**：w128 鏈 TiDB 無 `freeze-state/` 落檔（§2.6），
   凍結動作有執行（Makefile PD API）但無 before-dump 佐證；補齊需在 TiDB w128
   鏈加 dump 步驟後重跑。
3. X-CROSS `baseline_eligible=false` 不變：本報告數字供 cross-region 能力與
   相對量級判讀，不進 S-BASE/S-K8S 跨家正式排名。
4. 與 07-03 TiDB cell（16,808.6 / CV 2.4%，[baseline/w128/20260703T092243+0800/](../results/x-cross/baseline/w128/20260703T092243+0800/)）
   相比，本輪 TiDB t128 低約 21%——跨批次環境變異，兩者皆為有效 cell；引用時
   註明批次。
5. P-B placement、A-A profile、failover 場景未涵蓋；YBDB read-replica 架構語意
   差異見 §4。

## 8. 追溯索引

- 執行歷史：[SESSION-HISTORY.md](SESSION-HISTORY.md)（2026-07-11/12 W=128 首輪、07-12（續）TiDB 重跑）
- Smoke 前置：[SMOKE-STAGE1-SUMMARY.md](SMOKE-STAGE1-SUMMARY.md)（Stage 1 三家 smoke，07-08/09）
- 資料主檔：[results/x-cross/pipeline-log.md](../results/x-cross/pipeline-log.md)（採用/不採用登記）
- Commits：`621f24f1`（首輪數據 + snapshot SQL 修正）、`5c4a9bcc`（TiDB 重跑數據）、`d3bfbf04`（本報告初版）
