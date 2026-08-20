---
marp: true
theme: default
paginate: true
size: 16:9
header: '分散式資料庫 PoC：階段性結論與第二階段決策'
footer: '2026-08-21'
style: |
  section {
    font-family: 'Noto Sans CJK TC', 'Microsoft JhengHei', sans-serif;
    font-size: 21px;
    color: #22303f;
  }
  h1 { font-size: 32px; color: #1a2b3c; }
  h2 { font-size: 26px; color: #1a2b3c; }
  table { font-size: 18px; }
  strong { color: #c0392b; }
  section.lead h1 { font-size: 40px; }
---

<!-- _class: lead -->

# 分散式資料庫 PoC：階段性結論與第二階段決策

2026-08-21

---

# 導覽｜本次簡報六個段落

| 段落 | 這一段回答什麼 |
|---|---|
| **背景** | PoC 從 4 月到 8 月建立了哪些可追溯的證據 |
| **證據** | 評分規則、證據等級，以及兩條相容路線的逐項評分明細 |
| **主張** | 為何建議下一階段聚焦 MySQL 相容路線、由 TiDB 先行 |
| **比較** | 原廠技術支援與版本生命週期這個導入前提 |
| **建議** | 技術面與產品面各自要驗證什麼、如何對齊 |
| **決策** | 可執行選項、投資報酬判準與本次需要確認的事項 |

> 後續每頁標題皆以所屬段落開頭；附錄集中放證據入口、官方來源與判讀限制。

---

# 背景｜從 4 月建立框架，到 8 月形成可推進的候選方向

| 時間 | 主要里程碑 | 成果 |
|---|---|---|
| 4 月 | [範圍與測試環境建立](https://github.com/heavenruler/dba_career/blob/master/poc/MILESTONES.md#專案時程) | 確定評估面向，建好可重現的測試環境 |
| 5 月 | [共同基準完成](https://github.com/heavenruler/dba_career/blob/master/poc/MILESTONES.md#2-單節點三隔離級基準) | 三家改用同一套壓測條件，結果可互相對照 |
| 6 月 | [多節點與跨機房框架](https://github.com/heavenruler/dba_career/blob/master/poc/MILESTONES.md#專案時程) | 完成多節點、容器化部署與跨機房前置驗證 |
| 7 月 | [跨機房工作負載](https://github.com/heavenruler/dba_career/blob/master/poc/phase-crossregion/XCROSS-PA-VS-PB-FINAL-COMPARISON.md) | 完成跨機房各種讀寫情境，並修正量測有效性 |
| 8 月 | [故障演練與評分](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING-INTRO.md) | 完成故障切換實測，補上 MySQL 對照，形成兩條路線評估 |

> 里程碑的共同成果：把「產品功能宣稱」轉成可追溯的設定、量測、故障與限制證據。

---

# 證據｜評分規則與證據等級

**評分規則**

- 星等只在**同一相容群組內**依實測數值相對排序，最佳＝⭐⭐⭐⭐⭐
- MySQL 與 PostgreSQL 群組的星等與分數不互相比較

**證據等級**

- ✅ PoC 實測：go-tpc TPC-C-derived stress workload 的可追溯結果
- 📄 官方文件：只佐證產品設計、版本或支援能力，不計入實測分數
- ⏳ 待驗證：尚未完成公司情境下的實跑

**Failover 欄位一律只列實測秒數**：MySQL 群組兩家的故障注入與恢復流程不等價，不宜換算星等；PostgreSQL 群組雖為同一方法論，仍以秒數直接呈現，避免與其他項目的相對星等混淆。

---

# 證據｜MySQL 相容群組評分明細

| # | 項目 | 權重 | TiDB | PXC／Galera | 證據 | SSOT |
|---|---|---:|:---:|:---:|:---:|:---:|
| 1 | MySQL 協定相容性 | 20% | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ | 📄 | [§3.1](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#31-mysqlpostgresql-相容性) |
| 2 | 單節點／低併發延遲 | 19% | ⭐☆☆☆☆ | ⭐⭐⭐⭐⭐ | ✅ | [§3.2.1](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#321-單節點低併發延遲vm-1node-rc) |
| 3 | 水平擴展能力 | 24% | ⭐⭐⭐⭐⭐ | ⭐☆☆☆☆ | ✅ | [§3.2.2](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#322-水平擴展能力vm-1node--vm-3node-haproxy-3s3r) |
| 4 | 高併發穩定性 | 19% | ⭐⭐⭐⭐⭐ | ⭐☆☆☆☆ | ✅ | [§3.2.3](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#323-高併發穩定性t1285-round-rangemean-與-error-rate) |
| 5 | Failover 恢復（重啟→首次寫入） | 5% | 39.1–44.3s | 8.240s | ✅ | [§3.3.1a](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#331a-mysql-相容群組galerapxc-84chaosfailover-實測2026-08-13) |
| 6 | PITR／備份還原 | 3% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ | 📄 | [§3.3.2](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#332-pitr備份還原) |
| 7 | Online DDL 與維運工具 | 5% | ⭐⭐⭐⭐⭐ | ⭐⭐☆☆☆ | 📄 | [§3.4](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#34-online-ddl-與維運工具) |
| 8 | HTAP／TiFlash | 5% | 待測 | n/a | ⏳ | [§3.5](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#35-tidb-htaptiflash-與-yugabytedbcockroachdb-geo-distribution) |

---

# 證據｜PostgreSQL 相容群組評分明細

| # | 項目 | 權重 | YugabyteDB | CockroachDB | 證據 | SSOT |
|---|---|---:|:---:|:---:|:---:|:---:|
| 1 | PostgreSQL 協定相容性 | 10% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐☆☆ | 📄 | [§3.1](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#31-mysqlpostgresql-相容性) |
| 2 | 單節點／低併發延遲 | 24% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐☆☆ | ✅ | [§3.2.1](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#321-單節點低併發延遲vm-1node-rc) |
| 3 | 水平擴展能力 | 29% | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ | ✅ | [§3.2.2](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#322-水平擴展能力vm-1node--vm-3node-haproxy-3s3r) |
| 4 | 高併發穩定性 | 24% | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ | ✅ | [§3.2.3](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#323-高併發穩定性t1285-round-rangemean-與-error-rate) |
| 5 | Failover 恢復（重啟→首次寫入） | 5% | 2.99–3.65s | 7.01–7.12s | ✅ | [§3.3.1](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#331-failover-rtorpo--2026-08-11-真實重跑完成) |
| 6 | PITR／備份還原 | 3% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ | 📄 | [§3.3.2](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#332-pitr備份還原) |
| 7 | Online DDL 與維運工具 | 5% | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ | 📄 | [§3.4](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md#34-online-ddl-與維運工具) |

---

# 主張｜先選協定路線：兩條路線回答的是不同遷移問題

| 面向 | MySQL 相容路線 | PostgreSQL 相容路線 | 對決策的影響 |
|---|---|---|---|
| 候選順序 | **TiDB**、PXC／Galera | YugabyteDB、CockroachDB | 只在同一群組內比較 |
| 現行規模 | **28 個叢集、商務邏輯約 95%** | 4 個叢集、商務邏輯約 5% | **MySQL 路線可先形成較大覆蓋** |
| 應用變更 | 仍須驗 MySQL 語法差異，但協定遷移較小 | MySQL 應用需改 SQL／ORM／Driver／交易行為 | **相容性是導入門檻，不是普通效能分數** |
| 架構差異 | TiDB 為計算／儲存分離；PXC 為完整副本與 writeset certification | 兩家皆為 PostgreSQL wire protocol，但 SQL 引擎與相容程度不同 | 同名功能不能直接視為同一機制 |
| TSD 應用觀察 | 應用數較多、關鍵度需另盤點 | 部分頭部／AI 應用使用 | 「數量」與「業務關鍵度」必須分開 |

> 現況統計日期 2026/08/14；來源為 Prod 監控彙整。

---

# 主張｜所以下一階段聚焦 MySQL 相容，由 TiDB 先行

**建議下一階段聚焦 MySQL 相容路線，由 TiDB 先做快速驗證，再導入代表性應用 Pilot。**

| 支撐理由 | 階段性判讀 |
|---|---|
| 業務適配 | 現行商務邏輯約 95% 使用 MySQL 路線，可先降低協定遷移與應用改造範圍 |
| 技術方向 | TiDB 在本 PoC 的水平擴展與高併發穩定性較有利；PXC／Galera 保留原生相容與低延遲對照 |
| TSD 回饋 | 目前重視一致性、服務恢復速度、故障範圍隔離及 Database Self-Service，未要求直接推進跨區 A/A |


> 這是下一階段的驗證與推進順序；正式擴大導入由 Pilot 驗收結果決定。

---

# 比較｜原廠技術支援是 Promotion 門檻，不是效能加分

| 產品 | 官方可追溯的支援入口 | PoC 版本維護狀態 | Pilot 前需向原廠確認 |
|---|---|---|---|
| TiDB | [Enterprise ticket／Community](https://docs.pingcap.com/tidb/stable/support/) | v8.5 LTS Launch @ 2024-12；Community 維護 2027-12-19／延伸 2028-12-19，Enterprise 維護 2029-12-19／延伸 2030-12-19 | 台灣時區／語言、事故的回應與解決時限、根因分析、升級及現場協作 |
| PXC／Galera | [Percona Support Policy](https://www.percona.com/support-policies/) | 8.4 持續發版中（最新 8.4.10-10，2026-07-27）；官方尚未公布 8.4 的 EOL 日期 | **現有維運人力已可覆蓋，不需原廠協助**；僅需追蹤 8.4 EOL 公告 |
| YugabyteDB | [Software Support Agreement](https://www.yugabyte.com/yugabyte-software-support-services-agreement/) | 2025.2 LTS 維護至 2027-12-11、EOL 2028-06-11 | 自管環境的支援範圍、回應窗口、根因分析與升級協作 |
| CockroachDB | [Essentials／Enterprise Policy](https://www.cockroachlabs.com/terms-and-conditions/cockroachdb-support-policy/) | v26.2 GA 維護至 2027-04-27 | 同 YugabyteDB 困境 |

> 「有原廠支援方案」不等於符合公司需求；回應時間也不等於問題解決時間。正式結論需以原廠正式詢價（RFI）、報價與合約條款為準。

---

# 建議｜技術面：先驗證可營運邊界，再談擴大部署

- **以服務故障範圍決定隔離層級**

   先辨識強耦合與共同故障域，再決定單叢集、多叢集、或跨機房配置。

- **下一階段 TiDB 聚焦五項營運能力**

   MySQL 相容性、PITR／還原、Online DDL、服務層 Failover、資源管理與多租戶隔離。

- **所有設定值都要回讀驗證**

   指令執行成功不等於實際生效；隔離級、副本數、資料放置、就近讀取與故障注入，都要再查一次系統實際狀態。

- **以服務恢復時間取代單一的叢集健康燈號**

   量測叢集恢復、資料可讀寫、終端服務恢復，以及交易是否遺失。還是 RTO ; 只是更換另一方式描述。

- **A/A 不作預設起點**

   先完成單區營運與災難復原就緒能力；只有業務提出雙區讀寫需求時才啟動 A/A 驗證。

---

# 建議｜產品與業務面：以 TSD 使用情境定義 Pilot

| 分組 | TSD 討論觀察 | 對下一階段的轉換 |
|---|---|---|
| **選題**｜挑哪個服務 | 故障影響範圍的重要性提高（AWS 下雲、地端集中） | Pilot 需選可驗證隔離與恢復的代表性服務 |
| | **DR Site／EDC 具活化價值，但跨區 A/A 尚無強需求** | **可先挑能移至 EDC 持續運作的定期批次或低風險服務** |
| **驗收**｜怎麼算通過 | 在意最快恢復服務，而非只有抽象 RTO／RPO | 定義使用者可感知的恢復驗收點 |
| | **一致性優先（C > A）** | **先驗證一致性、拒寫與恢復，不以持續寫入為唯一目標** |
| **協作**｜誰來做 | **產品期待 Database Self-Service** | **Pilot 同步驗證申請、權限、配額、備份、監控與退場** |
| | 應用端協作可行，但需清楚 R&R、效益與回復程序 | 協作 TSD 其產品 Owner，確認依賴與改造上限 |

> Infra 改造必須同時說明產品效益、應用改造量與投資報酬；技術可行不等於推進理由。

---

# 決策｜Next Action：PoC 後有五種可執行選項

**建議採 Option B。** PXC／Galera 保留相容與低延遲對照；PostgreSQL 路線等待 TSD 提供高關鍵度／AI 應用需求後再做目標式驗證。

| Option | 做法 | 優點 | 代價／限制 |
|---|---|---|---|
| 0｜保留現況 | 結束本輪 PoC、封存 framework，依既有架構營運 | 不增加遷移與平台成本 | 不解決既有故障域、擴展或服務化問題 |
| A｜技術補件 | 只補 TiDB 相容性、PITR、Online DDL 與支援資料 | 投入最低、快速補足評分缺口 | 無真實應用與服務生命週期證據 |
| **B｜快速驗證＋Pilot** | **TiDB 完成技術門檻，再導入一個代表性 MySQL 應用／批次** | **最快取得應用、維運、Self-Service 與投資報酬證據** | 需 SSD Infra ; TSD/產品單位 協作共識 |
| C｜目標式替代驗證 | TiDB 不適配時驗 PXC；有 PostgreSQL 需求時再驗 YugabyteDB／CockroachDB | 只補與需求直接相關的證據 | 不形成四產品完整排名 |
| D｜平台與跨區擴展 | Pilot 通過後建 Self-Service；有 DR／EDC 需求再做 A/S 或 A/A-RO | 可把一次性 PoC 轉為長期平台能力 | 需多團隊 owner、治理與持續成本；A/A 不作預設 |

---

# 決策｜如果只看 ROI：先確認問題，再決定投入深度

<!-- flow -->

| 判斷情境 | 條件 | 出口 |
|---|---|---|
| **沒有**明確業務問題、維持現狀 | — | **Option 0**：保留現況與 PoC framework，定期重審需求; 無明顯技術管理急迫 |
| **MySQL 應用**為主要範圍 | 相容性／還原／DDL 尚未知 | **Option A**：技術補件 |
| | 技術門檻通過且效益可量化 | **Option B**：TiDB Pilot |
| | TiDB 不適配或極低延遲優先 | **Option C**：PXC 目標式對照 |
| **PostgreSQL** 高關鍵度／AI 應用有需求 | — | **Option C**：依需求驗 YugabyteDB 或 CockroachDB ; 或延用現有 PostgreSQL 架構 |
| **平台化或跨區**需求成立 | 重複申請／維運成本高 | **Option D**：Database Self-Service |
| | DR／EDC 活化 | **Option D**：先 A/S，需異地讀再評估 A/A-RO |

> 不以已投入的 PoC 工時作為繼續理由；每個出口都須回到需求、降低無謂技術研究與可量化收益。

---

# 決策｜本次需要確認的事項

1. **是否採 Option B**：TiDB 快速驗證＋代表性應用 Pilot。

2. **其他待討論事項**

   - 由 TSD 指派應用 owner，提供真實 SQL／ORM／Driver／Transaction 與改造限制。
   - 確認 Pilot 情境：一般 MySQL 應用、可移至 EDC 的定期批次，或故障影響範圍較明確的服務。
   - 定義服務驗收：一致性優先條件、可接受中斷、資料延遲、降級與回復方式。
   - 啟動原廠正式詢價與成本資料蒐集：支援、授權、維運人力及基礎設施。

---

<!-- _class: lead -->

# 附錄

---

# 附錄 A：三年投資報酬模型與放行條件

| 投資報酬構成 | 應量化內容 | 證據 owner |
|---|---|---|
| 服務風險降低 | 事故次數、影響人數／交易、恢復時間、可避免損失 | 產品／SRE／TSD |
| 應用交付效益 | 擴展等待、改造工時、發版與 schema change 時間 | RD／TSD |
| 維運與服務化 | DBA 人工時數、申請交付時間、備份／還原與擴縮工時 | DBA／Infra |
| 基礎設施與商務 | 主機、儲存、專線、授權、原廠支援與年度 run-rate | Infra／採購／財務 |
| 導入與退出成本 | Pilot、遷移、雙軌、教育、回復、資料搬遷與 vendor exit | 專案 owner／架構 |

`三年投資報酬率 =（三年量化收益 − 三年增量成本）÷ 三年增量成本`

> 採三年為短中期效益檢視窗口，與[預算評估報告](https://github.com/heavenruler/dba_career/blob/master/poc/gitbook/deliverables/budget-assessment.md)的三年總持有成本口徑一致。

**放行條件**：技術硬 Gate 通過、假設有 owner 與範圍、敏感度分析完成，且投資報酬／回收期達公司門檻。現階段價格仍為 TBD，不宣稱已達成正向投資報酬。

> 詳細模型與最低成本啟動策略：[預算評估報告](https://github.com/heavenruler/dba_career/blob/master/poc/gitbook/deliverables/budget-assessment.md)。

---

# 附錄 B：實際測試數據入口

**同機房 S-BASE canonical `summary.json`**

- TiDB：[vm-1node](https://github.com/heavenruler/dba_career/blob/master/poc/results/tidb-tc1/S-BASE/vm-1node-rc/tidb-vm-1node-rc-20260518T202009+0800/summary.json)／[vm-3node HAProxy 3s3r](https://github.com/heavenruler/dba_career/blob/master/poc/results/tidb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-haproxy-3s3r-rc-20260601T003316+0800/summary.json)
- PXC／Galera：[vm-1node](https://github.com/heavenruler/dba_career/blob/master/poc/results/galera-tc1/S-BASE/vm-1node-rc/galera-vm-1node-rc-20260813T073744+0800/summary.json)／[vm-3node HAProxy 3s3r](https://github.com/heavenruler/dba_career/blob/master/poc/results/galera-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/galera-vm-3node-haproxy-3s3r-rc-20260813T112044+0800/summary.json)
- YugabyteDB：[vm-1node](https://github.com/heavenruler/dba_career/blob/master/poc/results/yuga-tc1/S-BASE/vm-1node-rc/ybdb-vm-1node-rc-20260520T134929+0800/summary.json)／[vm-3node HAProxy 3s3r](https://github.com/heavenruler/dba_career/blob/master/poc/results/yuga-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/summary.json)
- CockroachDB：[vm-1node](https://github.com/heavenruler/dba_career/blob/master/poc/results/crdb-tc1/S-BASE/vm-1node-rc/crdb-vm-1node-rc-20260519T085346+0800/summary.json)／[vm-3node HAProxy 3s3r](https://github.com/heavenruler/dba_career/blob/master/poc/results/crdb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/crdb-vm-3node-haproxy-3s3r-rc-20260602T051500+0800/summary.json)

**跨區與故障入口**

- [X-CROSS 結果索引](https://github.com/heavenruler/dba_career/blob/master/poc/results/x-cross/README.md)
- [P-A／P-B 最終比較](https://github.com/heavenruler/dba_career/blob/master/poc/phase-crossregion/XCROSS-PA-VS-PB-FINAL-COMPARISON.md)
- [三家 Chaos／Failover 比較](https://github.com/heavenruler/dba_career/blob/master/poc/phase-crossregion/XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md)
- [評分 SSOT](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md)

---

# 附錄 C：MySQL 路線官方來源

| 產品 | 架構／能力來源 | 版本與支援來源 |
|---|---|---|
| TiDB | [MySQL 相容性](https://docs.pingcap.com/tidb/stable/mysql-compatibility/)／[PITR](https://docs.pingcap.com/tidb/stable/br-pitr-guide/)／[Online DDL](https://docs.pingcap.com/best-practices/ddl-introduction/) | [Support Resources](https://docs.pingcap.com/tidb/stable/support/)／[Release Support Policy](https://www.pingcap.com/tidb-release-support-policy/) |
| PXC／Galera | [PITR](https://docs.percona.com/percona-operator-for-mysql/pxc/backups-pitr.html)／[XtraBackup](https://docs.percona.com/percona-xtrabackup/8.0/point-in-time-recovery.html)／[TOI／RSU](https://www.percona.com/blog/various-ways-to-perform-schema-upgrades-with-percona-xtradb-cluster/) | [Support Policy](https://www.percona.com/support-policies/)／[Release Lifecycle](https://www.percona.com/release-lifecycle-overview/) |

> 官方文件只證明功能、版本或支援方案存在；公司環境的相容性、營運效果與合約適用性仍需 Pilot 與原廠正式詢價驗證。

---

# 附錄 D：PostgreSQL 路線官方來源

| 產品 | 架構／能力來源 | 版本與支援來源 |
|---|---|---|
| YugabyteDB | [PostgreSQL 相容性](https://docs.yugabyte.com/stable/faq/compatibility/)／[PITR](https://docs.yugabyte.com/stable/manage/backup-restore/point-in-time-recovery/) | [Software Support Agreement](https://www.yugabyte.com/yugabyte-software-support-services-agreement/)／[2025.2 LTS](https://docs.yugabyte.com/stable/releases/ybdb-releases/) |
| CockroachDB | [PostgreSQL 相容性](https://www.cockroachlabs.com/docs/v26.2/postgresql-compatibility)／[PITR](https://www.cockroachlabs.com/docs/stable/take-backups-with-revision-history-and-restore-from-a-point-in-time)／[Online Schema Changes](https://www.cockroachlabs.com/docs/v26.2/online-schema-changes) | [Support Policy](https://www.cockroachlabs.com/terms-and-conditions/cockroachdb-support-policy/)／[Release Policy](https://www.cockroachlabs.com/docs/releases/release-support-policy) |

> 官方文件只證明功能、版本或支援方案存在；公司環境的相容性、營運效果與合約適用性仍需 Pilot 與原廠正式詢價驗證。

---

# 附錄 E：證據限制與判讀邊界

- 本 PoC 使用 go-tpc 執行 TPC-C-derived stress workload，不是 audited TPC-C 認證。
- 目前多數效能 cell 為 `N=1`，可用於方向性建議，不宣稱統計顯著或正式容量。
- 跨區結果屬探索性 scope（`baseline_eligible=false`），不得併入 S-BASE 跨家排名。
- PXC／Galera 與 TiDB 的複寫、擴展、Failover 情境不同；本輪 Failover 計時口徑不等價，暫不排名。
- 官方文件星等不計入已測項目加權分數；真正導入結論以應用相容性、營運演練、原廠條款與總持有成本為準。
- 完整限制、公式與 Fact／Inference 分層以[評分 SSOT](https://github.com/heavenruler/dba_career/blob/master/poc/DISTRIBUTED-DB-SCORING.md)為準。
