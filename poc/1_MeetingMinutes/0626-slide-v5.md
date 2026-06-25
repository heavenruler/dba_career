---
marp: true
theme: default
paginate: true
size: 16:9
header: 'PoC 第一階段成果與下一步決策'
footer: '2026-06-26 · DBA'
style: |
  section {
    background: #1e2538;
    color: #e8eaed;
    font-family: 'Noto Sans CJK TC', 'Microsoft JhengHei', 'PingFang TC', sans-serif;
    font-size: 22px;
    padding: 50px 70px;
  }
  section::before {
    content: '';
    display: block;
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 6px;
    background: #e74c3c;
  }
  h1 {
    color: #ffffff;
    font-size: 36px;
    margin-bottom: 8px;
  }
  h2 {
    color: #ffffff;
    font-size: 30px;
    border-bottom: 2px solid #e74c3c;
    padding-bottom: 6px;
    margin-bottom: 18px;
  }
  h3 {
    color: #f39c12;
    font-size: 24px;
    margin-top: 14px;
  }
  table {
    font-size: 18px;
    border-collapse: collapse;
    width: 100%;
    margin: 12px 0;
    background: #ffffff;
  }
  th {
    background: #d8dde6;
    color: #111418;
    font-weight: 700;
    padding: 8px 10px;
    border: 1px solid #8c95a3;
  }
  td {
    background: #ffffff;
    padding: 8px 10px;
    border: 1px solid #8c95a3;
    color: #111418;
  }
  tr:nth-child(even) td {
    background: #f1f3f6;
  }
  td strong { color: #b03a14; }
  blockquote {
    color: #a0a8b8;
    border-left: 3px solid #e74c3c;
    padding-left: 12px;
    margin: 8px 0;
    font-size: 18px;
    font-style: normal;
  }
  strong { color: #f39c12; }
  code {
    background: #0e1320;
    color: #f39c12;
    padding: 2px 5px;
    border-radius: 3px;
    font-size: 18px;
  }
  ul { font-size: 20px; line-height: 1.45; }
  li { margin: 3px 0; }
  header, footer {
    color: #6b7488;
    font-size: 14px;
  }
  section.title {
    text-align: center;
    padding: 140px 80px;
  }
  section.title h1 { font-size: 48px; }
  section.title p { color: #a0a8b8; font-size: 22px; }
---

<!-- _class: title -->

# 第一階段 PoC 成果與下一步決策

分散式資料庫架構 × 跨區域驗證 × 決策框架

2026-06-26 　|　 DBA

---

## Outline

- 專案迄今歷程
- 第一階段 PoC 測試數據彙整
- 第二階段 跨區域 / 跨專線執行進度
- 決策框架說明
- 後續推進

---

## 專案歷程 ① 研究定義到跨家框架

> 先定義問題與比較口徑，再建立可重複執行的基礎設施與三資料庫共同工具鏈

| 時間 | 階段 | 重大節點 | 狀態 |
|---|---|---|---|
| 2026-03-30〜04-10 | **前期研究** | 定義分散式 SQL、跨區同鍵寫入、follower read、HA/DR 與九項 survey 評估面向 | ✅ 完成 |
| 2026-04-21〜04-27 | **IaC 與第一版測試鏈** | 建立多測項部署、HAProxy、VM / Kubernetes 流程及獨立壓測 client<br>**{FIXME}** Chain 的 flow & Key Point | ✅ 完成 |
| 2026-04-28〜05-05 | **YugabyteDB 首輪除錯** | 處理 BenchmarkSQL、bulk load、RF / schema packing 與 HAProxy 問題 | ✅ 完成 |
| 2026-05-06〜05-14 | **三資料庫對標成形** | 納入 TiDB、CockroachDB、YugabyteDB，統一結果結構與 go-tpc 工具鏈 | ✅ 完成 |

> 此階段完成的是「可比較的工程框架」，早期測試數字不直接納入 v4.7 正式結果。

---

## 專案歷程 ② 基準、三節點與治理

> 將測試從可執行提升為可重現、可追溯、可拆解成本來源

| 時間 | 階段 | 重大節點 | 狀態 |
|---|---|---|---|
| 2026-05-18〜05-21 | **v4.7 baseline 重構** | 建立 PoC-DESIGN SSOT、detached suite、gate、marker、summary 與單節點三隔離級對標 | ✅ 完成 |
| 2026-05-22〜06-02 | **三節點 controlled experiment** | 完成 shard × replica × HAProxy 拓樸、12-cell dry-run 與三家 5-cell 結果 | ✅ N=1 完成 |
| 2026-05-20〜06-04 | **文件與數據治理** | 建立模板、AI 協作規範、artifact-first 審計與三家 pipeline-log 對齊 | ✅ 完成 |
| 2026-06-06〜06-07 | **Phase isolation** | 分離 S-BASE、S-K8S、T-THRD、X-CROSS，建立配置宣告、基礎指標確認及指標配置 | ✅ 完成 |

> 正式數字必須能追回測試條件、時間戳、結果檔案與完成標記；缺少來源資料 (測試階段) 時不予納入參考。

---

## 專案歷程 ③ Kubernetes 到跨區驗證

> 已完成 Kubernetes 對照與跨區技術路徑；正式跨區效能仍受實測結果約束

| 時間 | 階段 | 重大節點 | 狀態 |
|---|---|---|---|
| 2026-06-08〜06-14 | **Kubernetes v4.7** | 由單 cell dry-run 擴充至三資料庫 × limit/unlimit 六組正式 suite | ✅ 6/6 完成 |
| 2026-06-08〜06-17 | **跨區設計與前置開發** | 建立 GCP VM、六節點部署、placement、WAN、chaos、failover 與 pre-flight 規格 | 🟡 框架完成<br>部分僅 dry-run |
| 2026-06-18〜06-19 | **IDC↔GCP 實際驗證** | 修正 IaC、gate、防火牆與 YugabyteDB placement，三家完成真六節點前期測試 | ✅ smoke 完成 |
| 2026-06-21〜06-22 | **Determinism 收斂** | W=4 重跑浮動過大，改採同 cluster、freeze/unfreeze、變異量/變異參數 與 W=128 baseline | 🟡 進行中 |

> 決策界線：可確認六節點跨區交易路徑可行；正式跨家排序須等 W=128、R2〜R5 中位數 / 變異係數與回復流程驗收結論。

---

## 三家資料庫導入定位

| 資料庫 | 第一階段觀察 | 導入定位 |
|---|---|---|
| **TiDB** | VM 與 K8s 吞吐表現較佳；K8s retention 較高 | 方便優先進入應用情境對接 |
| **CockroachDB** | 一致性需求較強（SSI 預設）；SI / SSI 模式下 retry 與效能成本明顯 | **保留觀察**：應用層需評估 Error Handling 容忍度與交易模式 |
| **YugabyteDB** | VM + HAProxy 表現為佳；K8s 結果目前不宜直接作為導入結論 | **保留觀察**：K8s 部署仍需調校與驗證，VM 路徑可進入評估 |

### 同 IDC / 同硬體 基準 — vm-3node-haproxy-3s3r-rc, t=128 mean tpmC

> **{FIXME}** 測試架構圖補完 ; db component intro ; 各節點較重損耗

| TiDB | YugabyteDB | CockroachDB |
|:-:|:-:|:-:|
| **≈ 26,900** | **≈ 15,600** | **≈ 15,000** |

> 本組數字為 controlled experiment 基準（VM 現況資源 × 3 node 拓樸）；不直接代表各家「拿出來就跑」的生產表現；不具任何採購驗收指標用。<br>商業實體 / 授權 / 採購層面議題需另案審查。

---

## VM 與 Kubernetes 效能差異

> K8s 化對 TiDB 與 CockroachDB 屬可接受範圍；YugabyteDB 在 K8s 下退化顯著，列為調校與驗證項

| 資料庫 | S-BASE (VM) tpmC | S-K8S unlimit tpmC | S-K8S limit tpmC | unlimit / VM | limit / VM | p99 unlimit Δ | p99 limit Δ |
|---|---:|---:|---:|---:|---:|---:|---:|
| TiDB v8.5.2 | 26,947 | 23,442.9 | 15,751.9 | **87.0 %** | 58.5 % | +17 % | +111 % |
| CockroachDB v26.2 | 15,033 | 12,196.7 | 6,493.5 | **81.1 %** | 43.2 % | +27 % | +192 % |
| YugabyteDB 2025.2 | 15,632 | 2,997.6 | 1,604.5 | **19.2 %** ⚠ | 10.3 % ⚠ | +669 % | +1556 % |

### 觀察解讀

- TiDB / CockroachDB：K8s unlimit 保留率 81-87 %，屬可接受範圍；limit 情境大幅衰退反映資源壓縮
- YugabyteDB：K8s unlimit 僅 19.2 %、p99 +669 %。成因推論：YSQL + DocDB 雙 process 在 K8s pod IPC + CPU contention 放大。**成因未定位，列後續調校項**
- S-BASE ↔ S-K8S 可直接比較（同 workload W=128 t=128）

---

## 跨區域 / 跨專線進度

> **{FIXME}** 架構圖示說明解釋 P-A/P-B placement

### ✅ 已完成

- 技術議題定案（GCP 5 VM 拓樸、placement P-A/P-B、Chaos Engineering 等）
- IaC、playbook、suite scripts、chrony drift gate（drift_median 0.017 ms；時間偏移 between IDC & GCP）
- 06-18〜06-19：修正 IaC / 防火牆 / YugabyteDB placement，三家 DB / 六節點前期測試驗證
- 06-21〜06-22：Determinism v2 — 同 cluster R1-R5、scheduler / balancer freeze

### 🟡 待執行

- 調度 scheduler (開/關)、round-only runner、Warmup、Placement (replica / lease 位置)、測試結果彙整
- 回到 W=128 正式基準量測
- Failover 與 Chaos Engineering 實際驗證

---

## X-CROSS 初步結果 (06-22〜06-23)

> W=4 framework 驗證；不與 S-BASE/S-K8S 直接對比 · 同 cluster 5 rounds、W=4、16 threads、每 round 5 min、controller = .31 (IDC client)

| 資料庫 | R1 | R2 | R3 | R4 | R5 | 中位數 (有效輪) | CV |
|---|---:|---:|---:|---:|---:|---:|---:|
| TiDB v8.5.2 | 9,525.5 | 9,553.2 | 9,786.9 | 9,393.2 | 9,530.8 | **9,566.0** (R2-R5) | **1.67 %** ✅ |
| CockroachDB v26.2 | 8,409.5 | 8,055.3 | 7,902.5 | 7,720.9 | 7,472.3 | **7,787.8** (R2-R5) | **3.23 %** ✅ |
| YugabyteDB 2025.2 | 102.0 | 226.9 | 6,424.2 | 6,259.3 | 6,206.2 | **6,296.6** (R3-R5) | **1.82 %** ✅ |

### 已確認結論

- 06-21 觀察到的 ±526 % / ±50 % 變異主因為「每輪重新部署」造成 placement / cache / scheduler 狀態異動，與 W=4 contention 為兩個獨立來源
- 同一 cluster 連跑時，三家 W=4 R2-R5（或 YBDB R3-R5）的 CV ≤ 5 %，重現性已建立
- YBDB Idle=0 解法：gate 改用 `get_load_move_completion=100%`；timed run 前 `set_load_balancer_enabled=0`
- CRDB lease gate SQL 改用 `SHOW RANGES FROM DATABASE tpcc WITH TABLES, DETAILS`（v26.2 相容）

> ⚠ Caveat：W=4 framework / contention 驗證 ≠ 正式基準；R2-R5（YBDB R3-R5）CV ≤ 5 % 已建立但**不可作跨家排名**；後續需回 W=128。

---

## 建議決策框架

> 不是選一家，是先界定 application 條件、再排序候選；僅提供做決策框架參考依據用

| 分類 | 內容 | 處置 |
|---|---|---|
| **短期候選** | TiDB | 優先進入應用情境對接，無門檻 |
| **保留觀察** | CockroachDB | 依一致性需求、Error Handling 容忍度、維運成本評估 |
| **保留觀察** | YugabyteDB | VM 路徑可評估；K8s 路徑需先完成部署層級調校與驗證 |
| **暫不作結論** | 跨區域場景、K8s 退化未定位項 | 待下一階段 W=128 測試數據與調校產出再回頭評估 |

### Application 需要確認的議題

1. **交易一致性需求**：是否需要 SERIALIZABLE / SSI？是否可接受 READ COMMITTED & 產品設計架構轉 CAP 的複雜度及可行性？
2. **可接受延遲**：在尖峰 t=128 等級負載下，p99 是否需要 500ms / 1s / 2s 以內？
3. **retry / timeout 行為**：應用層是否能接受 SI / SSI 模式下的 retry 機制？
4. **RTO / RPO**：跨區域 failover 是否需要 < 30s RTO？是否容許資料 lag？
5. **連線層 / 交易模式調整**：是否能配合 HAProxy / PgBouncer / 連線池與短交易模式？

---

## 後續推進階段

| 短期 EX: Y26/07 | 中期 | 決策 |
|---|---|---|
| **{FIXME}** 補完完整測試時間描述 | A-S / A-A-RO / A-A 三個 workload profile × P-A/P-B placement × 三家資料庫，依檢驗指標分批 / 量測 | Application owner 完成五項議題確認 |
| W=4 框架已驗，接 W=128 基準 | Failover 與 Chaos Engineering 測試 | 原廠後勤對接狀況說明 |
| freeze/unfreeze、round-only runner、暖機、placement gate 全部通過 審查 | 跨區域 analytics 第二份報告 | |
| X-CROSS 完成 determinism 流程 驗收，啟動正式 W=128 基準 量測 | 補齊 YugabyteDB K8s 退化成因調查（P-A/P-B、A-S/A-A-RO/A-A） | |
