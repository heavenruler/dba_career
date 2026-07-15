# X-CROSS 階段結案報告（雛形）— IDC↔GCP Cross-Region 3-DB W=128 正式測試

> 狀態：**雛形（draft）**。所有數字取自實際執行的 W=128 採樣，無任何模擬/示範資料。
> 每項參數與結論均以連結指向原始採樣檔案。產出日：2026-07-12（07-15 回填
> CRDB/YBDB 修正後重測 cell，取代 07-11 批降級數據）。

採樣目錄縮寫：

| 縮寫 | 採用 | Suite 目錄 |
|---|---|---|
| **TiDB#1**（首輪） | ❌ 備查（t128 CV 102.2%，§6） | [tidb-vm-6node-P-A-rc-20260711T215200+0800](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/) |
| **CRDB#1** | ❌ 備查（GCP 零副本，§7.0） | [crdb-vm-6node-P-A-rc-20260711T215200+0800](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/) |
| **YBDB#1** | ❌ 備查（GCP 零副本，§7.0） | [ybdb-vm-6node-P-A-rc-20260711T215200+0800](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/) |
| **TiDB#4**（重跑） | ✅ | [tidb-vm-6node-P-A-rc-20260712T164221+0800](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/) |
| **CRDB#2**（修正後） | ✅ | [crdb-vm-6node-P-A-rc-20260714T163716+0800](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/) |
| **YBDB#2**（修正後） | ✅（帶 §5 caveat） | [ybdb-vm-6node-P-A-rc-20260714T163716+0800](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/) |

CRDB#2/YBDB#2 的關鍵新證據（GCP 副本存在 gate + GCP 端 probe，07-11 批缺漏的兩層）：
[CRDB gcp-replica-gate](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/gate/gcp-replica-gate-crdb.txt)（ranges_missing_gcp_replica=0）・
[YBDB gcp-replica-gate](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/gate/gcp-replica-gate-ybdb.txt)（3/3 GCP tserver SST>0）・
GCP 端 probe 各 20 輪全 `fail_count=0`（例：[CRDB t128 r1](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/runs/threads-128/round-1/probe-iso-latency-gcp-t128-r1.json)／[YBDB t128 r1](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/runs/threads-128/round-1/probe-iso-latency-gcp-t128-r1.json)）。

## 1. 目的與範圍

驗證 TiDB / CockroachDB / YugabyteDB 三家分散式 SQL 在 6-node cross-region
（3 IDC + 3 GCP）拓樸、P-A placement（leader/lease pin IDC、GCP 就近讀）下，
以正式口徑 TPC-C W=128 量測吞吐與延遲，作為 X-CROSS 階段的結案數據。

不在本報告範圍：P-B placement 變體、failover 演練、跨家正式排名
（X-CROSS 於 phase registry 為 `baseline_eligible=false`，僅作 cross-region
framework / 相對量級證據；見 [results/PHASES.md](../results/PHASES.md)）。

## 2. 各 suite 證據檔索引

### 2.1 機器可讀彙整（primary 取數來源）

- TiDB#4: [summary.json](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/summary.json)
- CRDB#2: [summary.json](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/summary.json)
- YBDB#2: [summary.json](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/summary.json)
- 備查批：TiDB#1 [summary.json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/summary.json)・CRDB#1 [summary.json](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/summary.json)・YBDB#1 [summary.json](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/summary.json)

### 2.2 每輪原始 go-tpc 輸出（`runs/threads-{16,32,64,128}/round-{1..5}/go-tpc-stdout.txt`）

- TiDB#4: [runs/](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/runs/)（例：[threads-128/round-2/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/runs/threads-128/round-2/go-tpc-stdout.txt)＝與 TiDB#1 腰斬輪同輪位對照）
- CRDB#2: [runs/](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/runs/)（例：[threads-128/round-1/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/runs/threads-128/round-1/go-tpc-stdout.txt)）
- YBDB#2: [runs/](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/runs/)（例：[threads-128/round-1/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/runs/threads-128/round-1/go-tpc-stdout.txt)；§5 † 錯誤樣本可在 t32/t64/t128 各 round 檔 grep `execute run failed`）
- 備查批：TiDB#1 [runs/threads-128/round-2/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/runs/threads-128/round-2/go-tpc-stdout.txt)（腰斬首輪證據）・CRDB#1 [runs/](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/runs/)・YBDB#1 [runs/](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/runs/)

### 2.3 Placement gate（prepare 後驗收，採用三份全 PASS、gcp_leader_count=0）

- TiDB#4: [prepare/placement-gate-P-A.json](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/prepare/placement-gate-P-A.json)（idc=19/19）
- CRDB#2: [prepare/placement-gate-P-A.json](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/prepare/placement-gate-P-A.json)（idc=11/11；計數口徑為 07-14 修正後的 lease 單欄版，§7.0 第七問題）
- YBDB#2: [prepare/placement-gate-P-A.json](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/prepare/placement-gate-P-A.json)（idc=3/3）
- 備查批：TiDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)（idc=19/19）・CRDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)（idc=11/11，但當時計數口徑有誤且 GCP 零副本）・YBDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)（idc=3/3，GCP 零副本）

### 2.3b GCP 副本存在 gate（07-14 新增，fail-closed；備查批無此證據＝當時盲區）

- CRDB#2: [gate/gcp-replica-gate-crdb.txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/gate/gcp-replica-gate-crdb.txt)（ranges_missing_gcp_replica=0、gcp_leaseholders=0）
- YBDB#2: [gate/gcp-replica-gate-ybdb.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/gate/gcp-replica-gate-ybdb.txt)（3/3 GCP tserver SST>0）＋[gcp-replica-gate-ybdb-universe.json](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/gate/gcp-replica-gate-ybdb-universe.json)（live=idc:2+gcp:1）

### 2.4 就近讀設定快照

- TiDB#4: [prepare/near-read-vars.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/prepare/near-read-vars.txt)（`tidb_replica_read=closest-replicas`）
- CRDB#2: [prepare/near-read-vars.txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/prepare/near-read-vars.txt)（`follower_reads.enabled=t`）
- YBDB#2: [prepare/near-read-vars.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/prepare/near-read-vars.txt)（`yb_read_from_followers=on`, staleness 30000ms）
- 設定生效的**執行面**證明＝GCP 端 probe（07-14 起才有，見縮寫表下方連結；備查批 probe 因 client 缺失全滅，只能證明「設定有下」）。

### 2.5 跑後 leader/lease 分布快照

- TiDB#4: [leader-snapshot/tidb-region-leaders.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/leader-snapshot/tidb-region-leaders.txt)（tpcc-scoped 修正後查詢：IDC 3 store 8/8/3，0 GCP）
- CRDB#2: [leader-snapshot/crdb-lease-holders.txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/leader-snapshot/crdb-lease-holders.txt)＋[crdb-nodes.txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/leader-snapshot/crdb-nodes.txt)（6 node locality/版本）
- YBDB#2: [leader-snapshot/ybdb-leader-counts.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/leader-snapshot/ybdb-leader-counts.txt)＋[ybdb-tservers.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/leader-snapshot/ybdb-tservers.txt)（6/6 皆有 SST，對照 YBDB#1 GCP 全 0B）＋[ybdb-universe-config.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/leader-snapshot/ybdb-universe-config.txt)（live=idc:2+gcp(asia-east1):1，preferred zone idc）
- 備查批誤導/缺陷快照（§6/§7.0 佐證）：TiDB#1 [無過濾 leader 快照](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/tidb-region-leaders.txt)・YBDB#1 [ybdb-tservers.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/ybdb-tservers.txt)（GCP SST=0B 鐵證）

### 2.6 Scheduler/balancer 凍結證據（`freeze-state/`）

- TiDB#1 / TiDB#4：**無 `freeze-state/` dump**——w128 鏈的 TiDB freeze 由 Makefile 直呼 PD API 執行，未落 dump 檔（smoke 鏈才有 `pd-config-before.json`）。屬證據缺口，列 §7。
- CRDB#2: [freeze-state/crdb-lease-rebal-before.tsv](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/freeze-state/crdb-lease-rebal-before.tsv)＋[crdb-split-load-before.tsv](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/freeze-state/crdb-split-load-before.tsv)
- YBDB#2: [freeze-state/yb-lb-state-before.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/freeze-state/yb-lb-state-before.txt)＋[yb-universe-before.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/freeze-state/yb-universe-before.txt)

### 2.7 環境 gate（chrony / OS / disk / 隔離）

- TiDB#4: [gate/](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/gate/)（[chrony-gate.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/gate/chrony-gate.txt)）
- CRDB#2: [gate/](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/gate/)（[chrony-gate.txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/gate/chrony-gate.txt)）
- YBDB#2: [gate/](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/gate/)（[chrony-gate.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/gate/chrony-gate.txt)）

### 2.8 WAN 探測（RTT / 頻寬 / 時鐘；warmup 級，round 級在各 round 目錄）

- TiDB#4: [runs/wan-probe-warmup.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/runs/wan-probe-warmup.txt)
- CRDB#2: [runs/wan-probe-warmup.txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/runs/wan-probe-warmup.txt)（iperf3 rtt≈8.1ms）
- YBDB#2: [runs/wan-probe-warmup.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/runs/wan-probe-warmup.txt)
- 07-11 批參考值：CRDB#1 [wan-probe-warmup.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/runs/wan-probe-warmup.txt)（rtt=8504-8539µs、191-227 Mbps）

### 2.9 DB 有效設定 dump（`db-config/`）

- TiDB#4: [db-config/effective-config.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/db-config/effective-config.txt)
- CRDB#2: [db-config/cluster-settings.txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/db-config/cluster-settings.txt)＋[effective-config.txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/db-config/effective-config.txt)
- YBDB#2: [db-config/cluster-settings.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/db-config/cluster-settings.txt)＋[effective-config.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/db-config/effective-config.txt)

### 2.10 OS/主機環境（`env/`）與批次完整性

- TiDB#4: [env/db-host-snapshot.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/env/db-host-snapshot.txt)・[env/kernel.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/env/kernel.txt)
- CRDB#2: [env/db-host-snapshot.txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/env/db-host-snapshot.txt)・[env/kernel.txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/env/kernel.txt)
- YBDB#2: [env/db-host-snapshot.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/env/db-host-snapshot.txt)・[env/kernel.txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/env/kernel.txt)
- 批次級（每 TS 一份）：VM 重建證明 [07-11 批](../results/x-cross/baseline/w128/20260711T215200+0800/vm-rebuild-proof-20260711T215200+0800.json)／[07-12 批](../results/x-cross/baseline/w128/20260712T164221+0800/vm-rebuild-proof-20260712T164221+0800.json)／[07-14 批](../results/x-cross/baseline/w128/20260714T163716+0800/vm-rebuild-proof-20260714T163716+0800.json)；fetch 完整性收據 [07-11 批](../results/x-cross/baseline/w128/20260711T215200+0800/fetch-receipt.json)／[07-12 批](../results/x-cross/baseline/w128/20260712T164221+0800/fetch-receipt.json)／[07-14 批](../results/x-cross/baseline/w128/20260714T163716+0800/fetch-receipt.json)

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
| 執行入口 | TiDB#4：Mac 端 TiDB-only 鏈（07-12）；CRDB#2/YBDB#2：[`make win-ybdb-crdb-detach`](Makefile) `.31` detached 指揮鏈（07-14，Mac 可關機） | [SESSION-HISTORY.md](SESSION-HISTORY.md) 2026-07-12 / 07-14（續）節 |

**三家副本語意（07-14 起對齊）**：每筆資料 RF=3 = **2 IDC voter + 1 GCP voter**，
leader/lease 以 policy／zone config／preferred_zones pin 在 IDC，commit quorum
由 IDC pair 滿足（不等 WAN），GCP voter 持續收 raft log——三家在「寫入路徑
付出的跨區複製成本」上口徑一致，可作同語意比較。YBDB 由早期 read-replica
設計（從未實體化，§7.0）改為 live voter + GCP 三台統一 placement_zone
`asia-east1`（LB 均衡分擔）。佐證：§2.5 YBDB#2 `ybdb-universe-config.txt`
（live=idc:2+gcp:1）、§2.3b 兩家 gcp-replica-gate。**殘留語意差**：YBDB 的
transaction status tablet（系統層）leader 未被 gate 覆蓋，部分落 GCP 造成
§5 † 的少量跨 WAN 協調錯誤；TiDB/CRDB 的交易記錄跟隨資料表 region/range，
lease pin 已覆蓋，無此問題。

## 5. 主結果（採用 cell：TiDB#4、CRDB#2、YBDB#2）

> **2026-07-15 回填**：07-13 效度警示（CRDB#1/YBDB#1 GCP 零副本）之五根因修正
> 後重測，CRDB#2/YBDB#2 均通過三重驗證：placement gate、gcp-replica-gate
> （逐 range/tablet 驗 GCP 副本存在）、GCP 端 probe 各 20 輪 fail_count=0。
> 本表的 CRDB/YBDB 數字**帶真實跨區複製成本**，與 07-11 批（未付 WAN 成本、
> 已降級）不可比。TiDB#4 為 07-12 批，批次差見 §7.1。

tpmC_mean（R1-R5）；CV = `tpmC_range_mean_pct`；延遲 = NEW_ORDER p50/p95/p99 mean (ms)。
逐輪原始值：各 `summary.json` `thread_results.<t>.tpmC_per_round`；
逐輪完整輸出：各 round `go-tpc-stdout.txt`。

| threads | TiDB tpmC (CV) | CRDB tpmC (CV) | YBDB tpmC (CV) |
|---:|---:|---:|---:|
| 16 | 2077.1 (3.6%) | 9478.9 (15.2%) | 7207.5 (7.8%) |
| 32 | 3820.8 (28.0%*) | 10364.3 (6.2%) | 8148.7 (41.9%†) |
| 64 | 7681.8 (4.6%) | 10809.3 (4.7%) | 10904.1 (11.5%) |
| **128（主水位）** | **13251.6 (4.0%)** | **11001.1 (4.8%)** | **11138.6 (10.4%)** |

| t128 延遲 | p50 | p95 | p99 |
|---|---:|---:|---:|
| TiDB | 332.2 | 479.8 | 630.8 |
| CRDB | 379.2 | 724.8 | 959.7 |
| YBDB | 375.8 | 697.9 | 1214.7 |

- 交易錯誤：TiDB 與 CRDB 全程 **0 error**（TiDB 1,490,296 / CRDB 2,314,032 筆）；
  **YBDB t32/t64/t128 共 309 筆錯誤（率 0.011-0.03%）**——†見下：與 t32 dip 輪
  同源於「transaction status tablet leader 落 GCP」問題（SESSION-HISTORY
  2026-07-14（續）第六問題）：部分交易的 commit 協調跨 WAN 撞 5s RPC deadline。
  placement/replica gate 只驗 tpcc 表、系統層 tablet 漏網；引用 YBDB 數字必須
  帶此 caveat，gate 補強（status tablet leader 檢查 + stepdown）排入下輪。
  此現象本身是 P-A 語意下系統層跨區成本的真實證據。
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

0. **（已結案 2026-07-15）CRDB/YBDB GCP 零副本**：五根因全數修正並以 CRDB#2/
   YBDB#2 重測驗證（§5）——CRDB constraints counted-form、YBDB live 2+1 +
   統一 zone、probe 直打 GCP 節點、probe 主機補裝 DB clients（第五根因：
   `.15` 從無 client，四 suite probe 全滅實為 command-not-found）、CRDB gate
   grep 整行計數 bug（第七問題，經授權修 `prepare.sh`）。防再犯機制已入鏈：
   `gcp-replica-gate.sh`（fail-closed）+ static-check probe 斷言 +
   `phase2-probe-clients`。**遺留**：YBDB status tablet leader 落 GCP
   （§5 †，第六問題）gate 補強排入下輪。
1. **批次差**：採用的三個 cell 橫跨兩批——TiDB#4（07-12 批）與 CRDB#2/YBDB#2
   （07-14 批，同批同 VM 生命週期）。TiDB 與另兩家非同批；且 TiDB#4 量測時
   CRDB/YBDB 語意修正尚未存在，嚴格同批同語意的三家數據目前不存在。若結案
   要求，需以現行修正後管線（含 gcp-replica-gate + probe 斷言）再跑一輪
   三家 suite（~11 hr）。
2. **TiDB freeze dump 缺口**：w128 鏈 TiDB 無 `freeze-state/` 落檔（§2.6），
   凍結動作有執行（Makefile PD API）但無 before-dump 佐證；補齊需在 TiDB w128
   鏈加 dump 步驟後重跑。
3. X-CROSS `baseline_eligible=false` 不變：本報告數字供 cross-region 能力與
   相對量級判讀，不進 S-BASE/S-K8S 跨家正式排名。
4. 與 07-03 TiDB cell（16,808.6 / CV 2.4%，[baseline/w128/20260703T092243+0800/](../results/x-cross/baseline/w128/20260703T092243+0800/)）
   相比，本輪 TiDB t128 低約 21%——跨批次環境變異，兩者皆為有效 cell；引用時
   註明批次。
5. P-B placement、A-A profile、failover 場景未涵蓋；三家副本語意已對齊（§4），
   殘留的 YBDB 系統層 tablet 差異見 §4/§5 †。
6. **IDC VM 收尾**：07-14 批 GCP 5 台已 destroy；IDC 3 台因 vSphere API 夜間
   斷線（連三晚同模式）destroy 待補，不影響本報告數據。

## 8. 追溯索引

- 執行歷史：[SESSION-HISTORY.md](SESSION-HISTORY.md)（2026-07-11/12 首輪與 TiDB
  重跑、07-13 GCP 零副本三根因、07-14（續）detached 指揮鏈＋YBDB/CRDB cell、
  07-15 CRDB 三修結案）
- Smoke 前置：[SMOKE-STAGE1-SUMMARY.md](SMOKE-STAGE1-SUMMARY.md)（Stage 1 三家 smoke，07-08/09）
- 資料主檔：[results/x-cross/pipeline-log.md](../results/x-cross/pipeline-log.md)（採用/不採用登記）
- Commits：`621f24f1`（首輪數據 + snapshot SQL 修正）、`5c4a9bcc`（TiDB 重跑）、
  `5a624894`/`420849ad`（GCP 零副本修正）、`8b309599`（probe clients）、
  `2aa8450b`/`1b971cd0`/`9dc7c720`（CRDB lease enforcer / stale race / gate 計數）、
  `afe8872a`（detached 指揮鏈）、`1e5e3332`（CRDB#2/YBDB#2 數據）、`d3bfbf04`（本報告初版）
