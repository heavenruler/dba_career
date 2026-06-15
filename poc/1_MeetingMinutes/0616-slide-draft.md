# 第一階段 PoC 成果與下一步決策

> 受眾：C-level / 跨部門主管 / 業務 / application owner
> 頁數：5-8 頁（含選頁）
> 定位：第一階段成果與決策框架；本份**不是**工程細節報告
> 引用：`1_MeetingMinutes/analytics-S-K8S-2026-06-15.md` / `phase-crossregion/decisions-2026-06-08.md` / `1_MeetingMinutes/2026-06-09-distributed-db-adoption-non-technical.md` / `results/PoC-DESIGN.md` / `results/README.md`

---

## Slide 1 — 第一階段成果與下一步決策

> **本頁核心**：第一階段已給出技術證據，下一步需要 application owner 與管理層共同界定導入場景

### 進度地圖

| Phase | 範圍 | 狀態 |
|---|---|---|
| **S-BASE**（VM baseline） | TiDB / CockroachDB / YugabyteDB × 指定 isolation × 指定拓撲 | ✅ 已完成主要驗證 |
| **T-THRD**（thread control） | thread sweep 行為對標 | ✅ 已完成主要驗證 |
| **S-K8S**（K8s 對照） | 三家 × {unlimit, limit} = 6 cell | ✅ 已完成主要驗證 |
| **X-CROSS**（跨區域 / 跨專線） | 6-node TiDB cluster + GCP 跨區、placement、failover、chaos | 🟡 框架與規劃已建立；sweep 數據待執行 |

### 三點結論

1. **已完成什麼**
   - 三家資料庫於同一 4 vCPU 硬體 + W=128 TPCC 工作負載下完成 baseline 對標
   - VM 與 Kubernetes 部署平面差異已實測量化
   - 跨區域測試框架（IaC / playbook / suite scripts / chrony drift gate）已就位

2. **已觀察到什麼**
   - TiDB 與 CockroachDB 在 K8s 部署下吞吐 retention 約八成
   - YugabyteDB 在 K8s 部署下吞吐明顯退化，**成因尚未定位，列為後續調校項**
   - 全程 N=1 量測；正式採購或導入決策前**需補 N=3 重跑**（已列入下一階段）

3. **下一步需要誰決策**
   - **application owner**：交易一致性需求、可接受延遲、retry / timeout 行為、RTO / RPO
   - **管理層**：候選 vendor 是否含特定授權或商業實體限制、預算編列窗口（Q4 對齊）
   - **DBA / 維運**：依上述決策選擇導入路徑（VM 或 K8s、是否啟跨區）

---

## Slide 2 — 三家資料庫導入定位

> **本頁核心**：三家有不同的導入定位，不適合用「誰最快」單一排序判讀

### 導入定位

| 資料庫 | 第一階段觀察 | 適合的導入定位 |
|---|---|---|
| **TiDB** | VM 與 K8s 吞吐表現較佳；K8s retention 較高 | **短期優先候選**之一，可優先進入應用情境對接 |
| **CockroachDB** | 一致性語意較強（SSI 預設）；但 SI / SSI 模式下 retry 與效能成本明顯 | **保留觀察**：應用層需評估 retry 容忍度與交易模式 |
| **YugabyteDB** | VM + HAProxy 表現可觀；K8s 結果**目前不宜直接作為導入結論** | **保留觀察**：K8s 部署仍需調校與驗證，VM 路徑可進入評估 |

### 同硬體 baseline 數字（vm-3node-haproxy-3s3r-rc，t=128 mean tpmC）

```
TiDB           ≈ 26,900
YugabyteDB     ≈ 15,600
CockroachDB    ≈ 15,000
```

> 註：本組數字為 controlled experiment baseline（vm-3node 拓撲全部鎖定 sharding / replication 參數），目的是觀察拆解後的純效應，**不直接代表各家「拿出來就跑」的生產表現**（見 `results/PoC-DESIGN.md` §6）。

### 三家架構差異速覽

| | TiDB | CockroachDB | YugabyteDB |
|---|---|---|---|
| 部署形態 | TiDB compute + TiKV storage + PD（多 process） | single-binary | YSQL + DocDB（雙 process） |
| 原生強一致 | 不支援原生 SERIALIZABLE | SSI 預設 | SSI |
| 1-node TPCC 行為 | 已對標（baseline 用） | 已對標（baseline 用） | 已對標（baseline 用） |
| 3-node scale-out 行為 | 觀察值最高 | 觀察值中等 | 觀察值中等 |

> 商業實體 / 授權 / 採購層面議題請見 Slide 5 / Slide 6 風險頁。

---

## Slide 3 — VM 與 Kubernetes 效能差異

> **本頁核心**：K8s 化對 TiDB 與 CockroachDB 屬可接受範圍；YugabyteDB 在 K8s 下退化顯著、列為調校與驗證項

### t=128 mean tpmC（K8s 不設資源限制 vs VM baseline）

| 資料庫 | VM baseline | K8s（不限資源） | K8s retention | K8s（資源限制情境）retention |
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

## Slide 4 — 跨區域 / 跨專線進度

> **本頁核心**：框架與規劃已建立；dry-run blocker 修正後才能進入 sweep

### Done — 已完成

- 10 道技術 Q&A 拍板（GCP 5 VM 拓撲、9 cell-track 範圍、placement P-A/P-B、chaos C1/C4/C7、A-A 全 W=128 等）
- 14 道非技術 Q&A 拍板（採購、預算、授權、stakeholder 對齊、商業實體 review）
- IaC（GCP 5 VM Terraform）、ansible playbook、suite scripts、chrony drift gate（10-host 升級版，drift_median 0.017 ms）
- IDC 端機器盤點與 K8s 殘留清理
- GCP 5 VM 已驗證可建可連，已 destroy 釋出（節費）

### Pending — 待執行

- 修正 ansible inventory / playbook hostname mapping（B1，10 分鐘）與 IDC HAProxy IP（B2，5 分鐘）兩處 blocker
- terraform apply 重建 GCP 5 VM（28 秒）
- 完成 cross-region dry-run 驗證
- 進入 sweep 實跑

### Sweep 時間估計

- **量級**：約 150 小時 sweep 執行時間（360 rounds × 平均 25 分鐘）
- **連續執行**：約 6.25 天 wall-clock
- **實務上排程**：約 19 個工作天，**會分批執行並設置 review gate**（避免一次性 6 天連續佔用 IDC 端機器）
- **計費**：GCP 5 VM 連續開機約 USD 590 / 月，sweep 期間約 USD 40 自然發生

### Risk — 風險

- sweep 期間 IDC 端機器負載連續（建議避開其他維護）
- 部分 K8s cap 情境下 TPCC client 可能 hang（已於第一階段 Cell 6 YugabyteDB-limit T128 觀察到 deterministic 行為，跨區域階段拓撲不同，**列為觀察項**）
- 跨區域網路 drift 異常需 fail-closed gate（已實作於 chrony 10-host 版）

---

## Slide 5 — 建議決策框架

> **本頁核心**：不是選一家，是先界定 application 條件、再排序候選；本份簡報提供框架不替代決策

### 三層候選分類

| 分類 | 內容 | 處置 |
|---|---|---|
| **短期候選** | TiDB | 優先進入應用情境對接 |
| **保留觀察** | CockroachDB | 依一致性需求、retry 容忍度、授權 / BSL 政策、維運成本評估 |
| **保留觀察** | YugabyteDB | VM 路徑可評估；K8s 路徑需先完成部署層級調校與驗證 |
| **暫不作結論** | 跨區域場景、K8s 退化未定位項 | 等下一階段 sweep 與調校產出再回頭評估 |

### Application owner 需要確認的議題

1. **交易一致性需求**：是否需要 SERIALIZABLE / SSI？是否可接受 READ COMMITTED？
2. **可接受延遲**：在尖峰 t=128 等級負載下，p99 是否需要 500ms / 1s / 2s 以內？
3. **retry / timeout 行為**：應用層是否能接受 SI / SSI 模式下的 retry 機制？timeout 預期值？
4. **RTO / RPO**：跨區域 failover 是否需要 < 30s RTO？是否容許資料 lag？
5. **連線層 / 交易模式調整**：是否能配合 HAProxy / pgbouncer / 連線池與短交易模式調整？

> 上述五項取得共識前，建議**不直接拍板採購單一資料庫**。

---

## Slide 6（選）— 限制與風險

> **本頁核心**：本份簡報的引用邊界與後續補強項

### 三類資訊區分

| 類型 | 範例 | 引用方式 |
|---|---|---|
| **已驗證事實** | 三家 VM / K8s tpmC 數字、p99 數字、error count | 可在會議中引用；**但不可作為唯一採購或導入決策依據** |
| **工程推論** | TiDB K8s 偶發 stall event 推測為 leader transition / NodePort iptables | 引用時需附「推論」字樣 |
| **待補數據** | N=3 重跑、YugabyteDB K8s retention 成因、跨區域 sweep 結果 | 引用前需說明數據尚未產出 |

### 主要 caveat

- **N=1 量測**：第一階段全部 cell 單次跑，pipeline-log 已標註「下一階段補 N=3」
- **YugabyteDB K8s 19% retention**：成因尚未定位，列為後續調校項；可能涉及 helm chart 預設、tablet 配置、raft 跨 pod 開銷等
- **採購 / 商業實體層面**：候選 vendor 之授權模式（OSS / BSL / Enterprise）、商業實體狀態、供應鏈 / 政策考量，需另案 review，**不在本份技術簡報範圍內**

---

## Slide 7（選）— 後續推進階段

> **本頁核心**：分三階段推進，不是 task list

### 短期（修正 blocker、完成 cross-region dry-run）

- 修補 ansible inventory / playbook 兩處 blocker
- terraform apply 重建 GCP 5 VM
- 跑通 cross-region dry-run

### 中期（完成跨區域 sweep、failover、chaos）

- A-S / A-A-RO / A-A 三個 workload profile × P-A / P-B placement × 三家資料庫，依 review gate 分批 sweep
- failover 與 chaos（C1 / C4 / C7）driven 測試
- 跨區域 analytics 第二份報告

### 決策（與 application 共同定義導入候選場景）

- application owner 完成 Slide 5 五項議題確認
- 採購 / 商業實體層面 review 完成
- 選定一個或多個短期候選進入導入規劃

---

## Slide 8（選）— Appendix / 技術追溯入口

> **本頁核心**：細節文件導引；主簡報不塞 path

### 文件導引

| 主題 | 引用 |
|---|---|
| 第一階段數據彙整 | `1_MeetingMinutes/analytics-S-K8S-2026-06-15.md` |
| 跨區域技術決策 | `phase-crossregion/decisions-2026-06-08.md`（10 道 Q&A） |
| 跨區域非技術決策 | `1_MeetingMinutes/2026-06-09-distributed-db-adoption-non-technical.md`（14 道 Q&A） |
| PoC 設計原則 | `results/PoC-DESIGN.md`（SSOT） |
| 結果索引 | `results/README.md` |
| chrony 跨區域 drift gate | `phase-crossregion/scripts/gate-chrony-cross-region.sh` |

### 預期問題與回應方向

| 預期問題 | 回應方向 |
|---|---|
| 為什麼 YugabyteDB K8s 退化這麼多？ | 成因尚未定位，列為後續調校項；不在第一階段結論範圍內 |
| 何時可以給出最終建議？ | 待跨區域 sweep 完成 + application owner 五項議題共識 + 採購層面 review 完成 |
| K8s 化值得做嗎？ | TiDB 與 CockroachDB 在 K8s 不限資源情境下 retention 約 80% 以上、屬可接受；資源限制情境下吞吐砍半、p99 明顯惡化，須依應用情境權衡 |
| 是否需要等所有數據完整才能決策？ | 部分決策（如 application owner 議題確認、採購 / 商業實體 review）可平行進行，**不需等技術數據全齊才開始** |
