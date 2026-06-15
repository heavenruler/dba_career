# TiDB × 104 科技 會議記錄摘節 — 2026-06-11

> 原始 PDF：`0611-TiDBx104會議記錄.pdf`（Feishu Docs / Andy Hsu）
> 雙方：PingCAP × 104 人力銀行
> 主題：TiDB 分散式資料庫技術評估與合作模式討論
> 用途：採購 / 導入決策事實基線；交叉確認 0616.md §4「TiDB 原廠後勤已確認事項」

---

## 1. 已對焦項目（PingCAP 端已說明）

### 1.1 技術支援

| 項目 | 內容 |
|---|---|
| 支援模式 | 24×7 中文技術支援；線上工單系統；配備技術顧問（TAM）即時協助（依訂閱方案提供，已提供材料） |
| SLA 響應 | Premier S1（生產影響）30 分鐘；Enterprise 1 小時；實際響應通常十幾分鐘內 |
| 駐點 | 以遠端線上會議為主；特殊情況可安排現場支援；中文團隊成員多為大陸籍，需申請商務簽證 |

### 1.2 台灣本地資源

| 項目 | 內容 |
|---|---|
| 商務 / 合約 | 透過總代理商（麥塔等）處理發票與合約 |
| 在地工程支援 | 7 月將有台灣本地 SA 到職 |

### 1.3 專業服務（按人天計費）

| 項目 | 內容 |
|---|---|
| 計費 | US$ 2,000 / 人天 |
| 服務六大類 | 架構設計 / 資料遷移 / 效能調優 / 巡檢保障 / 客製化培訓 / 人員外包 |

### 1.4 TiDB Cloud 訂閱層級

| 層級 | 規格 / 計費 |
|---|---|
| Starter | 前 5 個資料庫免費；5 GB 資料量上限；按 RU（請求單位）計費；小規模試用 |
| Essential | GB ~ TB；按用量計費；雙層加密等安全功能 |
| Premium | TB ~ PB；4 個九可靠性；BYOK（客戶自有加密金鑰）；可選按量或固定資源 |
| Dedicated | 預置資源方案 |

### 1.5 多地多中心架構

| 項目 | 內容 |
|---|---|
| 副本間延遲建議 | 約 10 ms |
| 跨雲連線 | VPC Peering 與 Private Link（延遲無差異，僅 IP 衝突處理不同） |
| 容災 / Failover | Raft 多數派；專線完全中斷時自動 failover 至健康副本，停機 30 秒內；演算法原理上避免腦裂 |
| 抖動敏感度 | 80–100 ms 抖動可能導致事務 commit 時間變長或觸發路由至更健康副本 |

### 1.6 資料遷移服務流程

1. **環境準備**：打通 VPC 連線；跨雲 / 跨地專線延遲符合 HA 要求
2. **功能驗證**：客戶測試環境或原廠標準清單（加密解密、備份恢復、Online DDL 等）
3. **效能測試**：支援客戶壓測程式或標準 Benchmark（SysBench 等）
4. **遷移演練**：Data Migration（DM）工具完成全量 + 增量同步；演練切換與回滾
5. **輸出報告**：架構建議、驗證結果、風險評估

### 1.7 相容性

| 來源 | 結論 |
|---|---|
| MySQL 5.7 / 8.0 / 8.4 | 相容主流版本；但非基於 MySQL 內核開發，獨立實現並相容語法與功能 |
| MariaDB | 需線下評估（10.4 / 10.11） |
| PostgreSQL / MongoDB | 可遷移；需人工介入評估與改造，**無法無感遷移** |
| AI 場景 | 支援向量搜索（HNSW 索引）/ RAG / 圖搜索 / BM25；與 MiniMax 等品牌合作 |

---

## 2. PoC 測試現況（104 端）

| 時點 | 範圍 |
|---|---|
| 2025 重點 | 完成與既有 RDS 服務的效能比對；將重要服務資料遷移至 TiDB 進行產品端導流測試 |
| 2026 Q3（9 月） | 完成跨專線多地多中心架構測試報告 |
| 2026 Q4 | 評估明年預算與試行範圍（初期投入約 5-10% 產品流量） |

### 2.1 PoC 測試發現

- **同 VM 規格（4 vCPU / 16 GB / 100 GB）下，TiDB 在 Serializable 隔離級別的 TPC-C 效能優於 Read Committed**
- 此現象待原廠進一步分析驗證
- **內部交叉確認**：本 PoC `results/PoC-DESIGN.md` §5.4 與 `analytics-S-K8S-2026-06-15.md` §1 caveat 註記「TiDB 不支援原生 SERIALIZABLE，設 `tidb_skip_isolation_level_check` 後仍以 REPEATABLE-READ 行為執行」。會議所述 Serializable 數字實際對應 TiDB REPEATABLE READ（pessimistic mode）；本 PoC 命名為 `vm-1node-rr` 而非 `vm-1node-strict`，TiDB strict 列已標 N/A
- 此認知差異建議在下次原廠對焦會中與 PingCAP 確認術語對齊，避免後續報告引用混淆

---

## 3. 待 PingCAP 補充事項（PingCAP 端 follow-up）

| # | 項目 | 狀態 |
|---|---|---|
| 1 | Self-Managed 支援方案（地端自建部署的訂閱服務細節與計費模式） | 會後補充 |
| 2 | Serializable 效能異常分析（per §2.1，可能涉及術語對齊） | 進一步分析驗證 |
| 3 | MariaDB 10.4 / 10.11 相容性細節 | 線下評估 |

---

## 4. 行動項目（雙方）

| Owner | 項目 |
|---|---|
| Andy Hsu（PingCAP） | 準備商業層級簡報與技術文件，供 104 管理層與 CTO/CIO 溝通使用 |
| PingCAP 技術團隊 | 提供 MySQL 相容性清單、AI 應用案例、Self-Managed 訂閱方案細節 |
| 104 團隊 | Q3（9 月）完成跨專線多中心測試報告；Q4 評估明年預算與試行範圍（初期 5-10% 產品流量） |

---

## 5. 成功案例參考（PingCAP 提供）

| 客戶 | 痛點 / 結果 |
|---|---|
| **韓國三星** | 地端部署遭遇 Data Center 完全下線故障；TiDB 僅短暫波動無不可用情況；促使三星大規模遷移至 TiDB |
| **LINE / 日本最大支付平台 / 美國打車軟體 / 中國知乎** | 解決單集群 PB 級資料擴展、頻繁 DDL 變更不鎖表、跨雲容災等痛點 |

---

## 6. 下一步（雙方共識）

- 定期同步 104 PoC 測試進展，提供技術支援與文件資源
- 準備管理層溝通材料，必要時安排亞太區銷售負責人進行現場簡報
- Q4 依測試結果討論 2026-27 年預算規劃與試行產品範圍

---

## 7. 與 PoC 內部資料的交叉確認

| 議題 | 會議內容 | PoC 內部對照 | 結論 |
|---|---|---|---|
| 副本間延遲建議 ~10 ms | PingCAP 建議多地多中心副本間延遲 10 ms | `phase-crossregion/scripts/gate-chrony-cross-region.sh` drift threshold 100 ms（per Q10 fail-closed）；IDC↔GCP 實測 drift_median 0.017 ms / drift_worst 0.071 ms | PoC chrony gate 設計符合 PingCAP 建議邊界（threshold 100 ms 寬於 10 ms 建議值，且實測值遠低於兩者） |
| Failover 30 秒內 | Raft 多數派、自動 failover、30 秒內停機 | 跨區域 sweep 中含 F1 failover 測試（per decisions Q3 範圍）；尚未實測 RTO 數字 | F1 測試實跑後可回饋驗證 |
| 跨專線抖動 80-100 ms 影響 commit 時間 | 80-100 ms drift 可能拉長交易提交 | 本 PoC chrony fail-closed threshold 100 ms 與此匹配 | 一致 |
| Serializable 隔離效能異常 | PingCAP：TiDB Serializable > Read Committed 待分析 | 本 PoC：TiDB 無原生 SERIALIZABLE，rr 為其最強隔離 | 建議下次對焦會澄清術語 |
| 跨雲 VPC Peering / Private Link 延遲無差異 | PingCAP 確認 | 本 PoC 走 GCP IAP tunnel（per Q1）非 VPC Peering | 不影響第一階段測試；正式導入時需 review |
| Self-Managed 訂閱方案 | 會後補充 | 104 PoC 採地端自建（IDC + GCP cross-region），需此資訊評估採購 | 等 PingCAP 補充 |

---

## 8. 引用

- 原始 PDF：[`0611-TiDBx104會議記錄.pdf`](./0611-TiDBx104會議記錄.pdf)
- 採購 / 商業 review 出處：[`2026-06-09-distributed-db-adoption-non-technical.md`](./2026-06-09-distributed-db-adoption-non-technical.md) §Q2 / §Q4 / §Q14
- TiDB 隔離級別命名差異出處：[`../results/PoC-DESIGN.md`](../results/PoC-DESIGN.md) §5.4 + [`analytics-S-K8S-2026-06-15.md`](./analytics-S-K8S-2026-06-15.md) §1 caveat
- 0616 會議 §4 已對焦項目交叉引用：[`0616.md`](./0616.md) §4
