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
    font-size: 22px;
    color: #22303f;
  }
  h1 { font-size: 32px; color: #1a2b3c; }
  h2 { font-size: 26px; color: #1a2b3c; }
  table { font-size: 19px; }
  strong { color: #c0392b; }
  section.lead h1 { font-size: 40px; }
---

<!-- _class: lead -->

# 分散式資料庫 PoC：階段性結論與第二階段決策

2026-08-21

對應 [ITDBA-3596](https://104corp.atlassian.net/browse/ITDBA-3596)

---

# 目前證據可縮小範圍，尚不足以直接選型

**一、已完成初步驗證的技術風險**

單節點延遲、水平擴展、高併發穩定性，以及部分故障復原情境，四條候選路線皆有可追溯的量測結果。

**二、為何目前不足以選定產品路線**

產品應用相容性、備份還原、線上結構變更等權重尚未計分，這些正是決定應用改造成本與維運可行性的關鍵項目。

**三、建議進入下一階段**

進入應用相容性、維運能力與成本驗證階段，完成後再做產品 shortlist。

> **建議 PoC 下一階段方向**：根據產品規劃&公司層級技術管理策略，合適合理評估驗證範圍與資源投入

---

# 先確認協定路線，再於同群組內比較產品

| 相容路線 | 候選產品 | 現行叢集數 | 商務邏輯營運占比 |
|---|---|---:|---:|
| MySQL 相容 | Percona XtraDB Cluster 8.4（PXC，Galera）、TiDB | 28 | 約 95% |
| PostgreSQL 相容 | YugabyteDB、CockroachDB | 4 | 約 5% |

- 協定不同代表應用改造成本量級不同，是「能不能直接換」的門檻，不是效能差異
- 依現況盤點，**第二階段可優先驗證 MySQL 相容路線**——這是執行優先序，不是預選任何產品
- 兩群組分數不互相比較

> 現況盤點統計日期 2026/08/14；單位為資料庫叢集、產品、服務別；來源為現行 Prod 監控彙整（非精算值）

---

# 兩條路線的證據完成度不同

**三種證據等級必須分開判讀**

| 標示 | 證據等級 | 可支持的用途 |
|---|---|---|
| ✅ | PoC 實測 | 同群組、同條件下的方向性比較 |
| 📄 | 官方文件記載 | 產品設計或支援能力存在，**不計入加權分數** |
| ⏳ | 待驗證 | 尚無證據，不得以設計規格代替 |

---

# MySQL 相容路線：兩家強項互補，尚無單一勝出者

| 面向 | 目前判讀 | 證據 |
|---|---|:---:|
| 原生 MySQL 相容性 | PXC／Galera 較有利 | 📄 |
| 單節點／低併發延遲 | PXC／Galera 較有利 | ✅ |
| 水平擴展能力 | TiDB 較有利 | ✅ |
| 高併發穩定性 | TiDB 較有利 | ✅ |
| 故障切換（Failover） | 兩家測試邊界與計時口徑不等價，暫不排名 | ✅ |
| 相容性／PITR／Online DDL | 仍需實測 | ⏳ |

> PITR（Point-in-Time Recovery，還原到指定時間點）；Online DDL（線上結構變更）
> 全項評分見附錄 B

---

# PostgreSQL 相容路線：指數相同，能力組成不同

| 面向 | 目前判讀 | 證據 |
|---|---|:---:|
| PostgreSQL 相容性 | YugabyteDB 較有利 | 📄 |
| 單節點／低併發延遲 | YugabyteDB 較有利 | ✅ |
| 水平擴展能力 | CockroachDB 較有利 | ✅ |
| 高併發穩定性 | CockroachDB 較有利 | ✅ |
| 故障切換（Failover） | YugabyteDB 較有利 | ✅ |
| 相容性／PITR／Online DDL | 仍未完成驗證 | ⏳ |

- 兩家已測項目的部分加權指數相同（見附錄 C），但強項分布不同
- **指數相同不等於能力相同**，不可據此判定兩者可互相取代

---

# 正式選型前必須通過四個 Gate

| Gate | 必須回答的問題 | 主要輸出 | 建議 owner |
|---|---|---|---|
| 應用適配 | SQL、ORM、Driver、交易模式是否可接受 | 相容性矩陣與改造清單 | TSD／產品開發 |
| 維運就緒 | PITR、Online DDL、Failover 是否達門檻 | 操作手冊與驗證紀錄 | DBA／Infra |
| 服務需求 | RTO、RPO、一致性及 A/S、A/A-RO、A/A 是否真的需要 | 可驗收的服務需求 | 產品／架構／管理層 |
| 商務可行 | 五年 TCO、授權、專線、維運人力是否可接受 | 成本模型與最低成本啟動方案 | 管理層／採購／財務 |

> RTO（服務恢復時間目標）／RPO（可容忍資料遺失量）／TCO（總持有成本）
> A/S（單邊寫入、異地待命）／A/A-RO（異地唯讀）／A/A（兩地同時寫入）

---

# 本次需要核准的五項決策

1. **是否核准第二階段驗證範圍**（應用相容性、維運能力、成本三大面向）
2. **是否指派 TSD／產品端 owner** 提供真實 application 使用樣本
3. **是否要求產品端定義**可接受的 RTO、RPO、一致性與改造範圍
4. **是否啟動成本資料蒐集**：TCO、授權、維運人力與跨區網路成本
5. **第二階段完成後**，再進行產品 shortlist／pilot 決策

> 本次不做產品選型決議；上述四個 Gate 未通過前，不進入採購或導入階段

---

<!-- _class: lead -->

# 附錄

---

# 附錄 A：評分規則與證據等級

**星等規則**

- 星等只在**同一相容群組內**依實測數值相對排序，最佳＝⭐⭐⭐⭐⭐
- 星等是群組內相對評級，不是業界絕對基準
- MySQL 與 PostgreSQL 群組的星等與分數不互相比較

**證據等級**

- ✅ PoC 實測：以 go-tpc TPC-C-derived stress workload 於相同硬體與參數條件下量測
- 📄 官方文件記載：依廠商官方文件的支援狀況評定，**不計入加權分數**
- ⏳ 待驗證：尚未排入測試矩陣

**「待重新評估」**：已有原始數據，但兩家計時／比較口徑不等價，暫不評星

---

# 附錄 B：MySQL 相容群組評分明細

| # | 項目 | 權重 | PXC／Galera | TiDB | 證據 |
|---|---|---:|:---:|:---:|:---:|
| 1 | MySQL 協定相容性 | 20% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ | 📄 |
| 2 | 單節點/低併發延遲 | 19% | ⭐⭐⭐⭐⭐ | ⭐☆☆☆☆ | ✅ |
| 3 | 水平擴展能力 | 24% | ⭐☆☆☆☆ | ⭐⭐⭐⭐⭐ | ✅ |
| 4 | 高併發穩定性 | 19% | ⭐☆☆☆☆ | ⭐⭐⭐⭐⭐ | ✅ |
| 5 | Failover RTO／RPO | 5% | 待重新評估 | 待重新評估 | ✅ |
| 6 | PITR／備份還原 | 3% | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ | 📄 |
| 7 | Online DDL 與維運工具 | 5% | ⭐⭐☆☆☆ | ⭐⭐⭐⭐⭐ | 📄 |
| 8 | HTAP／TiFlash | 5% | n/a | 待測 | ⏳ |

已測項目部分加權試算：**PXC／Galera 44.5｜TiDB 75.5**（已計分 62%，非產品總分）

---

# 附錄 C：PostgreSQL 相容群組評分明細

| # | 項目 | 權重 | YugabyteDB | CockroachDB | 證據 |
|---|---|---:|:---:|:---:|:---:|
| 1 | PostgreSQL 協定相容性 | 10% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐☆☆ | 📄 |
| 2 | 單節點/低併發延遲 | 24% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐☆☆ | ✅ |
| 3 | 水平擴展能力 | 29% | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ | ✅ |
| 4 | 高併發穩定性 | 24% | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ | ✅ |
| 5 | Failover RTO／RPO | 5% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ | ✅ |
| 6 | PITR／備份還原 | 3% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ | 📄 |
| 7 | Online DDL 與維運工具 | 5% | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ | 📄 |

已測項目部分加權試算：**YugabyteDB 87.1｜CockroachDB 87.1**（已計分 82%，非產品總分）

---

# 附錄 D：官方文件星等不是單向加分項

**MySQL 相容群組**

- #1 協定相容性：PXC／Galera 為原生 MySQL 分支較有利
- #7 Online DDL：**換 TiDB 較有利**——Percona 官方文件說明 TOI 方式執行 `ALTER TABLE` 會鎖住整個叢集寫入

**PostgreSQL 相容群組**

- #1／#6：YugabyteDB 較有利——YSQL 直接重用 PostgreSQL 查詢層原始碼、PITR 涵蓋部署層級較廣
- #7 Online DDL：**換 CockroachDB 較有利**——官方定位為內建、不鎖表能力

> 官方文件只說明產品設計或支援能力，不代表本 PoC 已實測；真正判讀仍需第二階段驗證

---

# 附錄 E：資料庫版本生命週期

| 產品 | PoC 版本 | 版本類型 | 支援到期 | 佐證等級 |
|---|---|---|---|---|
| TiDB | 8.5.x | LTS（Community） | 維護 2027-12-19／延伸 2028-12-19 | 官方公告 |
| CockroachDB | v26.2 | Regular release | 維護 2027-04-27／協助 2027-10-27 | 官方公告 |
| YugabyteDB | 2025.2.x | LTS | 政策為首版起 2 年＋180 天 | 依政策推算 |
| PXC／Galera | 8.4.x | LTS line | 官方 EOL 日期尚待確認 | 待確認 |

- YugabyteDB 未查得逐版逐日公告，僅能依官方版本政策推算，非官方承諾日期
- PXC／Galera 8.4 的 EOL 日期未見於 Percona 官方 lifecycle 頁面，需向原廠確認

---

# 附錄 F：證據索引與限制

**追溯入口**

- 評分 SSOT：[`DISTRIBUTED-DB-SCORING.md`](../DISTRIBUTED-DB-SCORING.md)
- 評分導讀：[`DISTRIBUTED-DB-SCORING-INTRO.md`](../DISTRIBUTED-DB-SCORING-INTRO.md)
- 結果索引：[`results/README.md`](../results/README.md)
- 跨區結果索引：[`results/x-cross/README.md`](../results/x-cross/README.md)

**判讀限制**

- 本 PoC 為 stress benchmark／TPC-C-derived workload（go-tpc），非 audited TPC-C 認證
- 跨區結果屬探索性 scope（`baseline_eligible=false`），不作為 Active/Active 或災難復原能力的驗證依據
- 本階段結論以現有實測證據為支撐；若後續需形成容量或採購承諾，再依該決策所需的驗證深度補強
