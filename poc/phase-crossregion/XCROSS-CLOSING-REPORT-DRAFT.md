# X-CROSS 階段結案報告（雛形）— IDC↔GCP Cross-Region 3-DB W=128 正式測試

> 狀態：**雛形（draft）**。所有數字取自實際執行的四份 W=128 採樣，無任何模擬/示範資料。
> 每項參數與結論均連結原始採樣檔案。產出日：2026-07-12。

## 1. 目的與範圍

驗證 TiDB / CockroachDB / YugabyteDB 三家分散式 SQL 在 6-node cross-region
（3 IDC + 3 GCP）拓樸、P-A placement（leader/lease pin IDC、GCP 就近讀）下，
以正式口徑 TPC-C W=128 量測吞吐與延遲，作為 X-CROSS 階段的結案數據。

不在本報告範圍：P-B placement 變體、failover 演練、跨家正式排名
（X-CROSS 於 phase registry 為 `baseline_eligible=false`，僅作 cross-region
framework / 相對量級證據；見 `../results/PHASES.md`）。

## 2. 採用數據（四份採樣）

| # | DB | TPCC_TS | 採用 | 原始數據路徑（相對 `poc/`） |
|---|---|---|---|---|
| 1 | TiDB（首輪） | `20260711T215200+0800` | ❌ 不採用（t128 CV 102.2%，§6） | `results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/` |
| 2 | CRDB | `20260711T215200+0800` | ✅ 採用 | `results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/` |
| 3 | YBDB | `20260711T215200+0800` | ✅ 採用 | `results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/` |
| 4 | TiDB（重跑） | `20260712T164221+0800` | ✅ 採用 | `results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/` |

每份 suite 目錄結構一致：`summary.json`（機器可讀彙整，primary 取數來源）、
`prepare/placement-gate-P-A.json`（placement 驗收）、`gate/`（chrony/OS/disk/隔離）、
`freeze-state/`（凍結前 dump）、`leader-snapshot/`（跑後 leader 分布）、
`runs/threads-*/round-*/go-tpc-stdout.txt`（每輪原始輸出）、`runs/**/wan-probe-*.txt`
（WAN 探測）、`db-config/`、`env/`。fetch 完整性收據：各 TS 目錄下 `fetch-receipt.json`。

## 3. 測試環境

| 項目 | 值 | 佐證 |
|---|---|---|
| 拓樸 | 6 DB node = 3 IDC（172.24.40.32-34, vSphere）+ 3 GCP（10.160.152.11-13, asia-east1-a/b/c）；client/driver = .31（IDC） | `env/db-host-snapshot.txt`、`fetch-receipt.json` |
| OS / kernel | AlmaLinux 8.10，4.18.0-553.124.1.el8_10（DB hosts） | `env/kernel.txt`、`env/db-host-snapshot.txt` |
| DB 版本 | TiDB v8.5.2 / CRDB v26.2.0 / YBDB 2025.2.2.2-b11 | ansible playbook version vars；CRDB 另見 `leader-snapshot/crdb-nodes.txt`（build 欄 v26.2.0） |
| WAN RTT（IDC↔GCP） | ~8.5 ms（iperf3 tcp_info rtt=8504-8539 µs） | `runs/wan-probe-warmup.txt`（各 suite） |
| WAN 頻寬（探測值） | ~191-227 Mbps（iperf3） | 同上 |
| 時鐘同步 | chrony 10-host gate PASS，last_offset µs 級 | `gate/chrony-gate.txt`、`runs/wan-probe-*.txt` chronyc 段 |
| VM 潔淨度 | 每 TS 全 VM 重建（terraform destroy+apply），boot_id 留證 | `results/x-cross/baseline/w128/<TS>/vm-rebuild-proof-<TS>.json` |

## 4. 測試口徑（參數 → 佐證欄位）

| 參數 | 值 | 佐證（`summary.json` 欄位 / 檔案） |
|---|---|---|
| Workload | go-tpc TPC-C | `runs/threads-*/round-*/go-tpc-stdout.txt` |
| WAREHOUSES | 128 | `warehouses: 128` |
| Threads 檔位 | 16 / 32 / 64 / 128 | `threads_list` |
| Rounds | 每檔 5 輪 × 300 s | `rounds_per_thread_group: 5`、round 目錄數 |
| Warmup | 1200 s（每檔位前） | `runs/warmup.log`、Makefile `WARMUP_SEC=1200` |
| Primary estimator | tpmC_mean = R1-R5 mean（per PHASES.md §5） | `thread_results.<t>.tpmC_mean`、`skip_rounds: 0` |
| Placement | P-A（leader/lease pin IDC） | `region_routing_evidence.placement_gate`（四份全 `verdict: pass`, `gcp_leader_count: 0`） |
| 就近讀設定 | TiDB `tidb_replica_read=closest-replicas`；CRDB `follower_reads.enabled=t`；YBDB `yb_read_from_followers=on` (staleness 30000ms) | `region_routing_evidence.near_read_setup.vars_snapshot` |
| Scheduler/balancer 凍結 | 量測前 freeze、量測後 unfreeze | `freeze-state/`（TiDB: pd-config；CRDB: lease-rebal+split-load tsv；YBDB: lb-state+universe txt） |
| Client zone | idc（.31，不跨區打流量） | Makefile hard contract `CLIENT_ZONE=idc` |
| 執行入口 | `make phase-crossregion-w128-suite`（#2/#3）；TiDB 重跑（#4）為同 knobs 之 TiDB-only 鏈 | `phase-crossregion/Makefile:761`；SESSION-HISTORY 2026-07-11/12 節 |

YBDB 拓樸語意差異（必讀）：YBDB 採 live_replicas=IDC-only RF=3 + GCP 3 台
read_replica（`phase4-ybdb-fix6n` Plan B），GCP 不參與 quorum；TiDB/CRDB 則為
6-voter、以 placement policy/zone config 將 leader/lease pin 在 IDC。跨家比較時
YBDB 寫入路徑天生少一段跨區複製，屬設計選項差異而非量測誤差。
佐證：`leader-snapshot/ybdb-universe-config.txt`（liveReplicas idc RF=3 +
readReplicas gcp）。

## 5. 主結果（採用 cell：#4 TiDB、#2 CRDB、#3 YBDB）

tpmC_mean（R1-R5）；CV = `tpmC_range_mean_pct`；延遲 = NEW_ORDER p50/p95/p99 mean (ms)。

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
  YBDB 2,000,524 筆；`thread_results.<t>.all_txn.error_count`）。
- \* TiDB t32 CV 28.0% 來自單輪 dip（R2=3048.1，其餘 3965-4119），非持續性；
  t128 主水位不受影響。原始輪值：`thread_results.32.tpmC_per_round`。
- 低 thread 檔位形狀差異：TiDB t16 明顯低於 CRDB/YBDB（跨區 TSO/2PC 延遲敏感，
  隨並發放大而攤平）；t128 反超為三家最高。efficiency% 欄為無 think/keying 口徑，
  依既有慣例忽略（見 `pipeline-log.md` §2.3 效度邊界）。

## 6. TiDB 首輪 t128 異常與重跑驗證（#1 → #4）

- 首輪（#1）t128 五輪 tpmC = 13601.5 / 6513.7 / 6030.0 / 5855.2 / 5879.5，
  CV 102.2%——R2 起腰斬盤整。全程 0 error、無 retry/warn。
  原始值：#1 `summary.json` `thread_results.128.tpmC_per_round`。
- 排查中同時抓到量測腳本舊 bug：post-run leader-snapshot SQL 缺
  `DB_NAME='tpcc'` 過濾，把系統 schema region 的 leader 算進 GCP，一度誤判為
  「P-A leader 漂移」。以 tpcc-scoped gate 查詢（跑完首次輪詢即 100% IDC）證偽
  後修正 `phase-crossregion/Makefile` snapshot 查詢（commit `621f24f1`）。
- 重跑（#4）同 knobs：t128 五輪 13188.2 / 13087.6 / 13268.1 / 13099.1 / 13614.8，
  CV 4.0%；修正後 snapshot 顯示 tpcc leader 只在 3 台 IDC store（8/8/3），
  0 GCP——P-A 全程正確。佐證：#4 `leader-snapshot/tidb-region-leaders.txt`。
- 判定：首輪異常為單次環境雜訊（不可重現；首輪 VM 已拆無法回溯 TiKV metrics），
  **採用 #4、#1 保留備查不採用**。詳細過程：`SESSION-HISTORY.md` 2026-07-11/12
  兩節；commits `621f24f1`、`5c4a9bcc`。

## 7. 效度邊界與未竟事項

1. **批次差**：CRDB/YBDB（07-11 批）與採用的 TiDB cell（07-12 批）非同一 VM
   生命週期；三家「同批次」數據僅存在於 #1-#3（但 #1 t128 無效）。若結案要求
   嚴格同批次，需再跑一輪三家 suite（~11 hr）。
2. X-CROSS `baseline_eligible=false` 不變：本報告數字供 cross-region 能力與
   相對量級判讀，不進 S-BASE/S-K8S 跨家正式排名。
3. 與 07-03 TiDB cell（16,808.6 / CV 2.4%，`baseline/w128/20260703T092243+0800/`）
   相比，本輪 TiDB t128 低約 21%——跨批次環境變異，兩者皆為有效 cell；引用時
   註明批次。
4. P-B placement、A-A profile、failover 場景未涵蓋；YBDB read-replica 架構語意
   差異見 §4。
5. GCP 端 per-round metrics 與 WAN probe 齊備度沿用既有 pipeline 慣例，未逐檔
   重新盤點（首輪三家 `phase8.5-static-check` 均 PASS：3 DB suites schema-checked）。

## 8. 追溯索引

- 執行歷史：`SESSION-HISTORY.md`（2026-07-11/12 W=128 首輪、07-12（續）TiDB 重跑）
- Smoke 前置：`SMOKE-STAGE1-SUMMARY.md`（Stage 1 三家 smoke，07-08/09）
- 資料主檔：`../results/x-cross/pipeline-log.md`（採用/不採用登記）
- Commits：`621f24f1`（首輪數據 + snapshot SQL 修正）、`5c4a9bcc`（TiDB 重跑數據）
