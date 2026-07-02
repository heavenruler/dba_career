# 分散式資料庫 PoC 專案技術里程碑（截至 2026-06-22）

## 1. 文件目的與證據邊界

本文件記錄本 PoC 從前期架構研究、測試設計、工具開發，到環境除錯與跨區驗證的重大技術節點。內容只採用本 repo 已提交的文件、程式、測試紀錄與 Git commit；未完成或仍在驗證中的工作會明確標示，不把規劃視為成果。

主要依據：

- 專案目標與交付範圍：[`0_projectFor104/README.md`](../0_projectFor104/README.md)、[`0407.md`](./0407.md)
- 對標設計 SSOT：[`results/PoC-DESIGN.md`](../results/PoC-DESIGN.md)
- 結果與進度索引：[`results/README.md`](../results/README.md)
- 各資料庫執行紀錄：[`TiDB`](../results/tidb-tc1/S-BASE/pipeline-log.md)、[`CockroachDB`](../results/crdb-tc1/S-BASE/pipeline-log.md)、[`YugabyteDB`](../results/yuga-tc1/S-BASE/pipeline-log.md)
- 環境隔離規範：[`results/PHASES.md`](../results/PHASES.md)
- 跨區規劃與實測：[`phase-crossregion/`](../phase-crossregion/)

> 本 PoC 使用 go-tpc 執行 TPC-C-derived stress benchmark，不是 audited TPC-C；結果不能直接對照官方 TPC-C 排名。

## 2. 專案歷程總覽

| 時間 | 階段 | 設計／開發／除錯重大節點 | 狀態 |
|---|---|---|---|
| 2026-03-30～04-10 | 前期研究 | 建立分散式 SQL、跨區同鍵寫入、follower read、HA/DR 與九項 survey 評估面向 | 已完成前期範圍定義 |
| 2026-04-21～04-27 | IaC 與第一版測試鏈 | 建立多測項部署、HAProxy、VM/Kubernetes 流程及獨立壓測 client | 已完成第一版框架 |
| 2026-04-28～05-05 | YugabyteDB 首輪除錯 | 處理 BenchmarkSQL、bulk load、snapshot、RF/schema packing 與 HAProxy 問題 | 已形成可執行路徑，後續由 v4.7 取代 |
| 2026-05-06～05-14 | 三資料庫對標成形 | 納入 TiDB、CockroachDB、YugabyteDB，統一 VM/Kubernetes 結果結構與 go-tpc 工具鏈 | 已完成第一輪跨家框架 |
| 2026-05-18～05-21 | v4.7 baseline 重構 | 建立 PoC-DESIGN SSOT、detached suite、gate、marker、summary 與單節點三隔離級對標 | 已完成 |
| 2026-05-22～06-02 | 三節點 controlled experiment | 完成 shard × replica × HAProxy 拓撲、12-cell dry-run 與三家 5-cell 結果 | N=1 已完成 |
| 2026-05-20～06-04 | 文件與數據治理 | 建立模板、AI 協作規範、artifact-first 審計與三家 pipeline-log 對齊 | 已完成第一輪收斂 |
| 2026-06-06～06-07 | Phase isolation | 分離 S-BASE、S-K8S、T-THRD、X-CROSS，建立 manifest、guard 與 metrics fan-out | 框架已完成 |
| 2026-06-08～06-14 | Kubernetes v4.7 | 由單 cell dry-run 擴充至三資料庫 × limit/unlimit 六組正式 suite | 6/6 已完成，含 caveat |
| 2026-06-08～06-17 | 跨區設計與前置開發 | 建立 5 GCP VM、六節點部署、placement、WAN、chaos、failover 與 pre-flight 規格 | 框架完成，部分能力僅 dry-run plan |
| 2026-06-18～06-19 | IDC↔GCP 實際驗證 | 修正 IaC/gate/防火牆問題，三家完成 smoke；YugabyteDB 跑通真六節點 P-A | smoke 已完成 |
| 2026-06-21～06-22 | Determinism 收斂 | W=4 重跑變異過大，改採同 cluster、freeze/unfreeze、CV 與 W=128 baseline 方向 | 進行中，尚未形成正式結論 |

## 3. 重大技術節點

### M1. 從產品比較轉為可驗證的架構 PoC（2026-03-30～04-10）

**設計**

- 專案目標由單純資料庫選型，收斂為可用性、擴充性、一致性、維運性與成本可行性驗證。
- 評估面向涵蓋 Multi-Region 寫入、衝突處理、MVCC、failover、hotspot、DDL、維運與成本。
- 0407 會議確認以 VM on vSphere 為基礎，跨區場域以 IDC ↔ GCP 為主；交付物包含對照驗證報告、落地計畫與預算評估。

**來源**

- [`0_projectFor104/README.md`](../0_projectFor104/README.md)
- [`0400-to-dba.md`](./0400-to-dba.md)
- [`0407.md`](./0407.md)
- Git：`acd65be`、`630ee49`（跨區同鍵寫入與 follower read 研究）

### M2. 第一版 IaC、HAProxy 與 VM/Kubernetes 測試鏈（2026-04-21～04-27）

**開發**

- 建立 TiDB、YugabyteDB 多測項部署流程與 zone-aware routing。
- 導入 HAProxy，並建立 VM 與 Kubernetes TPC-C 比較框架。
- 將 go-tpc 移至專用 `.31` client 執行，避免 Mac 斷線或本機資源干擾長時間測試。
- 對齊 100 GB disk、128 warehouses、16/32/64/128 併發水位，補齊 VM 磁碟自動擴充與清理流程。

**除錯**

- Kubernetes pipeline 曾因設計不符官方方式而移除後重建。
- 修正 go-tpc v1.0.12、macOS、SSH remote mode、環境變數 word split、磁碟分割偵測與密碼殘留問題。

**來源**

- Git：`8b31891`、`fff487f`、`00c3a39`、`72c5bc5`、`f4393aa`、`4b744f3`、`e84da50`
- [`results/README.md`](../results/README.md)

### M3. YugabyteDB 壓測工具與資料載入除錯（2026-04-28～05-05）

**開發／除錯**

- 第一版使用 BenchmarkSQL，處理 jar build、database 建立、結果目錄競態與 OS collector 相依問題。
- bulk load 過程遇到 `kSnapshotTooOld`，曾測試 batch rewrite、transactional write 與 loadWorkers；最後依 4 vCPU 環境降低 loadWorkers，避免 prepare 階段 CPU 飽和。
- 單節點 RF=1 驗證指出 schema packing 會影響 shard/tablet 判讀。
- 3-node RF=3、HAProxy 與 128 warehouses 路徑完成初步驗證，後續統一改採 go-tpc 重跑。

**技術轉折**

- 此階段證明「資料載入成功」不等於「測試口徑可比較」，促成後續 v4.7 對 gate、prepare、schema、shard 與工具版本的全面重構。

**來源**

- YugabyteDB 歷史流程紀錄：[`results/archive/yuga-tc1-old/`](../results/archive/yuga-tc1-old/)
- Git：`08aee31`、`8b55da3`、`bca3943`、`19b991e`、`1918e4c`、`db69d42`

### M4. 三資料庫共同工具鏈與結果索引成形（2026-05-06～05-14）

**設計**

- 對標對象確立為 TiDB、CockroachDB、YugabyteDB。
- 將結果目錄依資料庫與拓撲重整，統一 vm-1node、vm-3node、HAProxy、Kubernetes 命名。
- 統一使用 go-tpc，明確標示無 think time/keying time，因此本測試屬壓力測試口徑。

**開發**

- 完成三家單節點基準入口及 CockroachDB 納入。
- 建立三家架構圖、pipeline-log 與 README 對照索引。

**除錯／重做決策**

- YugabyteDB 2025.2 LTS 無法沿用 AlmaLinux 10.1 環境，VM template 改為 AlmaLinux 8.10，舊 YugabyteDB 2.20/snapshot 結果標為 deprecated 並重跑。

**來源**

- [`results/README.md`](../results/README.md)
- Git：`8fbdf9e`、`ea37362`、`b4d85c5`、`2b6b887`、`2908e61`、`ef98ea1`、`a7b7b26`

### M5. v4.7 可重現 baseline 規格落地（2026-05-18）

**設計**

- 建立 [`results/PoC-DESIGN.md`](../results/PoC-DESIGN.md) 作為 SSOT。
- 固定 4 vCPU / 16 GB / 100 GB、W=128、threads 16/32/64/128、20 分鐘 warmup、每水位 5 round × 5 分鐘。
- 主對標採 READ COMMITTED；隔離級由 connection string 控制並由 active gate 驗證。
- 三家要求 durable WAL、auto-statistics 關閉、prepare 後 ANALYZE、OS/chrony/disk gate 與 DB-host 監控。
- 定義一次 cold reset、round 1 排除、round 2～5 作正式判讀，並保存 TPCC_TS 與 phase marker lineage。

**開發**

- 建立 vm-1node scaffold、detached suite、deploy/prepare/run/collect/fetch 分段流程。
- 長時間 suite 送至 `.31` 執行，避免 Mac 闔蓋、換網路或中斷影響測試。

**來源**

- [`0519.md`](./0519.md)
- [`results/PoC-DESIGN.md`](../results/PoC-DESIGN.md)
- Git：`eb08dc0`、`02cad09`、`a1fc740`、`d5c9a25`

### M6. 單節點三隔離級對標完成（2026-05-18～05-21）

**開發／驗證**

- 完成 TiDB、CockroachDB、YugabyteDB 的 vm-1node RC、RR、strict 對標；TiDB 不支援原生 SERIALIZABLE，因此 strict 沿用 RR 紀錄並明確標示限制。
- 新增 `summary-from-stdout.py`，由每輪 go-tpc stdout 產生 `summary.json`，補 error rate 與結果追溯。
- 確認三家同名 isolation 的底層機制不同，不將其視為完全相同的單一變數。

**除錯／觀察**

- 修正 PostgreSQL multi-statement isolation gate 只回傳最後一列、connection parameters spacing、CockroachDB cluster setting transaction 與 YugabyteDB effective isolation gate。
- RR/strict 在 CockroachDB 與 YugabyteDB 出現不同 retry/abort pattern，促成 vm-3node 主矩陣只跑 RC 的決策。

**來源**

- [`results/README.md`](../results/README.md)
- [`results/PoC-DESIGN.md`](../results/PoC-DESIGN.md#63-隔離級--拓撲)
- Git：`110c5e7`、`25b7a0a`、`991c05f`、`00c1584`、`c5cba65`、`8b90077`、`5cc2083`

### M7. 三節點 shard × replica controlled experiment（2026-05-22～06-02）

**設計**

- 將三節點拆成 1s1r、1s3r、3s1r、3s3r 四個直連 cell，加上 HAProxy 3s3r，共五種拓撲。
- shard 由 table/schema split 明確控制，replica/RF 由 cluster 設定控制；兩者不可由預設值推算。
- 建立 dry-run anchor、RF/topology/isolation gate、9 表 shard-count hard gate，以及跨 cell destroy/rebuild 規範。

**開發／驗證**

- YugabyteDB 四個直連 cell 與 HAProxy 3s3r 完成。
- TiDB 四個直連 cell、HAProxy 3s3r 及 CockroachDB 5-cell suite 完成。
- 三節點結果目前為 N=1；可作方向性觀察，但尚不足以宣稱跨環境重現性。

**重大除錯**

- YugabyteDB：worker join、master address、RF-aware gate、placement 與 tablet split 流程多次修正。
- TiDB：修正 clustered index `SPLIT TABLE` 語法、小表 split、TiKV 啟動競態與 PD scheduler limit。`replica-schedule-limit=0` 會妨礙 RF 收斂，後改為允許 leader/replica 調度並保留 region 數控制。
- CockroachDB：v26.2 對部分 `crdb_internal` 查詢有限制，shard gate 改用支援的 `SHOW RANGES FROM TABLE`；另修正 history split 整數被 shell 八進位解析。

**來源**

- [`results/PoC-DESIGN.md` §6.3.2](../results/PoC-DESIGN.md#632-vm-3node-元件分配與-dry-run-gate2026-05-21-決策)
- [`2026-06-02-crdb-vm3-5cell-suite-dispatch.md`](../results/dispatch-records/2026-06-02-crdb-vm3-5cell-suite-dispatch.md)
- [`0606-sharding-desc.md`](./0606-sharding-desc.md)
- Git：`242d9df`、`10db790`、`0875bc7`、`4cb782f`、`7826d1e`、`4cc8e94`

### M8. Artifact-first 文件與 AI 協作治理（2026-05-20～06-04）

**設計／開發**

- 建立 README 與 pipeline-log 模板，統一章節、表格、註腳、error rate、來源目錄與命名。
- 建立 `AI-COLLABORATION.md` 與 audit prompt，規定 artifact 為唯一真值、最新 TPCC_TS 優先、不憑空補數字，並要求 Codex/Claude Code 互相校驗。（該檔已於 git `24ab57b1` consolidate 時退役）
- 將 dispatch records 收斂成每資料庫 SUMMARY 與必要分析，並加入 README link verifier 與文件 gate。

**除錯價值**

- 多輪審計找出 placeholder 被誤當結果、summary 缺失、縮寫不一致、失敗 trial 混入主表、pipeline-log 與 artifact 數字不一致等問題。
- 文件治理從「結果整理」提升為測試品質 gate，降低人工摘錄造成的失真。

**來源**

- `results/AI-COLLABORATION.md`（已於 git `24ab57b1` consolidate 時退役；內容未搬移）
- [`results/pipeline-log-template.md`](../results/pipeline-log-template.md)
- [`results/README-template.md`](../results/README-template.md)
- Git：`3f5503e`、`df796f5`、`9992ef4`、`57c3e7b`、`eb22cc4`

### M9. Phase isolation framework 完成（2026-06-06～06-07）

**設計**

- 將結果 scope 分為：`S-BASE`、`S-K8S`、`T-THRD`、`X-CROSS`，避免調參、Kubernetes 或跨區結果污染 VM baseline。
- 建立 manifest schema、`baseline_family`、`baseline_eligible`、logical host id、`metrics/hosts.json` 與 phase metadata。
- thread control 採 path、marker、runtime guard 三層 hard gate。

**開發／除錯**

- metrics fan-out 保留舊 vm1/vm3 檔名相容性。
- Codex review 找出 guard 未接入 runtime、hosts schema 欄位不完整、manifest nested 欄位未驗證；後續 commit 完成修正。

**來源**

- [`results/PHASES.md`](../results/PHASES.md)
- [`phase-k8s/README.md`](../phase-k8s/README.md)
- [`phase-threadcontrol/README.md`](../phase-threadcontrol/README.md)
- Git：`832a3b3`～`7f0dc9c`

### M10. Kubernetes 六組 v4.7 suite 完成（2026-06-08～06-14）

**設計／開發**

- 測試矩陣擴充為 TiDB、CockroachDB、YugabyteDB × limit/unlimit，共六個 cell，固定 RC 與 HAProxy 3s3r。
- 先以 expected/actual/diff dry-run 驗證 workload、isolation、replica、split、資源限制與網路設定，再放行正式 suite。
- 每 cell 使用隔離 namespace，並規劃 PVC/PV/CRD/local-path cleanup gate，避免前一資料庫殘留污染下一組。

**驗證**

- 6/8 完成 TiDB-unlimit，6/9 完成 TiDB-limit；CockroachDB 與 YugabyteDB 後續完成，6/14 YugabyteDB-limit 使六組矩陣達 6/6。
- YugabyteDB-limit 的 t128 round 5 有 caveat，須保留於結果判讀，不將單一異常隱藏。

**來源**

- [`analytics-S-K8S-2026-06-15.md`](./analytics-S-K8S-2026-06-15.md)
- [`phase-k8s/test-plan-smoke.md`](../phase-k8s/test-plan-smoke.md)
- Git：`82949ab`、`04bc9a0`、`df17a70`、`2239124`、`95865ae`、`69dbee3`、`77728d3`

### M11. Cross-region framework 與 pre-flight 收斂（2026-06-08～06-17）

**設計**

- 規劃 IDC 3 nodes + GCP 3 nodes 的資料庫拓撲，GCP 另配置 HAProxy 與 client，共 5 台 GCP VM。
- workload 規劃包含 A/S、A/A Read Only、A/A；placement 分 P-A 與 P-B；chaos 規劃 C1/C4/C7，F1 failover 與 chaos 分離。
- 6/15 replan 將工作分為 Tier 1 TiDB-only dry-run 與 Tier 2 能力儲備，避免尚未成熟的三資料庫 full sweep 阻塞短期驗證。
- 建立 L1～L5、A～J 的 pre-flight test plan，涵蓋 Terraform、VM、IAP、Ansible、DB、workload、measurement、collect、chaos/failover 與 archive。

**開發**

- 完成 iac-gcp 5 VM、TiDB/CockroachDB/YugabyteDB vm6 playbook、placement SQL、zone-local client gate、WAN probe、chrony 10-host gate、chaos/failover dry-run planner。

**來源**

- [`decisions-2026-06-08.md`](../phase-crossregion/decisions-2026-06-08.md)
- [`REPLAN-2026-06-15.md`](../phase-crossregion/REPLAN-2026-06-15.md)
- [`PRE-FLIGHT-TEST-PLAN-2026-06-17.md`](../phase-crossregion/PRE-FLIGHT-TEST-PLAN-2026-06-17.md)
- Git：`1485812`、`0c17ae9`、`801c1b4`、`2fc3df2`、`42b7a55`、`cd47ec6`

### M12. 真實跨區部署與三資料庫 smoke（2026-06-18～06-19）

**開發／除錯**

- 修正 GCP startup script heredoc 與 chrony gate `KeyError`。
- 實際 IaC/deploy 驗證遇到防火牆阻塞，整理 IDC/GCP CIDR 與三資料庫連線埠申請範圍。
- 修正 TiDB、CockroachDB、YugabyteDB vm6 playbook 與共同 run 流程。
- YugabyteDB 初次僅部分成功，後續定位部署/placement 根因，完成真六節點跨 region P-A smoke。

**驗證狀態**

- 6/19 session 記錄 TiDB、CockroachDB smoke 完成；YugabyteDB 經修正後跑通，commit 記錄 tpmC 6812.2。
- 此處屬 smoke 與路徑驗證，不等同正式 W=128、N≥3 的跨區比較結論。

**來源**

- [`2026-06-18-fw-request-net.md`](./2026-06-18-fw-request-net.md)
- [`SESSION-HISTORY.md`](../phase-crossregion/SESSION-HISTORY.md) (06-18 iac-verify)
- [`SESSION-HISTORY.md`](../phase-crossregion/SESSION-HISTORY.md) (06-19 3db-smoke)
- Git：`61311cd`、`d8af817`、`da3d03a`、`20725d1`

### M13. Determinism 問題浮現，正式 baseline 重新收斂（2026-06-21～06-22）

**已確認問題**

- 6/21 使用 W=4 執行跨區測試，同 cluster redeploy 後各資料庫 run-to-run 差異過大；該組不能作正式跨家比較。
- session 將原因定位方向放在低 warehouse contention、重新部署造成的 cluster state 差異、placement/rebalancing 與 warmup 狀態，但尚未完成因果驗證。

**進行中設計**

- 規劃同一 cluster 連跑、freeze/unfreeze scheduler/balancer、R2～R5 CV/median 檢查，再進 W=128 正式 baseline。
- 6/22 工作樹仍有 Makefile、freeze scripts、round-only runner 與 HAProxy 設定的未提交變更；依目前 repo 狀態，不列為已完成 milestone。

**來源**

- [`SESSION-HISTORY.md`](../phase-crossregion/SESSION-HISTORY.md) (06-21 determinism)
- [`SESSION-HISTORY.md`](../phase-crossregion/SESSION-HISTORY.md) (06-22 determinism-v2)（工作樹未提交，僅作進行中紀錄）
- Git：`d91b0aa`

## 4. 除錯歷程歸納

| 類型 | 代表問題 | 專案形成的控制措施 |
|---|---|---|
| 環境相依 | YugabyteDB 2025.2 與 AlmaLinux 10.1 不相容 | 統一 AlmaLinux 8.10，舊結果 deprecated 後重跑 |
| 工具差異 | BenchmarkSQL/go-tpc 參數、driver、remote mode 不一致 | 三家統一 go-tpc 版本與共同 wrapper |
| 長跑可靠性 | Mac 闔蓋、換網路或本機中斷 | `.31` detached suite、phase marker、status/fetch target |
| 隔離級失真 | DB default、driver TxOptions、session 值不一致 | connection string + active gate；YugabyteDB triple gate |
| 資料載入 | snapshot too old、連線殘留、prepare CPU 飽和 | terminate session、調整 batch/loadWorkers、prepare hard gate |
| Shard/RF | 預設 shard 推算錯誤、split 語法與 RF 未收斂 | schema-level split、cluster-level RF、9 表 shard hard gate |
| 背景行為 | auto analyze、PD scheduler、tablet/range rebalancing | baseline 關閉 auto stats；調度行為留存設定與收斂 gate |
| Artifact 缺漏 | summary、metrics、marker 或來源時間戳缺失 | `summary.json`、七類 marker、TPCC_TS lineage、artifact-first audit |
| 文件失真 | placeholder、失敗 trial、舊數據混入主表 | deprecated archive、模板、link verifier、Codex/Claude 交叉審計 |
| 跨區連線 | IAP、host mapping、HAProxy IP、FW port 未對齊 | pre-flight、CIDR/port 清單、zone-local fail-closed |
| 重現性 | W=4 與 redeploy 造成 run-to-run 高變異 | 暫停正式結論；改驗同 cluster、CV 與 W=128 baseline |

## 5. 截至 2026-06-22 的完成度

### 已完成

- 三家 vm-1node 三隔離級 v4.7 對標。
- 三家 vm-3node 五種拓撲 RC suite，現有結果為 N=1。
- 三家 Kubernetes limit/unlimit 六組 v4.7 suite。
- Phase isolation、artifact schema、pipeline-log/README 模板與 AI 審計規範。
- IDC↔GCP 六節點部署路徑與三資料庫 smoke 驗證。

### 已完成框架、尚未完成正式結果

- Cross-region A/S、A/A Read Only、A/A 完整 sweep。
- P-A/P-B 全矩陣、C1/C4/C7 chaos 與 F1 failover 實測。
- Thread-control 正式 benchmark。
- 三節點 N=3 獨立重跑。

### 目前阻塞正式結論的事項

- Cross-region W=4 結果不具 determinism，不能升級為正式 baseline。
- 6/22 determinism v2 尚在修正與 review，未證明 freeze/unfreeze、warmup、round-only 與 rollback 流程可安全執行。
- 對外結論仍須依 artifact、N 值、caveat 與相同 workload/placement 口徑判讀。

## 6. 本專案形成的工程方法

1. **先定義可比性，再執行 benchmark**：硬體、隔離級、durability、warmup、統計、shard、replica 必須先鎖定。
2. **設計值不等於實際值**：所有 isolation、RF、shard、placement 都要以 active/readback gate 驗證。
3. **長跑流程必須 detached 且可恢復**：執行不依賴 Mac session，並保存 marker、lock、log 與 lineage。
4. **Artifact 是唯一數據真值**：README、pipeline-log、analysis 都只能引用可追溯原始結果。
5. **Baseline 與 exploratory experiment 分離**：用 phase scope 與 `baseline_eligible` 防止調參、Kubernetes、跨區資料混入 S-BASE。
6. **失敗與 caveat 必須可見**：失敗 trial 不進主表，但必須保留於註解或 session，避免只呈現成功數字。
7. **重現性高於單次峰值**：N=1 只作方向性觀察；正式結論需獨立重跑與跨 run 變異檢查。

## 7. 後續 milestone 判定條件

| 下一節點 | 完成條件 |
|---|---|
| Cross-region deterministic baseline | W=128、正式 warmup、同一 suite R2～R5 完整，CV/median 與 artifact lineage 可驗證 |
| 三資料庫跨區公平比較 | 相同 placement、workload、isolation、scheduler policy 與量測範圍，三家均通過 pre-flight |
| N=3 baseline | 每個候選案例完成三次獨立 rebuild/deploy/prepare/run/collect，跨 N 差異可解釋 |
| Chaos / failover | C1/C4/C7、F1 有核准 runbook、rollback、RTO/RPO 與完整記錄，不只 dry-run planner |
| 對外 PoC 結論 | 對照報告、落地計畫、風險與成本假設均引用已驗證結果，未完成項目明確列為限制 |
