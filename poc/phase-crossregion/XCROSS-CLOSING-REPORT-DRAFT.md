# X-CROSS 階段結案報告（雛形）— IDC↔GCP Cross-Region 3-DB W=128 正式測試

> 狀態：**雛形（draft）**。所有數字取自實際執行的 W=128 採樣，無任何模擬/示範資料。
> 每項參數與結論均以連結指向原始採樣檔案。
> 產出日：2026-07-12。07-15 回填 CRDB/YBDB 修正後重測 cell，並依審閱規格重構資訊架構。
> 07-18 改採 **#3 同批三家重跑**（07-17 單鏈零干預）為正式數據；前採用批（07-12/07-14）轉備查。
>
> 本文以下列標籤區分陳述性質：`實測事實`（有原始檔可查）、`觀察`（數據型態描述）、
> `機制推論`（最符合證據的解釋，未直接證實）、`根因未確認`、`採用決策`、`後續驗證`。
> 對應 GitBook 五級制：實測事實≈`[本 PoC 實測｜N=1]`、機制推論≈`[機制推論]`、
> 後續驗證≈`[待驗證]`、採用決策≈`[決策]`。

## 1. 執行摘要

1. `採用決策`：正式採用三個 cell——**TiDB#3、CRDB#3、YBDB#3**（07-17 同批 W=128、P-A、A-S；單一 detached 鏈 11h13m 零人工介入跑完三家；定義見 §3）。
2. `採用決策`：僅供備查、不作正式引用——**TiDB#1**（t128 高變異）、**CRDB#1 / YBDB#1**（GCP 零副本，§8 C1）；**TiDB#2 / CRDB#2 / YBDB#2**（前採用批，數據有效但非同批，07-18 起由 #3 取代，引用須附批次註記）。
3. `實測事實`：t128 主水位 tpmC——TiDB **12,526.5**、CRDB **10,163.4**、YBDB **12,769.5**（§5）。
4. `實測事實`：帶 caveat 的結果——YBDB#3 有 156 筆交易錯誤（總率 0.0072%，較 #2 批 309 筆減半），引用必須附 §6.3 caveat。三家為同批同鏈（§8 O3 已結案）。
5. `根因未確認`：TiDB#1 首輪 t128 下降（§7）、#3 批三處單輪異常（TiDB t16 前二輪偏低、YBDB t64 R4 深塌、CRDB t128 R4 下降，§6.1-6.3）、YBDB 殘餘錯誤的完整因果鏈（§6.3）——均無法以現有證據定案。
6. `採用決策`：X-CROSS 於 phase registry 為 `baseline_eligible=false`——本報告數字供 cross-region 能力與相對量級判讀，**不作正式跨家排名**（§2、§8 O5）。

## 2. 測試目的與範圍

驗證 TiDB / CockroachDB / YugabyteDB 三家分散式 SQL 在 6-node cross-region
（3 IDC + 3 GCP）拓樸、P-A placement（leader/lease pin IDC、GCP 就近讀）下，
以正式口徑 TPC-C W=128 量測吞吐與延遲，作為 X-CROSS 階段的結案數據。

不在本報告範圍：P-B placement 變體、failover 演練、跨家正式排名。
X-CROSS 於 phase registry 為 `baseline_eligible=false`，僅作 cross-region
framework 與相對量級證據；見 [results/PHASES.md](../results/PHASES.md)。

## 3. 採用與備查 Suite

| 縮寫 | 狀態 | Suite 目錄 |
|---|---|---|
| **TiDB#3**（同批） | ✅ 採用 | [tidb-vm-6node-P-A-rc-20260717T143238+0800](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/) |
| **CRDB#3**（同批） | ✅ 採用 | [crdb-vm-6node-P-A-rc-20260717T143238+0800](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/) |
| **YBDB#3**（同批） | ✅ 採用（帶 §6.3 caveat） | [ybdb-vm-6node-P-A-rc-20260717T143238+0800](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/) |
| **TiDB#2**（重跑） | ❌ 備查（前採用；非同批 07-12，由 #3 取代） | [tidb-vm-6node-P-A-rc-20260712T164221+0800](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/) |
| **CRDB#2**（修正後） | ❌ 備查（前採用；非同批 07-14，由 #3 取代） | [crdb-vm-6node-P-A-rc-20260714T163716+0800](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/) |
| **YBDB#2**（修正後） | ❌ 備查（前採用；非同批 07-14，由 #3 取代） | [ybdb-vm-6node-P-A-rc-20260714T163716+0800](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/) |
| **TiDB#1**（首輪） | ❌ 備查（t128 CV 102.2%，§7） | [tidb-vm-6node-P-A-rc-20260711T215200+0800](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/) |
| **CRDB#1** | ❌ 備查（GCP 零副本，§8 C1） | [crdb-vm-6node-P-A-rc-20260711T215200+0800](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/) |
| **YBDB#1** | ❌ 備查（GCP 零副本，§8 C1） | [ybdb-vm-6node-P-A-rc-20260711T215200+0800](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/) |

備查的 #2 批（07-12/07-14）數據本身有效（三重驗證證據見 §9.4），僅因非同批被 #3 取代；引用須附批次註記。

\#3 批相對 #2 批的增量驗證（`實測事實`，均 fail-closed）：

- **三家同批同鏈**：單一 [`make win-3db-detach`](Makefile) driver 於 .31 依序跑 TiDB→YBDB→CRDB，每 cell static-check 全綠才進下一家，全程零人工介入（消 §8 O3/O9）。
- **TiDB 補上 GCP 副本存在 gate**（#2 批 TiDB 缺此層）：[gcp-replica-gate-tidb.txt](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/gate/gcp-replica-gate-tidb.txt)（`gcp_followers=19, gcp_leaders=0`）。CRDB：[gcp-replica-gate-crdb.txt](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/gate/gcp-replica-gate-crdb.txt)（`ranges_missing_gcp_replica=0, gcp_leaseholders=0`）；YBDB：[gcp-replica-gate-ybdb.txt](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/gate/gcp-replica-gate-ybdb.txt)（3/3 GCP tserver SST>0）。
- **YBDB 新增 S1 系統層 gate**：transaction status tablet leader 檢查＋修復——prepare 後偵測 9/16 leader 在 GCP，`leader_stepdown` 修復至 16/16 IDC（[gcp-replica-gate-ybdb-status-tablets.txt](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/gate/gcp-replica-gate-ybdb-status-tablets.txt)，§6.3）。
- GCP 端就近讀 probe 三家各 20 輪（共 60 檔）全 `fail_count=0`（static-check 斷言）。例：[TiDB t128 r1](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-128/round-1/probe-iso-latency-gcp-t128-r1.json)、[CRDB t128 r1](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-128/round-1/probe-iso-latency-gcp-t128-r1.json)、[YBDB t128 r1](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-128/round-1/probe-iso-latency-gcp-t128-r1.json)。

## 4. 測試環境與共同口徑

### 4.1 環境

| 項目 | 值 | 佐證 |
|---|---|---|
| 拓樸 | 6 DB node = 3 IDC（172.24.40.32-34, vSphere）+ 3 GCP（10.160.152.11-13, asia-east1-a/b/c）；client/driver = .31（IDC） | §9.1 env 列 |
| OS / kernel | AlmaLinux 8.10，4.18.0-553.124.1.el8_10（DB hosts） | §9.1 env 列 |
| DB 版本 | TiDB v8.5.2 / CRDB v26.2.0 / YBDB 2025.2.2.2-b11 | ansible playbook version vars；CRDB 另見 §9.1 leader/lease 快照列的 `crdb-nodes.txt` build 欄 |
| WAN RTT（IDC↔GCP） | ~8.4 ms（#3 批實測 rtt≈8.4ms；07-14 批 ≈8.1ms） | §9.1 WAN probe 列 |
| WAN 頻寬（探測值） | ~191-227 Mbps | §9.3 CRDB#1 wan-probe 參考值 |
| 時鐘同步 | chrony 10-host gate PASS，offset µs 級 | §9.1 環境 gate 列 |
| VM 潔淨度 | 每 TS 全 VM 重建，boot_id 留證 | §9.2 vm-rebuild-proof |

### 4.2 量測口徑

| 參數 | 值 | 佐證 |
|---|---|---|
| Workload | go-tpc TPC-C | §9.1 raw go-tpc 列 |
| WAREHOUSES | 128 | §9.1 summary.json 列（`warehouses` 欄） |
| Threads 檔位 | 16 / 32 / 64 / 128 | 同上（`threads_list` 欄） |
| Rounds | 每檔 5 輪 × 300 s | 同上（`rounds_per_thread_group` 欄） |
| Warmup | 1200 s（每檔位前） | 各 suite `runs/warmup.log`；[Makefile `WARMUP_SEC=1200`](Makefile) |
| Primary estimator | tpmC_mean = R1-R5 mean（per [PHASES.md](../results/PHASES.md) §5） | §9.1 summary.json 列（`skip_rounds: 0`） |
| Placement | P-A（leader/lease pin IDC），gcp_leader_count=0 | §9.1 placement gate 列 |
| 就近讀設定 | TiDB closest-replicas / CRDB follower_reads / YBDB read_from_followers | §9.1 near-read 列 |
| Scheduler/balancer 凍結 | 量測前 freeze、量測後 unfreeze | §9.1 freeze state 列（TiDB 無 dump，§8 O4） |
| Client zone | idc（.31，不跨區打流量） | [Makefile](Makefile) hard contract `CLIENT_ZONE=idc` |
| 執行入口 | #3 三家同批：[`make win-3db-detach`](Makefile) `.31` detached 單鏈（07-17，TiDB→YBDB→CRDB 依序、per-cell static-check fail-closed） | [SESSION-HISTORY.md](SESSION-HISTORY.md) 2026-07-17 節 |

### 4.3 三家副本語意

`實測事實`（共同配置結論一句）：07-14 起三家的每筆資料均為 RF=3 = 2 IDC voter + 1 GCP voter，leader/lease pin 在 IDC，commit quorum 由 IDC pair 滿足。

三家實作差異：

| 資料庫 | 副本配置 | Leader／Lease 控制 | GCP 副本驗證 | 殘留差異 |
|---|---|---|---|---|
| TiDB | placement policy：`REGIONS="idc,gcp"` + MAJORITY_IN_PRIMARY | policy `PRIMARY_REGION=idc` | gate 驗 gcp follower>0、gcp leader=0 | 交易記錄跟隨資料表 region，lease pin 已覆蓋 |
| CockroachDB | zone config：`voter_constraints '{+region=idc: 2, +region=gcp: 1}'` | `lease_preferences=[[+region=idc]]` + wrapper lease enforcer | gate 逐 range 驗 `replica_localities` 含 gcp | 交易記錄跟隨資料表 range，lease pin 已覆蓋 |
| YugabyteDB | universe live placement：`idc:2 + gcp(asia-east1 統一 zone):1` | `set_preferred_zones` IDC | gate 驗 3/3 GCP tserver SST>0 | transaction status tablet（系統層）：07-17 起 S1 gate 於 prepare 後檢查＋`leader_stepdown` 修復；**run 中漂回未防**（§6.3） |

**仍不完全等價**：三家在「tpcc 資料表的寫入路徑跨區複製成本」上口徑一致，
但**不可宣稱完全同語意**。YugabyteDB 的 transaction status tablet 屬系統層物件；
`實測事實`：#3 批 prepare 後 S1 gate 直接 dump 到 9/16 status tablet leader 在
GCP（07-14 批僅能從錯誤訊息間接推論），`leader_stepdown` 修復至 16/16 IDC 後
才開跑（§6.3）。修復為一次性，run 中 LB 是否漂回未防、未驗。YBDB 由早期
read-replica 設計（從未實體化，§8 C1）改為 live voter；GCP 三台統一
`placement_zone` `asia-east1` 由 LB 均衡分擔。佐證：§9.1 的
`ybdb-universe-config.txt`（live=idc:2+gcp:1）與三家 gcp-replica-gate。

## 5. 主結果

範圍說明（`採用決策`）：本節僅含採用 cell（TiDB#3、CRDB#3、YBDB#3，07-17 同批）。
三家均通過三重驗證（placement gate、GCP 副本存在 gate、GCP 端 probe 20 輪
`fail_count=0`），數字帶真實跨區複製成本；與 07-11 備查批（GCP 零副本、
未付 WAN 成本）不可比。前採用 #2 批數字見 §9.4（跨批對照見 §8 O6）。

口徑：tpmC_mean 為 R1-R5 mean；CV = `tpmC_range_mean_pct`；延遲 = NEW_ORDER
p50/p95/p99 mean (ms)。逐輪原始值在各 `summary.json` 的
`thread_results.<t>.tpmC_per_round`；逐輪完整輸出在各 round 的 `go-tpc-stdout.txt`（§9.1）。

### 5.1 吞吐

| threads | TiDB tpmC (CV) | CRDB tpmC (CV) | YBDB tpmC (CV) |
|---:|---:|---:|---:|
| 16 | 1584.4 (52.8%*) | 9573.6 (3.8%) | 6856.0 (23.5%) |
| 32 | 3614.3 (14.3%) | 10515.9 (12.3%) | 9317.0 (17.9%) |
| 64 | 7176.1 (4.3%) | 11075.8 (6.1%) | 10201.9 (81.1%†) |
| **128（主水位）** | **12526.5 (5.7%)** | **10163.4 (19.2%‡)** | **12769.5 (13.0%)** |

\* 見 §6.1（TiDB t16 前二輪偏低）。† 見 §6.3（YBDB t64 R4 深塌，與 timeout
錯誤同檔位）。‡ 見 §6.2（CRDB t128 R4 單輪下降）。
三家隨 threads 的縮放形狀差異（TiDB 近線性、CRDB/YBDB 早飽和且 CRDB t128
出現負縮放）解讀見 §6.4。

### 5.2 t128 延遲（NEW_ORDER, ms）

| t128 延遲 | p50 | p95 | p99 |
|---|---:|---:|---:|
| TiDB | 355.7 | 506.7 | 677.8 |
| CRDB | 422.8 | 778.5 | 1020.1 |
| YBDB | 276.8 | 476.5 | 758.3 |

### 5.3 結果判讀

| 資料庫 | t128 觀察 | 穩定性 | 錯誤 | 可引用結論 | 限制 |
|---|---|---|---|---|---|
| TiDB | 12,526.5 tpmC、p99 677.8ms | t128 CV 5.7%，五輪緊密 | 0 / 1,384,230 | X-CROSS 內 TiDB P-A/A-S 有效參考值 | t16 前二輪偏低未歸因（§6.1）；與 07-03/07-12 批的跨批變異未歸因（§8 O6） |
| CockroachDB | 10,163.4 tpmC、p99 1,020.1ms | t128 CV 19.2%（R4=8,673 單輪下降） | 0 / 2,294,569 | X-CROSS 內 CRDB P-A/A-S 有效參考值 | t128 單輪下降未歸因（§6.2）；t64→t128 負縮放（§6.4） |
| YugabyteDB | 12,769.5 tpmC、p99 758.3ms | t128 CV 13.0%；t64 含一次深塌（R4=3,893） | 156 / 2,167,333（總率 0.0072%；各檔 0.001-0.012%） | 可引用，**必須附 §6.3 caveat** | 殘餘 timeout 錯誤未歸零（§8 O1）；S1 修復為 prepare 時一次性 |

## 6. 各資料庫觀察與限制

### 6.1 TiDB

- `實測事實`：t16 五輪 = 1121.8 / 1082.1 / 1894.1 / 1905.1 / 1918.8——前二輪明顯偏低（約 -43%），R3 起穩定，造成 CV 52.8%。原始值：TiDB#3 [summary.json](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/summary.json) `thread_results.16.tpmC_per_round`；[t16 R1 原始輸出](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-16/round-1/go-tpc-stdout.txt)。
- `根因未確認`：t16 為全 suite 首檔位（warmup 1200s 之後），型態類似冷啟收斂但無 TiKV metrics 可證。t16 各家絕對值最低、對主水位無影響。
- `觀察`：t32 R4=3227.3（其餘四輪 3693-3742）——單輪小幅下降再度出現；TiDB#2 批 t32 也有一次單輪下降（R2=3048.1，見 [TiDB#2 summary.json](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/summary.json) `thread_results.32`）。跨批皆為孤立單輪、未連續，`根因未確認`。
- `觀察`：TiDB t16 明顯低於 CRDB/YBDB，t128 反超為三家最高。
- `實測事實`：TiDB 的 IDC 節點 CPU 大量閒置——t16 時 idc-dbhost-1 idle 87.9%（[mpstat](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-16/round-1/mpstat-db-idc-dbhost-1.txt)）；t128 時三台 idle 41.9% / 68.6% / 66.9%（[idc-1](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-128/round-1/mpstat-db-idc-dbhost-1.txt)）。t128 仍未資源飽和。
- `機制推論`：低併發劣勢的可能機制為跨區環境下 TSO/2PC 的延遲敏感性——分層架構每筆交易多跳 RPC（client → HAProxy → tidb-server → PD TSO → TiKV pessimistic 加鎖往返），時間花在等待網路而非 CPU；延遲不隨併發惡化（NEW_ORDER p50：t32 318.8ms → t128 355.7ms），吞吐即隨 threads 近線性成長。未以 transaction trace 直接證實。
- `實測事實`（組態）：TiDB 的 HAProxy backend 為 `172.24.40.32:4000, 172.24.40.33:4000, 10.160.152.11:4000`（ansible playbook 定義）——約 1/3 連線的 SQL 層落在 GCP tidb-server，每個 statement 跨 WAN 回 IDC 的 TiKV/PD。
- `機制推論`：上述組態同時解釋「t16 偏低」與「線性段特別長」——跨 WAN 連線把平均單筆延遲墊高、單 thread 吞吐壓低，但幾乎不消耗 IDC CPU。
- 附註：`efficiency%` 欄為無 think/keying 口徑，依既有慣例忽略（見 [pipeline-log.md](../results/x-cross/pipeline-log.md) §2.3 效度邊界）。

### 6.2 CockroachDB

- `實測事實`：四檔全程 0 error（2,294,569 筆交易）。
- `實測事實`：t128 五輪 = 10562.0 / 10628.7 / 10526.0 / **8673.0** / 10427.5——R4 單輪下降約 -17%，造成 t128 CV 19.2%。原始值：CRDB#3 [summary.json](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/summary.json) `thread_results.128.tpmC_per_round`；[t128 R4 原始輸出](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-128/round-4/go-tpc-stdout.txt)。
- `根因未確認`：R4 下降未歸因（0 error、無 retry 訊息）；孤立單輪、未連續。前批（CRDB#2）t16 的 15.2% 波動在本批未重現（t16 CV 3.8%）。
- `實測事實`：t16 時最熱 IDC 節點已接近飽和——idc-dbhost-1 idle 15.3%（[mpstat](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-16/round-1/mpstat-db-idc-dbhost-1.txt)）；t128 時 idle 13.4%（[mpstat](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-128/round-1/mpstat-db-idc-dbhost-1.txt)）。
- `機制推論`：t16 即近飽和可解釋吞吐早平頂（16→64 僅 +16%）、t128 反而低於 t64（§6.4 負縮放）與 p99 隨併發放大（127.5→1020.1ms，×8.0）——增加的併發主要轉為排隊。對稱架構下 SQL 執行、交易協調與儲存疊加在同 3 台 IDC 節點；未以內部 queue 指標直接證實。
- `實測事實`：placement gate 計數口徑為 07-14 修正後的 lease 單欄版（§8 C1 之修正五）；本 cell 的 gate 值 idc=11/11，gcp_leaseholders=0。

### 6.3 YugabyteDB 錯誤（156 筆）與 S1 系統層修復

- **實測事實**：t16 / t32 / t64 / t128 分別出現 3 / 9 / 59 / 85 筆交易錯誤（率 0.001-0.012%，總計 156/2,167,333 = 0.0072%），較 #2 批（309 筆、0.0149%）約減半。錯誤樣本可於各 round 檔 grep `execute run failed`（§9.1 raw go-tpc 列）。
- **實測事實（07-14 批機制推論的直接證實）**：#3 批 prepare 後、開跑前，S1 gate dump 到 **9/16 transaction status tablet leader 位於 GCP**，隨即 `leader_stepdown` 修復、10 秒後 16/16 全在 IDC 才放行開跑。完整前後 dump：[gcp-replica-gate-ybdb-status-tablets.txt](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/gate/gcp-replica-gate-ybdb-status-tablets.txt)。「status tablet leader 會落在 GCP」由機制推論升級為實測事實。
- **實測事實**：修復後錯誤仍出現（156 筆），特徵仍為 ~5.2-5.6s 延遲的 `UpdateTransaction` RPC 逾時（`transaction_rpc_timeout_ms` 預設 5000）。
- **機制推論**（殘餘錯誤的候選解釋，未定案）：(a) 高併發尾延遲本身逼近 5s deadline——t128 錯誤輪的 99.9th 已達 3.9-4.8s，正常尾端再疊 WAN/IO 抖動即破 5s；(b) run 中 LB 把部分 status tablet leader 漂回 GCP（S1 修復為 prepare 時一次性，run 中未防）。集群已拆，兩者皆無法回溯驗證；錯誤隨併發遞增（3→9→59→85）與 (a) 一致，但不足以排除 (b)。
- **下一步**（後續驗證，已拍板）：依 decisions 2026-07-17 的備援路徑，將 `transaction_rpc_timeout_ms` 5000→15000 後重跑驗證歸零；採用該設定的數據須標注三家 timeout 口徑不對稱。
- `觀察`：t64 R4=3892.8 深塌（其餘四輪 10698-12166，t64 CV 81.1%）與 t64 的 59 筆錯誤同檔位，時間相關、因果未證。
- `觀察`：S1 修復後 YBDB t128 tpmC 12,769.5 較 #2 批 11,138.6 高 +14.6%——方向與「commit 協調不再跨 WAN」一致，屬跨批比較（`機制推論`，未以 tserver 指標直接證實，其他批間差異未排除）。
- `實測事實`：最熱 IDC 節點利用率隨併發逼近飽和——idc-dbhost-1 idle 由 t16 45.4%（[mpstat](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-16/round-1/mpstat-db-idc-dbhost-1.txt)）→ t128 26.7%（[mpstat](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-128/round-1/mpstat-db-idc-dbhost-1.txt)）。
- `機制推論`：t64 起最熱節點約 3/4 busy，可解釋 t32→t64 成長趨緩（×1.09）；未以 tserver 內部指標直接證實。

### 6.4 吞吐縮放形狀（跨家觀察）

- `觀察`：threads 每倍增的 tpmC 成長倍率——TiDB ×2.28 / ×1.99 / ×1.75（近線性、t128 未見平頂；×2.28 受 t16 前二輪偏低壓低基期，以 t16 R3-R5 均值 ~1,906 計為 ×1.90）；CRDB ×1.10 / ×1.05 / **×0.92（t128 負縮放）**；YBDB ×1.36 / ×1.09 / ×1.25（t64 均值受 R4 深塌拉低，剔除該輪為 ~11,779，形狀為 t64 起趨平）。
- `實測事實`：對應的資源證據見 §6.1-6.3——TiDB t128 仍大量 CPU 閒置（idle 41.9-68.6%）；CRDB t16 即近飽和（idle 15.3%）、YBDB t64 起逼近飽和。每節點 4 CPU；P-A 下 leader/lease 全在 3 台 IDC 節點，GCP 3 台僅承擔複製。
- `機制推論`：TiDB 為延遲受限（吞吐 ≈ 併發 ÷ 單筆延遲，延遲近乎不變故隨 threads 線性）；CRDB/YBDB 為資源受限（單筆服務時間短，少量 threads 即吃滿 3 台 IDC 節點，再加併發轉為排隊；CRDB t128 負縮放與排隊加深、p99 破 1s 一致）。
- `觀察`：三家最熱節點皆為 idc-dbhost-1——該節點同時是 gateway 焦點與控制面所在（PD leader / YB master / CRDB 首位 backend），有效容量低於 3 台均攤。
- 判讀限制：形狀差異不構成排名。低併發場景（t16）TiDB 吞吐僅另兩家的 1/6-1/4；「t128 反超」只在本矩陣範圍內成立，TiDB 的實際飽和點未量測（無 t256 資料，不可外推）。

## 7. 異常案例與採用判定（TiDB#1 → TiDB#2）

- **異常現象**（實測事實）：TiDB#1 t128 五輪 tpmC = 13601.5 / 6513.7 / 6030.0 / 5855.2 / 5879.5，CV 102.2%；自 R2 起顯著下降後盤整；全程 0 error、無 retry/warn。原始值：TiDB#1 [summary.json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/summary.json) `thread_results.128.tpmC_per_round`；下降起點輪：[runs/threads-128/round-2/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/runs/threads-128/round-2/go-tpc-stdout.txt)。
- **被證偽的假設**（實測事實）：排查初期懷疑「P-A leader 漂移到 GCP」。該訊號來自量測腳本 bug——post-run leader-snapshot SQL 缺 `DB_NAME='tpcc'` 過濾，把系統 schema region 的 leader 計入 GCP（誤導性快照：TiDB#1 [leader-snapshot/tidb-region-leaders.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/tidb-region-leaders.txt)）。以 tpcc-scoped gate 查詢證偽（跑完首次輪詢即 100% IDC），並修正 [Makefile](Makefile) snapshot 查詢（commit `621f24f1`）。
- **重跑結果**（實測事實）：TiDB#2 同參數重跑，t128 五輪 = 13188.2 / 13087.6 / 13268.1 / 13099.1 / 13614.8，CV 4.0%；異常未重現。修正後快照顯示 tpcc leader 只在 3 台 IDC store（8/8/3）、0 GCP：TiDB#2 [leader-snapshot/tidb-region-leaders.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/leader-snapshot/tidb-region-leaders.txt)。
- **根因未確認**：首輪下降的根因無法確認——首輪 VM 已銷毀，無 TiKV metrics 可回溯。
- **採用決策**：因高變異且同參數不可重現，TiDB#1 不納入正式結果、保留備查；當時採用 TiDB#2。詳細過程：[SESSION-HISTORY.md](SESSION-HISTORY.md) 2026-07-11/12 兩節；commits `621f24f1`、`5c4a9bcc`。
- **後續佐證**（實測事實）：TiDB#3（07-17）t128 五輪 12222.2-12933.5、CV 5.7%，異常連續第二批未重現。

## 8. 效度邊界與未竟事項

### 8.1 已結案問題

| ID | 問題 | 修正 | 驗證證據 | 殘留限制 |
|---|---|---|---|---|
| C1 | CRDB#1/YBDB#1 的 GCP 節點零 tpcc 資料副本（07-13 覆核發現） | 五項：CRDB constraints counted-form；YBDB live 2+1 + 統一 zone；probe 直打 GCP 節點；probe 主機補裝 DB clients（`.15` 原無 client，四 suite probe 全滅實為 command-not-found）；CRDB gate grep 整行計數 bug（經授權修 `prepare.sh`）。防再犯：`gcp-replica-gate.sh` fail-closed、static-check probe 斷言、`phase2-probe-clients` | CRDB#2/YBDB#2 起三重驗證全綠；#3 批三家全綠（§3 連結；§9.1 矩陣） | YBDB 系統層 tablet 另立 **O1**（S1 gate 已上線，錯誤未歸零） |
| O3 | 採用三 cell 橫跨兩批（TiDB#2 07-12 vs CRDB#2/YBDB#2 07-14），嚴格同批三家數據不存在 | #3：`win-3db-detach` 單鏈同批重跑三家（07-17） | §3 #3 批（同 TS `20260717T143238+0800`、同 driver、同 VM 世代）；[SESSION-HISTORY.md](SESSION-HISTORY.md) 2026-07-17 節 | 無（07-18 起採用 cell 即同批） |
| O9 | 流程穩定性尚未經「零人工介入」完整輪驗證（CRDB#2 過程含三修） | #3 全鏈 11h13m 零人工介入：TiDB→YBDB→CRDB 每 cell deploy→smoke→static-check→teardown→歸檔連續通過，含全部 fail-closed gate | driver `.done` marker＋[SESSION-HISTORY.md](SESSION-HISTORY.md) 2026-07-17 節 | 單次通過（N=1）；缺輪斷言/歸檔等新 gate 為本輪首驗 |

### 8.2 未結案問題

| ID | 缺口 | 對結果影響 | 是否阻擋結案 | 下一步 |
|---|---|---|---|---|
| O1 | YBDB 交易 timeout 錯誤未歸零（S1 gate 已上線並 live 驗證：prepare 後 9/16 status tablet leader 在 GCP → stepdown 修復；錯誤 309→156 減半但仍在，§6.3） | YBDB#3 引用須附 caveat（總率 0.0072%） | 不阻擋（帶 caveat 採用） | 依已拍板備援：`transaction_rpc_timeout_ms` 5000→15000 重跑驗證歸零；採用須標注三家 timeout 口徑不對稱（decisions 2026-07-17） |
| O2 | 單輪異常跨批重複出現、均根因未確認：TiDB#1 t128 首輪下降、TiDB#2/#3 t32 單輪小幅下降、TiDB#3 t16 前二輪偏低、CRDB#3 t128 R4、YBDB#3 t64 R4（§6.1-6.3、§7） | 不影響採用 cell 的有效性判定（主水位 mean 含全輪） | 不阻擋 | 時間允許時以 N=3 重跑檢查重現性；候補：per-round 系統快照 |
| O4 | TiDB w128 鏈無 `freeze-state/` dump（凍結有執行、無 before-dump 佐證；#3 批仍未加 dump 步驟） | TiDB 凍結證據鏈不完整 | 不阻擋 | TiDB w128 鏈加 dump 步驟後重跑才補齊 |
| O5 | X-CROSS `baseline_eligible=false` | 數字不得進 S-BASE/S-K8S 跨家正式排名 | 恆定約束（非缺口） | 無（設計如此） |
| O6 | 跨批變異未歸因：TiDB t128 07-03 16,808.6 → 07-12 13,251.6 → 07-17 12,526.5（[07-03 批](../results/x-cross/baseline/w128/20260703T092243+0800/)；07-12 批見 §9.4）；CRDB 11,001.1→10,163.4；YBDB 11,138.6→12,769.5 | 各批皆有效 cell；跨批並讀須註明批次 | 不阻擋 | 引用時註明批次 |
| O7 | P-B placement、A-A profile、failover 場景未涵蓋 | 本報告僅覆蓋 P-A × A-S | 不阻擋本階段報告；阻擋全矩陣結案 | 依既定順序執行 A-A-RO smoke / P-B |
| O8 | ~~07-14 批 IDC 3 台 VM destroy 待補~~ **已結案（2026-07-17）**：vSphere 恢復後補跑 `phase9-destroy`，IDC 3 台全拆、兩側 terraform state 歸零 | 無 | 已解 | 無 |

（O3、O9 已結案，移至 §8.1。）

## 9. 證據檔索引

### 9.1 採用 cell 證據矩陣

| 證據類型 | TiDB#3 | CRDB#3 | YBDB#3 | 用途 |
|---|---|---|---|---|
| summary.json | [json](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/summary.json) | [json](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/summary.json) | [json](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/summary.json) | primary 取數來源 |
| raw go-tpc | [runs/](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/runs/)・[t16 r1](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-16/round-1/go-tpc-stdout.txt)（偏低輪） | [runs/](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/runs/)・[t128 r4](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-128/round-4/go-tpc-stdout.txt)（下降輪） | [runs/](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/runs/)・[t64 r4](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/runs/threads-64/round-4/go-tpc-stdout.txt)（深塌輪） | 逐輪原始輸出；YBDB 錯誤樣本 grep `execute run failed` |
| placement gate | [json](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/prepare/placement-gate-P-A.json)（idc=19/19） | [json](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/prepare/placement-gate-P-A.json)（idc=11/11） | [json](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/prepare/placement-gate-P-A.json)（idc=3/3） | leader/lease 100% IDC 驗收 |
| GCP replica gate | [txt](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/gate/gcp-replica-gate-tidb.txt)（gcp_followers=19, gcp_leaders=0；**#3 起 TiDB 補上此層**） | [txt](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/gate/gcp-replica-gate-crdb.txt) | [txt](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/gate/gcp-replica-gate-ybdb.txt)・[universe.json](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/gate/gcp-replica-gate-ybdb-universe.json)・[status-tablets](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/gate/gcp-replica-gate-ybdb-status-tablets.txt)（S1） | GCP 真的持有副本；YBDB 另含系統層 S1 前後 dump |
| near-read 設定 | [txt](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/prepare/near-read-vars.txt) | [txt](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/prepare/near-read-vars.txt) | [txt](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/prepare/near-read-vars.txt) | 設定面；執行面由 GCP probe 證明（§3） |
| leader/lease/tablet 快照 | [region-leaders](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/leader-snapshot/tidb-region-leaders.txt) | [lease-holders](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/leader-snapshot/crdb-lease-holders.txt)・[nodes](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/leader-snapshot/crdb-nodes.txt) | [leader-counts](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/leader-snapshot/ybdb-leader-counts.txt)・[tservers](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/leader-snapshot/ybdb-tservers.txt)・[universe-config](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/leader-snapshot/ybdb-universe-config.txt) | 跑後分布；YBDB tservers 顯示 6/6 皆有 SST |
| freeze state | 無 dump（§8 O4） | [lease-rebal](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/freeze-state/crdb-lease-rebal-before.tsv)・[split-load](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/freeze-state/crdb-split-load-before.tsv) | [lb-state](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/freeze-state/yb-lb-state-before.txt)・[universe](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/freeze-state/yb-universe-before.txt) | 凍結前 dump |
| 環境 gate | [gate/](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/gate/)・[chrony](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/gate/chrony-gate.txt) | [gate/](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/gate/)・[chrony](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/gate/chrony-gate.txt) | [gate/](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/gate/)・[chrony](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/gate/chrony-gate.txt) | chrony / OS / disk / 隔離 |
| WAN probe | [warmup](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/runs/wan-probe-warmup.txt) | [warmup](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/runs/wan-probe-warmup.txt)（rtt≈8.4ms） | [warmup](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/runs/wan-probe-warmup.txt) | RTT/頻寬/時鐘；round 級在各 round 目錄 |
| DB config | [effective](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/db-config/effective-config.txt) | [settings](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/db-config/cluster-settings.txt)・[effective](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/db-config/effective-config.txt) | [settings](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/db-config/cluster-settings.txt)・[effective](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/db-config/effective-config.txt) | 有效設定 dump |
| env | [host](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/env/db-host-snapshot.txt)・[kernel](../results/x-cross/baseline/w128/20260717T143238+0800/tidb-vm-6node-P-A-rc-20260717T143238+0800/env/kernel.txt) | [host](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/env/db-host-snapshot.txt)・[kernel](../results/x-cross/baseline/w128/20260717T143238+0800/crdb-vm-6node-P-A-rc-20260717T143238+0800/env/kernel.txt) | [host](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/env/db-host-snapshot.txt)・[kernel](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/env/kernel.txt) | OS/主機環境 |

註：GCP 端 probe 證據連結見 §3（採用 cell 各 20 輪 `fail_count=0`）。

### 9.2 批次級證據（VM rebuild / fetch receipt）

| 批次 | VM 重建證明 | fetch 完整性收據 |
|---|---|---|
| 07-11 | [vm-rebuild-proof](../results/x-cross/baseline/w128/20260711T215200+0800/vm-rebuild-proof-20260711T215200+0800.json) | [fetch-receipt](../results/x-cross/baseline/w128/20260711T215200+0800/fetch-receipt.json) |
| 07-12 | [vm-rebuild-proof](../results/x-cross/baseline/w128/20260712T164221+0800/vm-rebuild-proof-20260712T164221+0800.json) | [fetch-receipt](../results/x-cross/baseline/w128/20260712T164221+0800/fetch-receipt.json) |
| 07-14 | [vm-rebuild-proof](../results/x-cross/baseline/w128/20260714T163716+0800/vm-rebuild-proof-20260714T163716+0800.json) | [fetch-receipt](../results/x-cross/baseline/w128/20260714T163716+0800/fetch-receipt.json) |
| 07-17（#3） | [vm-rebuild-proof](../results/x-cross/baseline/w128/20260717T143238+0800/vm-rebuild-proof-20260717T142931+0800.json)（proof 檔名時戳 `142931` 為 phase1 獨立執行時間，早於本批 `TPCC_TS=143238`；同一次重建） | [fetch-receipt](../results/x-cross/baseline/w128/20260717T143238+0800/fetch-receipt.json) |

### 9.3 備查批（07-11）證據

- summary.json：TiDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/summary.json)・CRDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/summary.json)・YBDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/summary.json)
- raw go-tpc：TiDB#1 [t128 r2 stdout](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/runs/threads-128/round-2/go-tpc-stdout.txt)（下降起點輪）・CRDB#1 [runs/](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/runs/)・YBDB#1 [runs/](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/runs/)
- placement gate：TiDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)（idc=19/19）・CRDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)（idc=11/11；當時計數口徑有誤，且 GCP 零副本）・YBDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)（idc=3/3；GCP 零副本）
- 誤導/缺陷快照（§7、§8 C1 佐證）：TiDB#1 [無過濾 leader 快照](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/tidb-region-leaders.txt)・YBDB#1 [ybdb-tservers.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/ybdb-tservers.txt)（GCP SST=0B 的直接證據）
- WAN 參考值：CRDB#1 [wan-probe-warmup.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/runs/wan-probe-warmup.txt)（rtt=8504-8539µs、191-227 Mbps）
- 備查批**沒有** GCP replica gate 與有效 probe 證據——該兩層驗證於 07-14 才加入（§8 C1）。

### 9.4 前採用批（#2，07-12/07-14）證據

07-18 前的正式數據來源，仍有效、供跨批對照（§8 O6）與歷史引用：

- summary.json：TiDB#2 [json](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/summary.json)（t128 13,251.6 / CV 4.0%）・CRDB#2 [json](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/summary.json)（11,001.1 / 4.8%）・YBDB#2 [json](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/summary.json)（11,138.6 / 10.4%；309 錯誤 = 0.0149%）
- GCP replica gate：CRDB#2 [txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/gate/gcp-replica-gate-crdb.txt)・YBDB#2 [txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/gate/gcp-replica-gate-ybdb.txt)；TiDB#2 無此層（gate 晚於該批引入）
- 完整證據矩陣見本報告 git 歷史版本（07-15 版 §9.1）；suite 目錄連結見 §3 備查列。

## 10. 追溯紀錄

- 執行歷史：[SESSION-HISTORY.md](SESSION-HISTORY.md)（2026-07-11/12 首輪與 TiDB
  重跑、07-13 GCP 零副本三根因、07-14（續）detached 指揮鏈＋YBDB/CRDB cell、
  07-15 CRDB 三修結案、07-17 #3 同批三家零干預）
- Smoke 前置：[SMOKE-STAGE1-SUMMARY.md](SMOKE-STAGE1-SUMMARY.md)（Stage 1 三家 smoke，07-08/09）
- 資料主檔：[results/x-cross/pipeline-log.md](../results/x-cross/pipeline-log.md)（採用/不採用登記）
- Commits：`621f24f1`（首輪數據 + snapshot SQL 修正）、`5c4a9bcc`（TiDB 重跑）、
  `5a624894` / `420849ad`（GCP 零副本修正）、`8b309599`（probe clients）、
  `2aa8450b` / `1b971cd0` / `9dc7c720`（CRDB lease enforcer / stale race / gate 計數）、
  `afe8872a`（detached 指揮鏈）、`1e5e3332`（CRDB#2/YBDB#2 數據）、`d3bfbf04`（本報告初版）、
  `f779242b`（S1 status-tablet gate）、`3f72c190`（缺輪斷言＋cell 歸檔）、
  `abcfa903`（win-3db 三家同批 driver）
