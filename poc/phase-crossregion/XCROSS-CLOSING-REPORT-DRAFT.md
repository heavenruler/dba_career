# X-CROSS 階段結案報告（雛形）— IDC↔GCP Cross-Region 3-DB W=128 正式測試

> 狀態：**雛形（draft）**。所有數字取自實際執行的 W=128 採樣，無任何模擬/示範資料。
> 每項參數與結論均以連結指向原始採樣檔案。
> 產出日：2026-07-12。07-15 回填 CRDB/YBDB 修正後重測 cell，並依審閱規格重構資訊架構。
>
> 本文以下列標籤區分陳述性質：`實測事實`（有原始檔可查）、`觀察`（數據型態描述）、
> `機制推論`（最符合證據的解釋，未直接證實）、`根因未確認`、`採用決策`、`後續驗證`。
> 對應 GitBook 五級制：實測事實≈`[本 PoC 實測｜N=1]`、機制推論≈`[機制推論]`、
> 後續驗證≈`[待驗證]`、採用決策≈`[決策]`。

## 1. 執行摘要

1. `採用決策`：正式採用三個 cell——**TiDB#2、CRDB#2、YBDB#2**（各 DB 一個 W=128、P-A、A-S cell；定義見 §3）。
2. `採用決策`：三個 cell 僅供備查、不作正式引用——**TiDB#1**（t128 高變異）、**CRDB#1 / YBDB#1**（GCP 零副本，詳見 §8 C1）。
3. `實測事實`：t128 主水位 tpmC——TiDB **13,251.6**、CRDB **11,001.1**、YBDB **11,138.6**（§5）。
4. `實測事實`：帶 caveat 的結果——YBDB#2 有 309 筆交易錯誤（率 0.011-0.03%），引用必須附 §6.3 caveat；TiDB 與另兩家非同批次（§8 O3）。
5. `根因未確認`：TiDB#1 首輪 t128 下降（§7）、TiDB#2 t32 單輪下降（§6.1）、YBDB 錯誤的完整因果鏈（§6.3）——三者均無法以現有證據定案。
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
| **TiDB#2**（重跑） | ✅ 採用 | [tidb-vm-6node-P-A-rc-20260712T164221+0800](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/) |
| **CRDB#2**（修正後） | ✅ 採用 | [crdb-vm-6node-P-A-rc-20260714T163716+0800](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/) |
| **YBDB#2**（修正後） | ✅ 採用（帶 §6.3 caveat） | [ybdb-vm-6node-P-A-rc-20260714T163716+0800](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/) |
| **TiDB#1**（首輪） | ❌ 備查（t128 CV 102.2%，§7） | [tidb-vm-6node-P-A-rc-20260711T215200+0800](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/) |
| **CRDB#1** | ❌ 備查（GCP 零副本，§8 C1） | [crdb-vm-6node-P-A-rc-20260711T215200+0800](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/) |
| **YBDB#1** | ❌ 備查（GCP 零副本，§8 C1） | [ybdb-vm-6node-P-A-rc-20260711T215200+0800](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/) |

CRDB#2 / YBDB#2 與備查批的關鍵差異是兩層新驗證證據（07-11 批完全缺漏）：

- GCP 副本存在 gate：[CRDB gcp-replica-gate](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/gate/gcp-replica-gate-crdb.txt)（`ranges_missing_gcp_replica=0`）；[YBDB gcp-replica-gate](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/gate/gcp-replica-gate-ybdb.txt)（3/3 GCP tserver SST>0）。
- GCP 端就近讀 probe 各 20 輪全 `fail_count=0`。例：[CRDB t128 r1](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/runs/threads-128/round-1/probe-iso-latency-gcp-t128-r1.json)、[YBDB t128 r1](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/runs/threads-128/round-1/probe-iso-latency-gcp-t128-r1.json)。

## 4. 測試環境與共同口徑

### 4.1 環境

| 項目 | 值 | 佐證 |
|---|---|---|
| 拓樸 | 6 DB node = 3 IDC（172.24.40.32-34, vSphere）+ 3 GCP（10.160.152.11-13, asia-east1-a/b/c）；client/driver = .31（IDC） | §9.1 env 列 |
| OS / kernel | AlmaLinux 8.10，4.18.0-553.124.1.el8_10（DB hosts） | §9.1 env 列 |
| DB 版本 | TiDB v8.5.2 / CRDB v26.2.0 / YBDB 2025.2.2.2-b11 | ansible playbook version vars；CRDB 另見 §9.1 leader/lease 快照列的 `crdb-nodes.txt` build 欄 |
| WAN RTT（IDC↔GCP） | ~8.5 ms（07-14 批實測 rtt≈8.1ms） | §9.1 WAN probe 列 |
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
| 執行入口 | TiDB#2：Mac 端 TiDB-only 鏈（07-12）；CRDB#2/YBDB#2：[`make win-ybdb-crdb-detach`](Makefile) `.31` detached 指揮鏈（07-14） | [SESSION-HISTORY.md](SESSION-HISTORY.md) 2026-07-12 / 07-14（續）節 |

### 4.3 三家副本語意

`實測事實`（共同配置結論一句）：07-14 起三家的每筆資料均為 RF=3 = 2 IDC voter + 1 GCP voter，leader/lease pin 在 IDC，commit quorum 由 IDC pair 滿足。

三家實作差異：

| 資料庫 | 副本配置 | Leader／Lease 控制 | GCP 副本驗證 | 殘留差異 |
|---|---|---|---|---|
| TiDB | placement policy：`REGIONS="idc,gcp"` + MAJORITY_IN_PRIMARY | policy `PRIMARY_REGION=idc` | gate 驗 gcp follower>0、gcp leader=0 | 交易記錄跟隨資料表 region，lease pin 已覆蓋 |
| CockroachDB | zone config：`voter_constraints '{+region=idc: 2, +region=gcp: 1}'` | `lease_preferences=[[+region=idc]]` + wrapper lease enforcer | gate 逐 range 驗 `replica_localities` 含 gcp | 交易記錄跟隨資料表 range，lease pin 已覆蓋 |
| YugabyteDB | universe live placement：`idc:2 + gcp(asia-east1 統一 zone):1` | `set_preferred_zones` IDC | gate 驗 3/3 GCP tserver SST>0 | **transaction status tablet（系統層）leader 未被 gate 覆蓋** |

**仍不完全等價**：三家在「tpcc 資料表的寫入路徑跨區複製成本」上口徑一致，
但**不可宣稱完全同語意**。YugabyteDB 的 transaction status tablet 屬系統層物件，
現有 placement gate 與 GCP 副本 gate 均只驗 tpcc 表；`實測事實`：YBDB#2 的錯誤
訊息顯示部分交易協調 RPC 的目標是 GCP tserver（§6.3）。YBDB 由早期 read-replica
設計（從未實體化，§8 C1）改為 live voter；GCP 三台統一 `placement_zone`
`asia-east1` 由 LB 均衡分擔。佐證：§9.1 的 `ybdb-universe-config.txt`
（live=idc:2+gcp:1）與兩家 gcp-replica-gate。

## 5. 主結果

範圍說明（`採用決策`）：本節僅含採用 cell（TiDB#2、CRDB#2、YBDB#2）。
CRDB#2/YBDB#2 通過三重驗證（placement gate、GCP 副本存在 gate、GCP 端 probe
20 輪 `fail_count=0`），數字帶真實跨區複製成本；與 07-11 備查批（GCP 零副本、
未付 WAN 成本）不可比。TiDB#2 為 07-12 批，批次差見 §8 O3。

口徑：tpmC_mean 為 R1-R5 mean；CV = `tpmC_range_mean_pct`；延遲 = NEW_ORDER
p50/p95/p99 mean (ms)。逐輪原始值在各 `summary.json` 的
`thread_results.<t>.tpmC_per_round`；逐輪完整輸出在各 round 的 `go-tpc-stdout.txt`（§9.1）。

### 5.1 吞吐

| threads | TiDB tpmC (CV) | CRDB tpmC (CV) | YBDB tpmC (CV) |
|---:|---:|---:|---:|
| 16 | 2077.1 (3.6%) | 9478.9 (15.2%) | 7207.5 (7.8%) |
| 32 | 3820.8 (28.0%*) | 10364.3 (6.2%) | 8148.7 (41.9%†) |
| 64 | 7681.8 (4.6%) | 10809.3 (4.7%) | 10904.1 (11.5%) |
| **128（主水位）** | **13251.6 (4.0%)** | **11001.1 (4.8%)** | **11138.6 (10.4%)** |

\* 見 §6.1（TiDB t32 單輪下降）。† 見 §6.3（YBDB 錯誤與變異）。

### 5.2 t128 延遲（NEW_ORDER, ms）

| t128 延遲 | p50 | p95 | p99 |
|---|---:|---:|---:|
| TiDB | 332.2 | 479.8 | 630.8 |
| CRDB | 379.2 | 724.8 | 959.7 |
| YBDB | 375.8 | 697.9 | 1214.7 |

### 5.3 結果判讀

| 資料庫 | t128 觀察 | 穩定性 | 錯誤 | 可引用結論 | 限制 |
|---|---|---|---|---|---|
| TiDB | 13,251.6 tpmC、p99 630.8ms | CV 4.0%，五輪緊密 | 0 / 1,490,296 | X-CROSS 內 TiDB P-A/A-S 有效參考值 | 與另兩家非同批（§8 O3）；t32 單輪下降未歸因（§6.1） |
| CockroachDB | 11,001.1 tpmC、p99 959.7ms | CV 4.8% | 0 / 2,314,032 | X-CROSS 內 CRDB P-A/A-S 有效參考值 | t16 CV 15.2% 波動未歸因（§6.2） |
| YugabyteDB | 11,138.6 tpmC、p99 1,214.7ms | CV 10.4%；t32 含一次深度下降 | 309 筆（率 0.011-0.03%） | 可引用，**必須附 §6.3 caveat** | 系統層 tablet 未被 gate 覆蓋（§8 O1） |

## 6. 各資料庫觀察與限制

### 6.1 TiDB

- `實測事實`：t32 五輪中 R2=3048.1，其餘四輪為 3965-4119，造成 CV 28.0%。原始值：TiDB#2 [summary.json](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/summary.json) `thread_results.32.tpmC_per_round`；該輪原始輸出：[runs/threads-32/round-2/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/runs/threads-32/round-2/go-tpc-stdout.txt)。
- `觀察`：該下降僅出現一輪，未連續發生。
- `根因未確認`：現有證據不足以歸因該輪下降。
- `觀察`：TiDB t16 明顯低於 CRDB/YBDB，t128 反超為三家最高。
- `機制推論`：低併發劣勢的可能機制為跨區環境下 TSO/2PC 的延遲敏感性，隨併發放大而攤平；未以 transaction trace 直接證實。
- 附註：`efficiency%` 欄為無 think/keying 口徑，依既有慣例忽略（見 [pipeline-log.md](../results/x-cross/pipeline-log.md) §2.3 效度邊界）。

### 6.2 CockroachDB

- `實測事實`：四檔全程 0 error（2,314,032 筆交易）。
- `觀察`：t16 的 CV 15.2% 高於其他檔位（6.2%/4.7%/4.8%）。
- `根因未確認`：t16 波動未歸因。
- `實測事實`：placement gate 計數口徑為 07-14 修正後的 lease 單欄版（§8 C1 之修正五）；本 cell 的 gate 值 idc=11/11。

### 6.3 YugabyteDB 錯誤（309 筆）

- **實測事實**：t32 / t64 / t128 分別出現 57 / 67 / 185 筆交易錯誤，錯誤率 0.011-0.03%；t16 為 0。錯誤樣本可於各 round 檔 grep `execute run failed`（§9.1 raw go-tpc 列）。
- **相關證據**：錯誤訊息為 `UpdateTransaction` RPC 逾時（5s deadline）與 `Leader changed`（`transaction_coordinator.cc:380`）；RPC 目標為 GCP tserver（10.160.152.12:9100）。t32 的深度下降輪（R2=5835.8）與錯誤發生時段在時間上一致。
- **可能機制**（目前最符合證據的機制推論）：部分 transaction status tablet 的 leader 位於 GCP，使該批交易的 commit 協調跨 WAN 並撞 RPC deadline。此為系統層跨區成本的候選解釋。
- **尚未證實**：集群已拆除，未在存活期間直接 dump status tablet 的 leader 分布；現有證據不足以建立單一因果鏈，亦不足以排除其他機制。
- **下一步**（後續驗證）：gcp-replica-gate 增加 status tablet leader 檢查與 `leader_stepdown` 修復，之後重跑驗證錯誤是否歸零。
- `觀察`：若上述機制成立，此現象是 P-A 語意下系統層跨區成本的實例，對容量與 SLO 評估有參考價值；此判讀依賴前述未證實的機制推論。

## 7. 異常案例與採用判定（TiDB#1 → TiDB#2）

- **異常現象**（實測事實）：TiDB#1 t128 五輪 tpmC = 13601.5 / 6513.7 / 6030.0 / 5855.2 / 5879.5，CV 102.2%；自 R2 起顯著下降後盤整；全程 0 error、無 retry/warn。原始值：TiDB#1 [summary.json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/summary.json) `thread_results.128.tpmC_per_round`；下降起點輪：[runs/threads-128/round-2/go-tpc-stdout.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/runs/threads-128/round-2/go-tpc-stdout.txt)。
- **被證偽的假設**（實測事實）：排查初期懷疑「P-A leader 漂移到 GCP」。該訊號來自量測腳本 bug——post-run leader-snapshot SQL 缺 `DB_NAME='tpcc'` 過濾，把系統 schema region 的 leader 計入 GCP（誤導性快照：TiDB#1 [leader-snapshot/tidb-region-leaders.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/tidb-region-leaders.txt)）。以 tpcc-scoped gate 查詢證偽（跑完首次輪詢即 100% IDC），並修正 [Makefile](Makefile) snapshot 查詢（commit `621f24f1`）。
- **重跑結果**（實測事實）：TiDB#2 同參數重跑，t128 五輪 = 13188.2 / 13087.6 / 13268.1 / 13099.1 / 13614.8，CV 4.0%；異常未重現。修正後快照顯示 tpcc leader 只在 3 台 IDC store（8/8/3）、0 GCP：TiDB#2 [leader-snapshot/tidb-region-leaders.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/leader-snapshot/tidb-region-leaders.txt)。
- **根因未確認**：首輪下降的根因無法確認——首輪 VM 已銷毀，無 TiKV metrics 可回溯。
- **採用決策**：因高變異且同參數不可重現，TiDB#1 不納入正式結果、保留備查；採用 TiDB#2。詳細過程：[SESSION-HISTORY.md](SESSION-HISTORY.md) 2026-07-11/12 兩節；commits `621f24f1`、`5c4a9bcc`。

## 8. 效度邊界與未竟事項

### 8.1 已結案問題

| ID | 問題 | 修正 | 驗證證據 | 殘留限制 |
|---|---|---|---|---|
| C1 | CRDB#1/YBDB#1 的 GCP 節點零 tpcc 資料副本（07-13 覆核發現） | 五項：CRDB constraints counted-form；YBDB live 2+1 + 統一 zone；probe 直打 GCP 節點；probe 主機補裝 DB clients（`.15` 原無 client，四 suite probe 全滅實為 command-not-found）；CRDB gate grep 整行計數 bug（經授權修 `prepare.sh`）。防再犯：`gcp-replica-gate.sh` fail-closed、static-check probe 斷言、`phase2-probe-clients` | CRDB#2/YBDB#2 三重驗證全綠（§3 連結；§9.1 矩陣） | YBDB 系統層 tablet 未被相同 gate 覆蓋 → **O1** |

### 8.2 未結案問題

| ID | 缺口 | 對結果影響 | 是否阻擋結案 | 下一步 |
|---|---|---|---|---|
| O1 | YBDB transaction status tablet leader 未被 gate 覆蓋 | YBDB#2 有 309 筆錯誤（0.011-0.03%），引用須附 caveat（§6.3） | 不阻擋（帶 caveat 採用） | gate 補 status tablet leader 檢查 + `leader_stepdown`，重跑驗證 |
| O2 | TiDB#1 首輪下降、TiDB#2 t32 單輪下降均根因未確認 | 不影響採用 cell 的有效性判定 | 不阻擋 | 時間允許時以 N=3 重跑檢查重現性 |
| O3 | 採用三 cell 橫跨兩批：TiDB#2（07-12）vs CRDB#2/YBDB#2（07-14 同批）；且 TiDB#2 量測時 CRDB/YBDB 語意修正尚未存在 | 嚴格同批同語意的三家數據不存在；跨家並讀須註明批次 | 不阻擋條件式引用 | 若結案要求同批：以現行管線（含 gcp-replica-gate + probe 斷言）重跑三家 suite（~11 hr） |
| O4 | TiDB w128 鏈無 `freeze-state/` dump（凍結有執行、無 before-dump 佐證） | TiDB 凍結證據鏈不完整 | 不阻擋 | TiDB w128 鏈加 dump 步驟後重跑才補齊 |
| O5 | X-CROSS `baseline_eligible=false` | 數字不得進 S-BASE/S-K8S 跨家正式排名 | 恆定約束（非缺口） | 無（設計如此） |
| O6 | 與 07-03 TiDB cell（16,808.6 / CV 2.4%，[baseline/w128/20260703T092243+0800/](../results/x-cross/baseline/w128/20260703T092243+0800/)）相比，本輪 TiDB t128 低約 21% | 兩者皆有效 cell；跨批變異未歸因 | 不阻擋 | 引用時註明批次 |
| O7 | P-B placement、A-A profile、failover 場景未涵蓋 | 本報告僅覆蓋 P-A × A-S | 不阻擋本階段報告；阻擋全矩陣結案 | 依既定順序執行 P-B / A-A-RO / A-A |
| O8 | 07-14 批 IDC 3 台 VM destroy 待補（vSphere API 夜間斷線，連三晚同模式；GCP 5 台已 destroy） | 不影響本報告數據 | 不阻擋 | vSphere 恢復後補跑 `phase9-destroy` |

## 9. 證據檔索引

### 9.1 採用 cell 證據矩陣

| 證據類型 | TiDB#2 | CRDB#2 | YBDB#2 | 用途 |
|---|---|---|---|---|
| summary.json | [json](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/summary.json) | [json](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/summary.json) | [json](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/summary.json) | primary 取數來源 |
| raw go-tpc | [runs/](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/runs/)・[t128 r2](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/runs/threads-128/round-2/go-tpc-stdout.txt) | [runs/](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/runs/)・[t128 r1](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/runs/threads-128/round-1/go-tpc-stdout.txt) | [runs/](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/runs/)・[t128 r1](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/runs/threads-128/round-1/go-tpc-stdout.txt) | 逐輪原始輸出；YBDB 錯誤樣本 grep `execute run failed` |
| placement gate | [json](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/prepare/placement-gate-P-A.json)（idc=19/19） | [json](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/prepare/placement-gate-P-A.json)（idc=11/11） | [json](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/prepare/placement-gate-P-A.json)（idc=3/3） | leader/lease 100% IDC 驗收 |
| GCP replica gate | 未執行（gate 於 07-14 引入，晚於 TiDB#2；GCP follower 存在為機制推論，佐證見 SESSION-HISTORY 07-13 節 sar-net 觀察） | [txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/gate/gcp-replica-gate-crdb.txt) | [txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/gate/gcp-replica-gate-ybdb.txt)・[universe.json](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/gate/gcp-replica-gate-ybdb-universe.json) | GCP 真的持有副本（07-14 新增層） |
| near-read 設定 | [txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/prepare/near-read-vars.txt) | [txt](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/prepare/near-read-vars.txt) | [txt](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/prepare/near-read-vars.txt) | 設定面；執行面由 GCP probe 證明（§3） |
| leader/lease/tablet 快照 | [region-leaders](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/leader-snapshot/tidb-region-leaders.txt) | [lease-holders](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/leader-snapshot/crdb-lease-holders.txt)・[nodes](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/leader-snapshot/crdb-nodes.txt) | [leader-counts](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/leader-snapshot/ybdb-leader-counts.txt)・[tservers](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/leader-snapshot/ybdb-tservers.txt)・[universe-config](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/leader-snapshot/ybdb-universe-config.txt) | 跑後分布；YBDB tservers 顯示 6/6 皆有 SST |
| freeze state | 無 dump（§8 O4） | [lease-rebal](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/freeze-state/crdb-lease-rebal-before.tsv)・[split-load](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/freeze-state/crdb-split-load-before.tsv) | [lb-state](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/freeze-state/yb-lb-state-before.txt)・[universe](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/freeze-state/yb-universe-before.txt) | 凍結前 dump |
| 環境 gate | [gate/](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/gate/)・[chrony](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/gate/chrony-gate.txt) | [gate/](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/gate/)・[chrony](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/gate/chrony-gate.txt) | [gate/](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/gate/)・[chrony](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/gate/chrony-gate.txt) | chrony / OS / disk / 隔離 |
| WAN probe | [warmup](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/runs/wan-probe-warmup.txt) | [warmup](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/runs/wan-probe-warmup.txt)（rtt≈8.1ms） | [warmup](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/runs/wan-probe-warmup.txt) | RTT/頻寬/時鐘；round 級在各 round 目錄 |
| DB config | [effective](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/db-config/effective-config.txt) | [settings](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/db-config/cluster-settings.txt)・[effective](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/db-config/effective-config.txt) | [settings](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/db-config/cluster-settings.txt)・[effective](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/db-config/effective-config.txt) | 有效設定 dump |
| env | [host](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/env/db-host-snapshot.txt)・[kernel](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/env/kernel.txt) | [host](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/env/db-host-snapshot.txt)・[kernel](../results/x-cross/baseline/w128/20260714T163716+0800/crdb-vm-6node-P-A-rc-20260714T163716+0800/env/kernel.txt) | [host](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/env/db-host-snapshot.txt)・[kernel](../results/x-cross/baseline/w128/20260714T163716+0800/ybdb-vm-6node-P-A-rc-20260714T163716+0800/env/kernel.txt) | OS/主機環境 |

註：GCP 端 probe 證據連結見 §3（採用 cell 各 20 輪 `fail_count=0`）。

### 9.2 批次級證據（VM rebuild / fetch receipt）

| 批次 | VM 重建證明 | fetch 完整性收據 |
|---|---|---|
| 07-11 | [vm-rebuild-proof](../results/x-cross/baseline/w128/20260711T215200+0800/vm-rebuild-proof-20260711T215200+0800.json) | [fetch-receipt](../results/x-cross/baseline/w128/20260711T215200+0800/fetch-receipt.json) |
| 07-12 | [vm-rebuild-proof](../results/x-cross/baseline/w128/20260712T164221+0800/vm-rebuild-proof-20260712T164221+0800.json) | [fetch-receipt](../results/x-cross/baseline/w128/20260712T164221+0800/fetch-receipt.json) |
| 07-14 | [vm-rebuild-proof](../results/x-cross/baseline/w128/20260714T163716+0800/vm-rebuild-proof-20260714T163716+0800.json) | [fetch-receipt](../results/x-cross/baseline/w128/20260714T163716+0800/fetch-receipt.json) |

### 9.3 備查批（07-11）證據

- summary.json：TiDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/summary.json)・CRDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/summary.json)・YBDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/summary.json)
- raw go-tpc：TiDB#1 [t128 r2 stdout](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/runs/threads-128/round-2/go-tpc-stdout.txt)（下降起點輪）・CRDB#1 [runs/](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/runs/)・YBDB#1 [runs/](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/runs/)
- placement gate：TiDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)（idc=19/19）・CRDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)（idc=11/11；當時計數口徑有誤，且 GCP 零副本）・YBDB#1 [json](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)（idc=3/3；GCP 零副本）
- 誤導/缺陷快照（§7、§8 C1 佐證）：TiDB#1 [無過濾 leader 快照](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/tidb-region-leaders.txt)・YBDB#1 [ybdb-tservers.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/ybdb-tservers.txt)（GCP SST=0B 的直接證據）
- WAN 參考值：CRDB#1 [wan-probe-warmup.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/runs/wan-probe-warmup.txt)（rtt=8504-8539µs、191-227 Mbps）
- 備查批**沒有** GCP replica gate 與有效 probe 證據——該兩層驗證於 07-14 才加入（§8 C1）。

## 10. 追溯紀錄

- 執行歷史：[SESSION-HISTORY.md](SESSION-HISTORY.md)（2026-07-11/12 首輪與 TiDB
  重跑、07-13 GCP 零副本三根因、07-14（續）detached 指揮鏈＋YBDB/CRDB cell、
  07-15 CRDB 三修結案）
- Smoke 前置：[SMOKE-STAGE1-SUMMARY.md](SMOKE-STAGE1-SUMMARY.md)（Stage 1 三家 smoke，07-08/09）
- 資料主檔：[results/x-cross/pipeline-log.md](../results/x-cross/pipeline-log.md)（採用/不採用登記）
- Commits：`621f24f1`（首輪數據 + snapshot SQL 修正）、`5c4a9bcc`（TiDB 重跑）、
  `5a624894` / `420849ad`（GCP 零副本修正）、`8b309599`（probe clients）、
  `2aa8450b` / `1b971cd0` / `9dc7c720`（CRDB lease enforcer / stale race / gate 計數）、
  `afe8872a`（detached 指揮鏈）、`1e5e3332`（CRDB#2/YBDB#2 數據）、`d3bfbf04`（本報告初版）
