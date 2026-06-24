# 第一階段 PoC 成果與下一步決策

> 受眾：DBA
> 頁數：11 頁（對齊 `0626-slide-v4.pdf`）
> 定位：第一階段成果與決策框架；本份**不是**工程細節報告
> 引用：`1_MeetingMinutes/analytics-S-K8S-2026-06-15.md` / `phase-crossregion/decisions-2026-06-08.md` / `1_MeetingMinutes/2026-06-09-distributed-db-adoption-non-technical.md` / `results/PoC-DESIGN.md` / `results/README.md` / `poc/*` 等相關必要檔案

---

## v4 簡報 {FIXME} 對照表

> 對應 `0626-slide-v4.pdf` 內 4 處逐字標記，列管待補。

| # | PDF Slide | 位置 | 原文 |
|---|---|---|---|
| **F1** | Slide 3 | 「IaC 與第一版測試流程鏈」row 重大節點 cell | `**{FIXME}** Chain 的 flow & Key Point` |
| **F2** | Slide 6 | 同 IDC / 同硬體 基準 橫幅 | `**{FIXME}** 測試架構圖補完 ; db component intro ; 各節點較重損耗` |
| **F3** | Slide 8 | 副標 | `**{FIXME}** 架構圖示說明解釋 P-A/P-B placement` |
| **F4** | Slide 11 | 「短期 EX: Y26/07」column 標題下 | `**{FIXME}** 補完完整測試時間描述` |

---

## Slide 1 — Title

**第一階段 PoC 成果與下一步決策**

分散式資料庫架構 × 跨區域驗證 × 決策框架

2026-06-26 · DBA

---

## Slide 2 — Outline

- 專案迄今歷程
- 第一階段 PoC 測試數據彙整
- 第二階段 跨區域 / 跨專線執行進度
- 決策框架說明
- 後續推進

---

## Slide 3 — 專案歷程 ① 研究定義到跨家框架

> **本頁核心**：先定義問題與比較口徑，再建立可重複執行的基礎設施與三資料庫共同工具鏈

| 時間 | 階段 | 設計／開發／除錯重大節點 | 狀態 |
|---|---|---|---|
| **2026-03-30～04-10** | **前期研究** | 定義分散式 SQL、跨區同鍵寫入、follower read、HA/DR 與九項 survey 評估面向 | ✅ 完成 |
| **2026-04-21～04-27** | **IaC 與第一版測試流程鏈** | 建立多測項部署、HAProxy、VM / Kubernetes 流程及獨立壓測 client。**{FIXME}** Chain 的 flow & Key Point | ✅ 完成 |
| **2026-04-28～05-05** | **YugabyteDB 首輪除錯** | 處理 BenchmarkSQL、bulk load、snapshot、RF / schema packing 與 HAProxy 問題 | ✅ 完成 |
| **2026-05-06～05-14** | **三資料庫對標成形** | 納入 TiDB、CockroachDB、YugabyteDB，統一結果結構與 go-tpc 工具鏈 | ✅ 完成 |

**判讀**：此階段完成的是「可比較的工程框架」，早期測試數字不直接納入 v4.7 正式結果。

---

## Slide 4 — 專案歷程 ② 基準、三節點與治理

> **本頁核心**：將測試從可執行提升為可重現、可追溯、可拆解成本來源

| 時間 | 階段 | 設計／開發／除錯重大節點 | 狀態 |
|---|---|---|---|
| **2026-05-18～05-21** | **v4.7 基準重構** | 建立 PoC-DESIGN SSOT、detached suite、gate、marker、summary 與單節點三隔離級對標 | ✅ 已完成 |
| **2026-05-22～06-02** | **三節點 controlled experiment** | 完成 shard × replica × HAProxy 拓撲、12-cell 試跑與三家 5-cell 結果 | ✅ N=1 已完成 |
| **2026-05-20～06-04** | **文件與數據治理** | 建立模板、AI 協作規範、artifact-first 審計與三家流程-log 對齊 | ✅ 第一輪收斂完成 |
| **2026-06-06～06-07** | **Phase isolation** | 分離 S-BASE、S-K8S、T-THRD、X-CROSS，建立配置宣告、守門檢查與指標分發 | ✅ 框架完成 |

**判讀**：正式數字必須能追回測試條件、時間戳、結果檔案與 done marker；缺少來源時不進主表。

---

## Slide 5 — 專案歷程 ③ Kubernetes 到跨區驗證

> **本頁核心**：已完成 Kubernetes 對照與跨區技術路徑，正式跨區效能仍受 determinism gate 約束

| 時間 | 階段 | 設計／開發／除錯重大節點 | 狀態 |
|---|---|---|---|
| **2026-06-08～06-14** | **Kubernetes v4.7** | 由單 cell 試跑擴充至三資料庫 × limit / unlimit 六組正式 suite | ✅ 6/6 完成，含 caveat |
| **2026-06-08～06-17** | **跨區設計與前置開發** | 建立 5 GCP VM、六節點部署、placement、WAN、chaos、failover 與 pre-flight 規格 | 🟡 框架完成；部分能力僅試跑 plan |
| **2026-06-18～06-19** | **IDC↔GCP 實際驗證** | 修正 IaC、gate、防火牆與 YugabyteDB placement，三家完成真六節點探煙 | ✅ 探煙完成；非正式效能結論 |
| **2026-06-21～06-22** | **Determinism 收斂** | W=4 重跑變異過大，改採同 cluster、調度關 / 開、CV 與 W=128 基準 | 🟡 進行中；尚未形成正式結論 |

**決策界線**：目前可確認六節點跨區交易路徑可行；正式跨家排序必須等待 W=128、R2～R5 中位數 / CV 與完整回復流程驗收。

---

## Slide 6 — 三家資料庫導入定位

> **本頁核心**：三家有不同的導入定位，不適合用「誰最快」單一排序判讀

### 導入定位

| 資料庫 | 第一階段觀察 | 適合的導入定位 |
|---|---|---|
| **TiDB** | VM 與 K8s 吞吐表現較佳；K8s 保留率較高 | **短期優先候選**之一，可優先進入應用情境對接 |
| **CockroachDB** | 一致性語意較強（SSI 預設）；但 SI / SSI 模式下 retry 與效能成本明顯 | **保留觀察**：應用層需評估 retry 容忍度與交易模式 |
| **YugabyteDB** | VM + HAProxy 表現可觀；K8s 結果**目前不宜直接作為導入結論** | **保留觀察**：K8s 部署仍需調校與驗證，VM 路徑可進入評估 |

### 同 IDC / 同硬體基準（vm-3node-haproxy-3s3r-rc，t=128 平均 tpmC）

> **{FIXME}** 測試架構圖補完 ; db component intro ; 各節點較重損耗

```
TiDB           ≈ 26,900
YugabyteDB     ≈ 15,600
CockroachDB    ≈ 15,000
```

> 註：本組數字為 controlled experiment 基準（vm-3node 拓撲全部鎖定 sharding / replication 參數），目的是觀察拆解後的純效應，**不直接代表各家「拿出來就跑」的生產表現**（見 `results/PoC-DESIGN.md` §6）。

### 三家架構差異速覽

| | TiDB | CockroachDB | YugabyteDB |
|---|---|---|---|
| 部署形態 | TiDB compute + TiKV storage + PD（多 process） | single-binary | YSQL + DocDB（雙 process） |
| 原生強一致 | 不支援原生 SERIALIZABLE | SSI 預設 | SSI |
| 1-node TPCC 行為 | 已對標（基準用） | 已對標（基準用） | 已對標（基準用） |
| 3-node scale-out 行為 | 觀察值最高 | 觀察值中等 | 觀察值中等 |

> 商業實體 / 授權 / 採購層面議題請見 Slide 10 / 補充段風險頁。

---

## Slide 7 — VM 與 Kubernetes 效能差異

> **本頁核心**：K8s 化對 TiDB 與 CockroachDB 屬可接受範圍；YugabyteDB 在 K8s 下退化顯著、列為調校與驗證項

### t=128 平均 tpmC（K8s 不設資源限制 vs VM 基準）

| 資料庫 | VM 基準 | K8s（不限資源） | K8s 保留率 | K8s（資源限制情境）保留率 |
|---|---:|---:|---:|---:|
| TiDB | 26,947 | 23,442.9 | **約 87%** ✅ | 約 58% |
| CockroachDB | 15,033 | 12,196.7 | **約 81%** ✅ | 約 43% |
| YugabyteDB | 15,632 | 2,997.6 | **約 19%** ⚠ | 約 10% |

> **「資源限制情境」說明**：Kubernetes 上設定每個資料庫 pod 的 CPU 上限為 2 vCPU、記憶體上限為 8 GiB（相對於 VM 的 4 vCPU），用以觀察生產環境若採用較緊資源配額時的吞吐表現。

### 延遲 / 錯誤率觀察

- **延遲（NEW_ORDER p99）**：K8s 限制資源情境下 CockroachDB 延遲約為 VM 的 3 倍、YugabyteDB 高出更多，建議納入 SLA 設計
- **錯誤率**：24 個 (cell, thread) 組合中僅一例非零（TiDB-unlimit T16 集中於單一 round 的 16 秒 stall event；其餘 99.998% 完成），仍需配合 K8s 部署層級優化
- **K8s 部署優化方向**：服務網格 / Service Mesh、Pod 反親和性、leader election timeout、CPU pinning、可觀測性留存等屬後續工程項

---

## Slide 8 — 跨區域 / 跨專線進度

> **本頁核心**：框架與規劃已建立；試跑 blocker 修正後才能進入量測
> **{FIXME}** 架構圖示說明解釋 P-A/P-B placement

### Done — 已完成

- 10 道技術議題拍板（GCP 5 VM 拓撲、9 cell-track 範圍、placement P-A/P-B、chaos C1/C4/C7、A-A 全 W=128 等）
- 非技術議題收斂為 9 項（5 待決 + 4 已拍板）；已拍板含：跨區 DR「現行 No、中長期必需」、PG→TiDB「TiDB 為主」、是否全面採用 TiDB「Unknown 待補背書 4-6 週」、TLS 補測「僅備註不另測」
- IaC（GCP 5 VM Terraform）、ansible playbook、suite scripts、chrony drift gate（10-host 升級版，drift_median 0.017 ms）
- IDC 端機器盤點與 K8s 殘留清理
- GCP 5 VM 已驗證可建可連，已 destroy 釋出（節費）

### Pending — 待執行

- 修正 ansible inventory / playbook hostname mapping（B1，10 分鐘）與 IDC HAProxy IP（B2，5 分鐘）兩處 blocker
- terraform apply 重建 GCP 5 VM（28 秒）
- 完成 cross-region 跨區 試跑驗證
- 進入量測實跑

### 量測時間估計

- **量級**：約 150 小時量測執行時間（360 rounds × 平均 25 分鐘）
- **連續執行**：約 6.25 天 wall-clock
- **實務上排程**：約 19 個工作天，**會分批量測並設置審查閘門**（避免一次性 6 天連續佔用 IDC 端機器）
- **計費**：GCP 5 VM 連續開機約 USD 590 / 月，量測期間約 USD 40 自然發生

### Risk — 風險

- 量測期間 IDC 端機器負載連續（建議避開其他維護）
- 部分 K8s cap 情境下 TPCC client 可能 hang（已於第一階段 Cell 6 YugabyteDB-limit T128 觀察到 deterministic 行為，跨區域階段拓撲不同，**列為觀察項**）
- 跨區域網路 drift 異常需 fail-closed gate（已實作於 chrony 10-host 版）

---

## Slide 9 — X-CROSS 初步結果 (06-22 ~ 06-23)

> W=4 framework 驗證；不與 S-BASE/S-K8S 直接對比

條件：**同 cluster N 連跑**、W=4、16 threads、每 round 5 min、5 rounds、控制節點 = `.31` (IDC client, 取代 Mac IAP tunnel)、部署 → 探煙 → 清理 → 下一個 DB（序列流程鏈）。

| 資料庫 | R1 | R2 | R3 | R4 | R5 | 平均 | CV | 備註 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| **TiDB v8.5.2** | 9525.5 | 9553.2 | 9786.9 | 9393.2 | 9530.8 | **9566.0** (R2-R5) | **1.67%** ✅ | placement P-A，6 store ALIVE |
| **CockroachDB v26.2.0** | 8409.5 | 8055.3 | 7902.5 | 7720.9 | 7472.3 | **7787.8** (R2-R5) | **3.23%** ✅ | placement P-A num_voters=3，lease 100% IDC |
| **YugabyteDB 2025.2** | 102.0 | 226.9 | 6424.2 | 6259.3 | 6206.2 | **6296.6** (R3-R5) | **1.82%** ✅ | Plan B (IDC live RF=3 + GCP read_replica RF=3)；R1+R2 為 postgres backend cache 暖機 |

> 數據來源：`results/x-cross/determinism/run1-20260622T131459+0800/{tidb,crdb}-vm-6node-P-A-rc-run1-*` 與 `results/x-cross/determinism/run2-20260622T231927+0800/ybdb-vm-6node-P-A-rc-run2-*`。commit `dd948dcf` + `28e39881`。

### 已確認結論

- 06-21 觀察到的 ±526% / ±50% 變異主因為「每輪重新部署」造成 placement / cache / scheduler 狀態異動，與 W=4 contention 是兩個獨立來源。
- 同一 cluster 連跑時，三家 W=4 R2-R5（或 YBDB R3-R5）的 CV ≤ 5%，重現性已建立。
- YBDB Idle=0 詭異（read_replica 模式 良性）解法：(a) gate 改用 `get_load_move_completion=100%`，(b) timed run 前 `set_load_balancer_enabled=0`，run 後 enable=1。
- CRDB lease gate SQL 改用 `[SHOW RANGES FROM DATABASE tpcc WITH TABLES, DETAILS]`（v26.2 `crdb_internal.ranges` 無 `table_name` 欄位且禁止存取）。

### Caveat

W=4 為 framework / contention 驗證 ≠ 正式基準；R2-R5（YBDB R3-R5）CV ≤ 5% 已建立但**不可作跨家排名**；後續需依「v2 完成條件」回到 W=128。

---

## Slide 10 — 建議決策框架

> **本頁核心**：不是選一家，是先界定 application 條件、再排序候選；本份簡報提供框架不替代決策

### 三層候選分類

| 分類 | 內容 | 處置 |
|---|---|---|
| **短期候選** | TiDB | 優先進入應用情境對接 |
| **保留觀察** | CockroachDB | 依一致性需求、retry 容忍度、維運成本評估 |
| **保留觀察** | YugabyteDB | VM 路徑可評估；K8s 路徑需先完成部署層級調校與驗證 |
| **暫不作結論** | 跨區域場景、K8s 退化未定位項 | 等下一階段量測與調校產出再回頭評估 |

### Application owner 需要確認的議題

1. **交易一致性需求**：是否需要 SERIALIZABLE / SSI？是否可接受 READ COMMITTED？
2. **可接受延遲**：在尖峰 t=128 等級負載下，p99 是否需要 500ms / 1s / 2s 以內？
3. **retry / timeout 行為**：應用層是否能接受 SI / SSI 模式下的 retry 機制？timeout 預期值？
4. **RTO / RPO**：跨區域 failover 是否需要 < 30s RTO？是否容許資料 lag？
5. **連線層 / 交易模式調整**：是否能配合 HAProxy / pgbouncer / 連線池與短交易模式調整？

> 上述五項取得共識前，建議**不直接拍板採購單一資料庫**。

---

## Slide 11 — 後續推進階段

> **本頁核心**：分三階段推進，不是 task list

### 短期 EX: Y26/07

> **{FIXME}** 補完完整測試時間描述

- 修補 ansible inventory / playbook 兩處 blocker
- terraform apply 重建 GCP 5 VM
- 跑通 cross-region 跨區 試跑
- W=4 框架已驗，接 W=128 基準
- freeze/unfreeze、round-only runner、暖機、placement gate 全部通過審查
- X-CROSS 完成 determinism 流程驗收，啟動正式 W=128 基準量測

### 中期

- A-S / A-A-RO / A-A 三個 workload profile × P-A / P-B placement × 三家資料庫，依檢驗指標分批量測
- Failover 與 Chaos Engineering（C1 / C4 / C7）實際驗證
- 跨區域 analytics 第二份報告
- 補齊 YugabyteDB K8s 退化成因調查（P-A/P-B、A-S/A-A-RO/A-A）

### 決策

- Application owner 完成 Slide 10 五項議題確認
- 原廠後勤對接狀況說明
- 採購 / 商業實體層面審查完成
- 選定一個或多個短期候選進入導入規劃

---

## 補充 A — 現況摘要（PDF 無對應，原 Slide 1 內容）

> **本頁核心**：第一階段已給出技術證據，下一步需要 application owner 與管理層共同界定導入場景

### 進度地圖

| Phase | 範圍 | 狀態 |
|---|---|---|
| **S-BASE**（VM 基準） | TiDB / CockroachDB / YugabyteDB × 指定 isolation × 指定拓撲 | ✅ 已完成主要驗證 |
| **S-K8S**（K8s 對照） | 三家 × {unlimit, limit} = 6 cell | ✅ 已完成主要驗證 |
| **T-THRD**（thread control） | 執行緒量測行為對標 | 🟡 待完成 |
| **X-CROSS**（跨區域 / 跨專線） | 6-node TiDB cluster + GCP 跨區、placement、failover、chaos | 🟡 框架與規劃已建立；量測數據待執行 |

### 三點結論

1. **已完成什麼**
   - 三家資料庫於同一 4 vCPU 硬體 + W=128 TPCC 工作負載下完成基準對標
   - VM 與 Kubernetes 部署平面差異已實測量化
   - 跨區域測試框架（IaC / playbook / suite scripts / chrony drift gate）已就位

2. **已觀察到什麼**
   - TiDB 與 CockroachDB 在 K8s 部署下吞吐保留率約八成
   - YugabyteDB 在 K8s 部署下吞吐明顯退化，**成因尚未定位，列為後續調校項**
   - 全程 N=1 量測；正式採購或導入決策前**需補 N=3 重跑**（已列入下一階段）

3. **下一步需要誰決策**
   - **application owner**：交易一致性需求、可接受延遲、retry / timeout 行為、RTO / RPO
   - **管理層**：候選廠商之商業實體限制、預算編列窗口（Q4 對齊）
   - **DBA / 維運**：依上述決策選擇導入路徑（VM 或 K8s、是否啟跨區）

---

## 補充 B — 三階段 tpmC 彙整（S-BASE / S-K8S / X-CROSS）

> **重要**：S-BASE / S-K8S 用 W=128 t=128（正式基準 workload），X-CROSS 目前為 W=4 t=16（framework 驗證 workload）。三者數字**不可直接相減**，僅可在「同 workload 條件」內比較保留率。

### Table A. VM 基準 → K8s 額外開銷（同 workload：vm-3node-haproxy-3s3r, RC, t=128）

| 資料庫 | S-BASE (VM) tpmC | S-K8S (unlimit) tpmC | S-K8S (limit) tpmC | unlimit / VM | limit / VM | p99 unlimit Δ | p99 limit Δ |
|---|---:|---:|---:|---:|---:|---:|---:|
| **TiDB v8.5.2** | 26,947 | 23,442.9 | 15,751.9 | **87.0%** | **58.5%** | +17% | +111% |
| **CockroachDB v26.2** | 15,033 | 12,196.7 |  6,493.5 | **81.1%** | **43.2%** | +27% | +192% |
| **YugabyteDB 2025.2** | 15,632 |  2,997.6 |  1,604.5 | **19.2%** ⚠ | **10.3%** ⚠ | +669% | +1556% |

> 數據來源：`analytics-S-K8S-2026-06-15.md` Section 3。tpmC = t=128 平均；p99 為 NEW_ORDER。

### Table B. X-CROSS 跨區框架驗證（W=4 t=16, same-cluster N-round; 06-22/06-23）

> 同 Slide 9 主表，此處不重複。

### Table C. 階段對比解讀

| 階段對比 | 條件可比？ | 觀察重點 |
|---|---|---|
| **S-BASE ↔ S-K8S** | ✅ 同 workload (W=128 t=128) | K8s 額外開銷：TiDB 高保留率 87% / CRDB 81% / YBDB 19%（YBDB K8s 化大幅退化）|
| **S-K8S ↔ X-CROSS** | ❌ workload 不同 (W=128 t=128 vs W=4 t=16) | 不可比；X-CROSS 為 framework 驗證，不是正式跨家排名 |
| **X-CROSS 內部** | ✅ same-cluster N-round | 重現性 CV ≤ 5%：證實 06-21 ±526% 變異主因為重新部署，不是 W=4 contention 本身 |

### 階段判讀

1. **S-BASE 正式基準**：W=128 t=128 數字可作對外排名參考（TiDB > CRDB ≈ YBDB）。
2. **S-K8S 退化模式分歧**：TiDB / CRDB K8s 額外開銷在合理範圍 (13-19% drop)；YBDB K8s 退化嚴重 (80% drop)，p99 +669%，反映 YBDB postgres backend + DocDB 雙 process 在 K8s pod 內 IPC + CPU contention 放大。
3. **X-CROSS 框架已驗**：部署 → 探煙 → 清理流程鏈跑通，三家 W=4 R2-R5 CV ≤ 5%，可進入正式 W=128 跨區基準；**不可直接以 X-CROSS W=4 數字推論跨區效能排名**（W=4 contention dominates）。

---

## 補充 C — 2026-06-16～2026-06-22 實作進度更新（v2 重整輸入）

> 本段為 v2 簡報的新增事實基礎；Slide 5 「Determinism 收斂」row 與 Slide 9 X-CROSS 主表均由此衍生。

### 進度摘要

| 日期 | 實作／驗證進度 | 結果與限制 |
|---|---|---|
| **06-16** | 整合 CockroachDB / YugabyteDB 六節點 playbook、IDC VM 基準冷重置、WAN probe、C1/C4/C7 chaos planner 與 F1 failover planner | Chaos / failover 此時只有試跑指令規劃器，不代表已完成故障實測 |
| **06-17** | 完成 cross-region pre-flight test plan v2；修正 WAN probe、iperf3 bootstrap、sweep archive 等五項啟動前問題 | 框架 reserve 與啟動條件建立完成；正式量測尚未開始 |
| **06-18** | IDC / GCP IaC 重建與 destroy 驗證通過；TiDB 部署通過；修正 GCP startup-script heredoc 與 chrony gate `KeyError` | IDC↔GCP 控制平面受防火牆阻擋，當日無跨區正式數據；後續完成 13 TCP ports / 9-rule / CIDR 申請整理 |
| **06-19** | 防火牆開通後完成 TiDB、CockroachDB、YugabyteDB 真六節點 P-A 探煙；新增九階段 Makefile orchestration | 僅 W=4、16 threads、短時間探煙；證明部署與交易路徑可行，不是正式效能排名 |
| **06-20** | 補強 YugabyteDB 跨區 timing、Plan A、WAN probe 與 leader / lease / tablet snapshot instrumentation | 提升 placement 與跨區狀態的可觀測性，仍未形成 W=128 基準 |
| **06-21** | 導入 YugabyteDB Plan B 與 best-practice gates；保留 21 次 smoke artifacts；同 cluster 重跑 determinism 對照 | 三家 W=4 run-to-run 差異均過大，W=4 結果判定不可作正式基準 |
| **06-22** | 規劃 determinism v2：同 cluster round-only、scheduler / balancer 關閉、R2～R5 CV / 中位數、W=128 正式基準 | Makefile、調度關/開、round-only runner 與 HAProxy 仍在工作樹及審查；尚未驗收，不得標示完成 |

### 06-19 三資料庫真六節點探煙

共同條件：IDC 3 nodes + GCP 3 nodes、P-A placement、READ COMMITTED、IDC client、W=4、16 threads、短時間單輪。

| 資料庫 | smoke tpmC | 驗證到的事項 | 不可推論的事項 |
|---|---:|---|---|
| **TiDB v8.5.2** | **11112.9** | 六節點 cluster 與 IDC leader placement 可執行交易 | 不可與 VM/K8s W=128 基準直接比較 |
| **CockroachDB v26.2.0** | **2145.2** | 六節點存活、region locality 與跨區交易路徑可運作 | 不可由單輪數字判定正式延遲或跨家排名 |
| **YugabyteDB 2025.2.2.2** | **6812.2** | 真六 tserver、IDC/GCP placement 與 preferred zone 路徑跑通 | 不可把相對 IDC-only 的差異直接歸因為 scale-out 效益 |

> 數據來源：`phase-crossregion/SESSION-2026-06-19-3db-smoke.md`。本表只能用於「技術路徑已跑通」的證據，不可作為正式 benchmark 結論。

### 06-19 YugabyteDB 重大除錯節點

- 確認防火牆不是 YugabyteDB 最終阻塞原因。
- GCP `advertise_address` 改用 IPv4，避免 hostname 優先解析成 IPv6 link-local 位址。
- 延長 YSQL catalog version backend wait timeout，處理跨區 catalog propagation 延遲。
- 使用 `modify_placement_info` 配置 IDC:GCP = 2:1，並以 `set_preferred_zones` 將 leader 優先放在 IDC。
- 修正後由 IDC-only fallback 進一步跑通真六節點；此成果是可行性驗證，不是正式吞吐結論。

### 06-21 Determinism 驗證結果

條件：同 cluster 重新部署 DB、W=4、16 threads、每次 5 分鐘。

| 資料庫 | Run 1 | Run 2 | 差異 |
|---|---:|---:|---:|
| TiDB | 1552.2 | 9719.2 | **+526%** |
| YugabyteDB | 41.8 | 23.0 | **-45%** |
| CockroachDB | 3929.6 | 2365.6 | **-40%** |

**已確認結論**：上述 W=4 結果不具重現性，不得納入正式跨家比較，也不得用來更新候選排序。

**目前待驗證假設**：變異可能同時受低 warehouse contention、重新部署後 placement / scheduler 狀態、暖機與背景調度影響。`SESSION-2026-06-21-determinism.md` 將主要原因判為 W=4 lock contention，但正式因果仍須由 06-22 的同 cluster、調度關閉與 CV 實驗確認。

### 06-22 Determinism v2 方向與完成條件

1. **同一 cluster 執行**：不在每輪間重部署或冷重置。
2. **測量前收斂**：placement gate 通過後才關閉 scheduler / balancer，並等待 in-flight operator 清空。
3. **正式暖機**：go-tpc 無 `--warmup` 參數，必須由外部流程實作；正式口徑仍為 20 分鐘。
4. **正式採樣**：5 rounds，排除 R1，以 R2～R5 中位數與 CV 判讀。
5. **正式 workload**：回到 W=128；W=4 僅能作 framework / contention probe。
6. **失敗回復**：任何階段失敗都必須依原始 dump 還原 TiDB PD、CockroachDB settings 與 YugabyteDB load balancer。
7. **放行條件**：調度關/開、round-only runner、暖機、placement gate、產物抓取與 CV report 全部通過審查，才能啟動正式基準。

### 新增引用來源

- `phase-crossregion/PRE-FLIGHT-TEST-PLAN-2026-06-17.md`
- `phase-crossregion/SESSION-2026-06-18-iac-verify.md`
- `1_MeetingMinutes/2026-06-18-fw-request-net.md`
- `phase-crossregion/SESSION-2026-06-19-3db-smoke.md`
- `phase-crossregion/SESSION-2026-06-21-determinism.md`
- `phase-crossregion/SESSION-2026-06-22-determinism-v2.md`（未提交／進行中，只能引用為工作方向）
- `1_MeetingMinutes/2026-06-22-milestone.md`

---

## 補充 D — 限制與風險（PDF 無對應，原 Slide 9 選頁）

> **本頁核心**：本份簡報的引用邊界與後續補強項

### 三類資訊區分

| 類型 | 範例 | 引用方式 |
|---|---|---|
| **已驗證事實** | 三家 VM / K8s tpmC 數字、p99 數字、error count | 可在會議中引用；**但不可作為唯一採購或導入決策依據** |
| **工程推論** | TiDB K8s 偶發 stall event 推測為 leader transition / NodePort iptables | 引用時需附「推論」字樣 |
| **待補數據** | N=3 重跑、YugabyteDB K8s 保留率成因、跨區域量測結果 | 引用前需說明數據尚未產出 |

### 主要 caveat

- **N=1 量測**：第一階段全部 cell 單次跑，流程-log 已標註「下一階段補 N=3」
- **YugabyteDB K8s 19% 保留率**：成因尚未定位，列為後續調校項；可能涉及 helm chart 預設、tablet 配置、raft 跨 pod 額外開銷等
- **採購 / 商業實體層面**：候選廠商之商業實體狀態、供應鏈與政策考量，需另案審查，**不在本份技術簡報範圍內**

---

## 補充 E — Appendix / 技術追溯入口（PDF 無對應，原 Slide 11 選頁）

> **本頁核心**：細節文件導引；主簡報不塞 path

### 文件導引

| 主題 | 引用 |
|---|---|
| 第一階段數據彙整 | `1_MeetingMinutes/analytics-S-K8S-2026-06-15.md` |
| 跨區域技術決策 | `phase-crossregion/decisions-2026-06-08.md`（10 道議題） |
| 分散式 DB 非技術議題 | `1_MeetingMinutes/2026-06-09-distributed-db-adoption-non-technical.md`（5 待決 + 4 拍板） |
| PoC 設計原則 | `results/PoC-DESIGN.md`（SSOT） |
| 結果索引 | `results/README.md` |
| chrony 跨區域 drift gate | `phase-crossregion/scripts/gate-chrony-cross-region.sh` |

### 預期問題與回應方向

| 預期問題 | 回應方向 |
|---|---|
| 為什麼 YugabyteDB K8s 退化這麼多？ | 成因尚未定位，列為後續調校項；不在第一階段結論範圍內 |
| 何時可以給出最終建議？ | 待跨區域量測完成 + application owner 五項議題共識 + 採購層面審查完成 |
| K8s 化值得做嗎？ | TiDB 與 CockroachDB 在 K8s 不限資源情境下保留率約 80% 以上、屬可接受；資源限制情境下吞吐砍半、p99 明顯惡化，須依應用情境權衡 |
| 是否需要等所有數據完整才能決策？ | 部分決策（如 application owner 議題確認、採購 / 商業實體審查）可平行進行，**不需等技術數據全齊才開始** |
