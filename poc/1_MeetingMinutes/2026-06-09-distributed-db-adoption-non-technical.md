# 2026-06-09 分散式資料庫導入：非技術討論 minutes (draft v1)

> 由 sub-agent (ab18210067fd25784) 起草，主 agent 整合 + commit。
> Status: draft pending user 拍板 12 道 open questions。

## 1. 緣起

PoC 已累積 4 個 phase 完整討論與資料：

| Phase | Status | 關鍵成果 |
|---|---|---|
| phase-baseline (S-BASE) | ✓ 完成 | vm-1node + vm-3node-{1s1r,1s3r,3s1r,3s3r,haproxy-3s3r} × {TiDB, CRDB, YBDB} × {RC, RR, strict} 全 cell N=1 |
| phase-threadcontrol (T-THRD) | ✓ spec 完成 | tidb-readpool tuning profile, framework + smoke 規範 |
| phase-k8s (S-K8S) | ⚙️ 執行中 (2/6 cell done) | TiDB-{unlimit, limit} 完成，CRDB-unlimit 進行中；YBDB-{unlimit, limit} 待 |
| phase-crossregion (X-CROSS) | ✓ plan 拍板 (decisions-2026-06-08.md) | 10 questions 拍板；~56 工作天 scope |

**技術面已成熟**；transition 至「該不該真正導入營運」需要組織/業務層級對齊。本 minutes 為起點。

## 2. 9 軸非技術討論面向總覽

| # | 軸 | 主要決策 | 預估討論工時 |
|---|---|---|---|
| 1 | 戰略需求 | 5 年 OLTP 是否超出單機 RDBMS 能力？ | 1 day |
| 2 | Vendor 政策 | 排除哪些（中資 / BSL / 規模 / 商業實體）？ | 0.5 day |
| 3 | 組織/人力 | DBA 擴編 vs vendor managed cloud？ | 1 day |
| 4 | 成本/預算 | 5 年 TCO；vendor 授權 + 雲端 egress + 人力 | 1 day |
| 5 | 合規/法規 | 跨境（IDC→GCP）個資流動；資料留存稽核 | 1-2 day（須法務 in loop）|
| 6 | 遷移風險 | 既有 MySQL/Pg/Oracle 應用 SQL 方言相容性 | 1 day |
| 7 | DR/BC | 跨區 RTO/RPO 是否 hard requirement？ | 0.5 day |
| 8 | 變更管理/SRE | DBA 工作流程 paradigm shift; on-call rotation | 0.5 day |
| 9 | 採購/對外溝通 | 預算編列窗口（Q4 對齊）、stakeholder 對齊會議 | 1 day |

---

## 3. 各軸詳述

### 3.1 戰略需求（最前提）

**現況**：PoC 由 DBA team 發起，技術可行性已驗證。但「業務必要性」未經正式 BOD-level 確認。

**議題**：
- 公司主力 OLTP 系統（HR / 求才求職 platform / 金流）資料量 5 年成長預估？
- 既有 RDBMS (MySQL / Oracle / SQL Server) 在 vertical scale (e.g., 64-core / 256GB RAM) + read replica 是否足支撐？
- distributed SQL 真實需求：geo-distribution / multi-region active-active / 99.99% SLA / 10s TB → PB scale-out？哪一個是 hard requirement？

**待決**：→ **Q1**

### 3.2 Vendor 政策與篩選

**現況**：PoC 涵蓋 TiDB / CockroachDB / YugabyteDB 三家。

**潛在排除因素**：
| 因素 | TiDB (PingCAP) | CockroachDB (Cockroach Labs) | YugabyteDB (Yugabyte Inc.) |
|---|---|---|---|
| 公司國籍 | 中國（雖總部 California，創辦人/主力研發中國）| 美國 | 美國 |
| 授權模式 | Apache 2.0 (OSS) + Enterprise | BSL → Apache（PR 後） | Apache 2.0 |
| 商業實體狀態 | 私募，Series F (2024) ~3.6B 估值 | IPO 申請中 (2024)，年營收 ~150M | 私募，Series C (2022) ~1.3B 估值 |
| 中資投資 | Tencent / Matrix Partners China | 無 | 無 |
| 國內客戶可見度 | 多（中信 / 富邦 / 玉山）| 少 | 少 |

**議題**：
- 公司是否有「禁止中資技術」政策？
- BSL 授權是否 acceptable（CRDB 已 BSL）？
- 三家任一是否屬被監管的「禁用名單」？

**待決**：→ **Q2**

### 3.3 組織/人力

**現況**：DBA team N 人（規模 user 補充）；都是 MySQL/Oracle 背景；無 distributed DB 維運經驗。

**議題**：
- distributed DB 維運是 paradigm shift：raft consensus / region scheduling / placement / online schema change / TSO debugging — 非漸進
- 估需 1-2 名 senior DBA 進新訓 / 招聘
- 替代方案：vendor managed cloud（TiDB Cloud / CockroachDB Cloud / YugabyteDB Anywhere），由 vendor 維運
- on-call rotation 影響：distributed DB issue 通常需要 cross-team coordination (SRE + 網路 + 應用)

**待決**：→ **Q4**

### 3.4 成本/預算

**5 年 TCO 三維度**：
1. **授權** vendor enterprise license / per-vCPU subscription
2. **基礎建設** vCPU / RAM / storage / 跨區網路 egress
3. **人力** DBA 擴編 / 訓練 / 外部支援合約

**估算**（粗估 3-node TiDB cluster）：
- 自建 IDC: license $0 (OSS) + 3 × $30k VM + $20k 人力訓練 = ~$110k year 1
- TiDB Cloud: ~$10k/month × 12 = $120k year 1
- CockroachDB Cloud Dedicated: ~$15k/month × 12 = $180k year 1
- YugabyteDB Managed: ~$12k/month × 12 = $144k year 1

實際數字需詢價（PoC 階段未做 vendor 報價）

**議題**：
- 預算 source: capex (基礎建設) vs opex (cloud)
- 5 年攤提 vs 3 年攤提
- Egress 流量超預期風險（跨區 raft 流量可能 1-3 TB/month）

**待決**：→ **Q7**

### 3.5 合規/法規/資料治理

**最高關注議題**：

1. **個資跨境流動**（IDC TW ↔ GCP asia-east1 TW）：
   - GCP asia-east1 機房在彰化，**physical 在台灣境內** → individual 個資保護法 (PDPA) 屬「境內」
   - 但 GCP 為境外法人實體，數據雖在台**法律上仍屬 Google LLC 控制**
   - 法務認可？需求徵詢

2. **跨境 raft replication 流量**：
   - placement P-B (cross-region active-active) leader 散兩端 → 每筆 commit 跨 WAN
   - 個資 record 透過 raft log 跨境傳輸 → 雙向都觸發 cross-border data flow
   - 合規 review 必經（個資法 §21 / 個資安全維護計畫）

3. **稽核日誌**：
   - distributed DB 的 audit log 與單機 RDBMS 結構不同（per-node + central aggregator）
   - 既有稽核系統（ELK / Splunk）是否 ready？

**待決**：→ **Q5** + **Q6**

### 3.6 遷移風險

**既有應用棧分析**（需 user 補充）：

| 應用 | DBMS | ORM | 預估遷移難度 |
|---|---|---|---|
| 主 HR | ? | ? | ? |
| 求才求職 | ? | ? | ? |
| 金流 | ? | ? | ? |

**TiDB 相容性**：MySQL wire-protocol → 大部分 MySQL ORM 直接可用；但 `AUTO_INCREMENT` / `SHOW MASTER STATUS` / 部分 SQL 函式不同
**CockroachDB**：PostgreSQL wire-protocol → 部分 Pg 函式不同；transaction retry 行為差異大
**YugabyteDB**：PostgreSQL wire-protocol → Pg 11+ 子集；DDL transactional 行為差異

**議題**：
- 應用 query 是否高度依賴 stored procedure / trigger？distributed DB 多數不支援
- ORM (Hibernate / SQLAlchemy / Django ORM) 版本相容性
- migration 策略：dual-write / change data capture / cutover window

**待決**：→ **Q8**

### 3.7 DR / BC

**現況**：
- 既有 RDBMS DR：每日 backup → off-site；RTO ~4h / RPO ~24h
- distributed DB 內建跨區 replica：理論 RTO < 1 min / RPO < 1s

**議題**：
- 業務 SLA 是否要求 RTO < 1 min？或既有 4h 已夠？
- 若不要求跨區 active-active → phase-crossregion 大幅縮減（~56 → ~10 工作天）
- 災難演習頻率（distributed DB 需更頻繁練習 failover）
- 跨區 raft log 延遲（IDC↔GCP ~10ms）對 commit latency 影響業務可接受嗎？

**待決**：→ **Q3**

### 3.8 變更管理 / SRE 觀念

**議題**：
- DBA → DB-SRE: 概念轉變（觀察性 / on-call / automation / SLO）
- CI/CD 對 schema migration 影響（distributed DB 多支援 online DDL，但 ORM 端 migration tool 不一定 ready）
- 工作流程：既有 RDBMS 多走 「DBA 手動 review SQL」；distributed DB 鼓勵「應用工程師自助 migration」
- 文化轉變預估 6-12 個月

### 3.9 採購流程 / 內部對齊

**Stakeholder map**：

| Role | 立場 | 對齊 |
|---|---|---|
| CTO / VP Engineering | 戰略決策 | 必對齊 |
| Infra 主管 | 基礎建設 ownership | 必對齊 |
| DBA 主管 | 維運 ownership + 人力擴編 | 必對齊（即 PoC 主導）|
| SRE 主管 | on-call / 監控 / SLO | 必對齊 |
| 應用開發主管 | 應用相容 + migration burden | 必對齊 |
| CFO / 採購 | 預算 + vendor contract | 必對齊 |
| 法務 / Compliance | PDPA / 合規 | 必對齊 |
| Audit | 稽核準備 | 需被告知 |
| 業務 (各 BU) | SLA / 業務影響 | 需被告知 |

**Critical path**：
- 跨部門對齊會議（需 CTO 拉）→ Q3 開預算編列 → Q4 budget approval → 隔年 H1 pilot start
- 若拖到 Q3 才對齊 → 預算窗口錯過 → 整體計畫延後 12 個月

**待決**：→ **Q9** + **Q10** + **Q11**

### 3.10 對外溝通 / 內部背書

**議題**：
- POC report 該以什麼形式呈現？BOD / executive summary / technical deep dive？
- 是否需邀請 vendor presentation 給 stakeholder？
- 第三方驗證（顧問公司 / Gartner 評估）必要？

**待決**：→ **Q12**

---

## 4. 利害關係人對齊表

| Stakeholder | 對齊狀態 | 下次 sync 內容 |
|---|---|---|
| CTO | ❓ 未啟動 | Q1 戰略需求 / Q2 vendor 政策 |
| Infra 主管 | ❓ 未啟動 | Q4 self-managed vs managed / Q7 預算 |
| DBA 主管 | ✓ PoC 已 own | 全部議題（PoC 主導者）|
| SRE 主管 | ❓ 未啟動 | Q4 on-call / Q8 變更管理 |
| 應用開發主管 | ❓ 未啟動 | Q8 遷移風險 |
| CFO / 採購 | ❓ 未啟動 | Q7 5 年 TCO |
| 法務 / Compliance | ❓ 未啟動 | Q5 跨境個資 / Q6 raft 流量合規 |
| Audit | ❓ 未啟動 | Q5 稽核日誌 |
| 業務 (各 BU) | ❓ 未啟動 | Q3 RTO/RPO SLA |

---

## 5. Open Questions（user 拍板）

### Top 5（critical path，前提性）

**Q1**: distributed SQL DB 導入是否真有業務必要？
- *Context*: 5 年 OLTP 是否超出單機 MySQL/Oracle 能力（含 read replica）?
- *預設答*: 若無 hard data 證明，PoC 結束，無導入
- *影響*: Q2-Q12 全部作廢的前提條件

**Q2**: 三家 vendor 是否有公司政策必須排除？
- *Context*: 中資（TiDB / PingCAP）/ BSL 授權（CRDB）/ 規模（私募 vs 上市）
- *預設答*: 若無排除政策，三家齊頭 fair compare
- *影響*: vendor 篩選 / 報價時間

**Q3**: 跨區（IDC ↔ GCP）DR 是否為 hard requirement？
- *Context*: phase-crossregion ~56 工作天 + 跨境合規範圍
- *預設答*: 若非 hard requirement，phase-crossregion scope 縮為 IDC-only
- *影響*: phase-crossregion 縮 ~56 → ~10d；P4/P5 backup/migration 全免

**Q4**: DBA 團隊擴編 + self-managed vs 不擴 + managed？
- *Context*: distributed DB paradigm shift；self-managed 需 1-2 senior 擴編
- *選項*: (a) 擴 + self-managed / (b) 不擴 + vendor managed cloud / (c) 不導入
- *影響*: §3.1 組織 / §3.2 成本 / §3.7 變更管理 三軸

**Q5**: 是否啟動跨部門 stakeholder 對齊會議？
- *Context*: Q4 預算窗口 hard deadline；對齊會議是 pilot 啟動前置
- *預設答*: 是，目標 6 月底前完成第一輪
- *影響*: 整體時程

### 第 6-12 題（執行細節）

**Q6**: 個資跨境流動（IDC TW → GCP asia-east1 TW）法務 review 何時啟動？
- *Context*: GCP asia-east1 物理在台但法人 Google LLC（境外）；個資法 §21
- *預設答*: Q5 對齊會議後 30 天內啟動法務 review

**Q7**: 5 年 TCO 預算 source（capex 自建 vs opex cloud）？
- *Context*: 自建 ~$110k year 1 / cloud ~$120-180k year 1
- *預設答*: 待 Q4 拍板 self vs managed 後決定

**Q8**: 應用棧現況評估（DBMS / ORM / stored proc 使用）何時做？
- *Context*: 遷移可行性評估的前置研究
- *預設答*: Q5 對齊後啟動，由應用 team owner 負責

**Q9**: pilot DB 選哪個應用？
- *Context*: pilot 必選一個非 critical 應用為試點
- *候選*: 內部工具 / 新功能模組 / 非主力業務
- *預設答*: 待應用 team 評估

**Q10**: 第三方顧問（Gartner / Forrester / 諮詢公司）是否邀請？
- *Context*: BOD-level 決策的外部背書
- *預設答*: 視 Q1 答的嚴重性決定

**Q11**: 預算編列窗口（公司 Q4 預算流程）的內部 deadline？
- *Context*: 一般大公司預算編列 Q3 前需鎖定
- *預設答*: 待 CFO / 採購 確認

**Q12**: POC report 呈現形式？
- *Context*: 給誰看 + 深度
- *選項*: BOD summary (1-2 pg) / Executive deep dive (10 pg) / Technical detail (30+ pg)
- *預設答*: 三層皆做（不同 audience）

---

## 6. 推薦下一步動作

| Action | Owner | Timing | Critical Path? |
|---|---|---|---|
| 1. User 拍板 Top 5 questions | user | now | ✓ critical |
| 2. 草擬 BOD-level POC executive summary (1-2 pg) | DBA 主管 | Q1 拍板後 1 週 | ✓ |
| 3. 跨部門對齊會議 round 1（CTO / Infra / 應用 / CFO）| DBA 主管 + 行政 | Q5 拍板後 2 週 | ✓ |
| 4. 法務 review 啟動 | DBA 主管 + 法務 | Q3 拍板後 30 天 | (僅 Q3=yes 時)|
| 5. Vendor 報價收集（如 Q2 不排除）| 採購 | Q2 拍板後 30 天 | |
| 6. 應用棧現況評估 | 應用主管 | Q5 對齊後 30 天 | (僅 Q1=yes 時)|
| 7. pilot 應用選擇 | 應用主管 | 應用棧評估後 30 天 | |
| 8. DBA 擴編 / 訓練 plan | DBA 主管 | Q4 拍板後 30 天 | (僅 Q4=self 時)|
| 9. CFO 預算編列 | CFO | Q11 拍板後 60 天 | ✓ Q4 hard deadline |
| 10. 顧問評估報告（若 Q10=yes）| 採購 + 外部 | 視 Q10 排程 | |
| 11. POC report 三層撰寫 | DBA 主管 | now | |
| 12. pilot kickoff | DBA + 應用 | 隔年 H1 | ✓ 取決於 9 |

**Critical path 總長**：Q1 拍板 → Q5 對齊會議 → Q4 預算 → 隔年 H1 pilot
最快 ~4-6 個月（含對齊會議 + 預算流程 + 法務）

---

## 7. References

- `1_MeetingMinutes/0602-decisions-track-E.md` — 既有跨區決議
- `1_MeetingMinutes/0605.md` — TPCC 設計討論
- `1_MeetingMinutes/0606-test-plan-orchestration.md` — phase-k8s/threadcontrol 測試 plan
- `phase-crossregion/decisions-2026-06-08.md` — phase-crossregion 10 questions 拍板
- `results/PoC-DESIGN.md` — PoC 設計全文
- `results/README.md` — PoC 進度 + 結論
- External vendor 資料：
  - PingCAP 公司 about / 投資人 list
  - Cockroach Labs S-1 / annual report
  - Yugabyte Series C announcement

## 8. User 拍板紀錄（2026-06-09 互動式 Q&A）

### Q1: 業務必要性 — **Yes + Likely**
- 明確有 distributed DB 需求（部分 hard requirement 已存在）
- 但**仍需盤點現有 RDBMS vertical scale + read replica 上限**作為對照基準
- 推導：Q2-Q14 續進；補做 Q9 (sharded MySQL baseline 對照)

### Q2: Vendor 排除政策 — **三家齊頭評估**（user 拍板「一起評估」）
- 三家無公司政策排除；fair compare
- user 補問「維運層次評估考量」→ 補 §9 Vendor 維運後勤 比較表
- 推導：Q13 (PG→TiDB) / Q14 (all-in TiDB) 仍開啟；後續 vendor 評估走實際維運/支援 + 性能/合規/應用相容綜合決策

---

## §9. Vendor 維運/後勤對比（Q2 user 補問追加）

| 維度 | TiDB (PingCAP) | CockroachDB (Cockroach Labs) | YugabyteDB (Yugabyte Inc.) |
|---|---|---|---|
| 24×7 SLA | enterprise OK | premium OK | platinum OK |
| 中文文件 / 中文支援 | ✓ 完整中文團隊 | ✗ 僅英文 | △ 部分中文 |
| 台灣 partner / reseller | ✓ 多家 | ⚠️ 無 | ⚠️ 無 |
| on-prem enterprise | ✓ TiDB Enterprise Server | ✓ self-hosted Enterprise | ✓ self-hosted Enterprise |
| Critical CVE SLA | 1-2 週 | 1-2 週 | 1-4 週 |
| Major LTS 支援週期 | 18-36 月 | 12 月 | 24-36 月 |
| 顧問費 daily rate | $1.5-3k AP | $2.5-5k US | $2-4k US |
| 台灣客戶 case | ✓ 中信/富邦/玉山/台達 | ⚠️ 無公開 | ⚠️ 無公開 |
| Commercial status | 私募 Series F；2024 裁員 ~20% | IPO filed；2024 營收 ~150M cash burn | 私募 Series C；近兩年動態低調 |
| 授權純度 | OSS + Enterprise | BSL+ELv2 (有 use 限制) | Apache 2.0 OSS + Enterprise 可選 |

### Vendor 評估下一步建議
1. 三家詢價 SPIN（cluster scale + tier + 5-yr quote）— 1 週收回
2. 維運 ecosystem demo（installer/monitoring/DR/upgrade）— 各 1 週
3. 客戶 reference call（台灣優先）— 3-4 週
4. CVE / EOL 政策書面承諾 — 2 週

---

### Q13 (新增): PG 應用導入 TiDB 可行性
- *Context*: TiDB 是 MySQL 8.0 wire-compat；PG → TiDB 是 cross-engine 遷移（SQL 方言 + driver + ORM dialect 三重）
- *選項*: (a) PG-stack 為主 → 排除 TiDB / (b) MySQL-stack 為主 → TiDB 首選 / (c) 混合 → 拆 track
- *影響*: 直接決定三家篩選；與 Q2 / Q14 連動

### Q14 (新增): all-in TiDB 公司樂見否
- *Context*: PoC 中 TiDB tpmC 26,947 (最強 vs CRDB 15k / YBDB 15.6k)；但 all-in = 中資 vendor lock-in
- *選項*: (a) all-in TiDB / (b) TiDB-primary + 1 backup vendor / (c) multi-vendor by use-case
- *影響*: vendor 策略；與 Q2/Q4/Q13 強連動

### Q3: 跨區 IDC↔GCP DR — **No, 但中長期必需** (2026-06-09 拍板)
- *拍板理由*: 現行 distributed DB 導入 focus 在 IDC，累積維運經驗 + 架構穩定性 test
- *phase-crossregion 處置*: framework 保留作能力儲備（5 GCP VM iac + tidb-vm6 ansible + placement SQL + dry-run gate + chrony gate）；**不 destroy commit 0c17ae9**；當業務面 ready 時隨時啟動
- *Q8 (TLS 補測) 降權*: 仍可補 cavet-only

### Q3 衍生 — 「IDC-first + cross-region 中長期」可規劃周邊（10 項）

| # | 項目 | 啟動時機 |
|---|---|---|
| 1 | IDC 內多機房 DR (multi-rack/AZ) — RF=3 對應不同機櫃/電源組 | pilot 同期 |
| 2 | IDC backup → GCS/S3 冷備（非 active DR）— TiDB BR / cockroach backup / yb-admin → S3 | pilot + 3-6 月 |
| 3 | observability 跨區 (metrics/log ship 到 GCP) — Prometheus/Grafana federation | pilot 同期 |
| 4 | DBA cross-region lab 訓練 — phase-crossregion framework 跑 lab；不上 prod | DBA 擴編後 |
| 5 | 法務 / 個資跨境 pre-review — 個資法/GDPR/資料留存預先 review | 跨部門對齊後 |
| 6 | CFO cross-region cost model 教育 — egress/replicate/storage 預估 | 跨部門對齊後 |
| 7 | Vendor 詢價含 multi-region SLA — enterprise tier 必含 | vendor 詢價同步加入 |
| 8 | 網路架構規劃 (IDC↔GCP VPN/Cloud Interconnect) — IT/Network team 預想 | pilot + 6 月 |
| 9 | 應用 DB 連接抽象層 (proxy/connection string config) — 未來改 multi-region 不改 app code | pilot 同期（**必做**）|
| 10 | Chaos engineering 先在 IDC 練 — 跨機櫃 node down / network partition lab | pilot + 1 月 |

### Q13: PG→TiDB 可行性 — **TiDB 著重**（MySQL 相容性為主）
- *拍板理由*: 公司現行業務 MySQL stack 為主，**PostgreSQL stack 占比 < 5%**
- *推導*: TiDB 為首選；PG-stack 5% 應用先**列為「不導入 distributed DB」或獨立評估**（不阻礙 TiDB 路線）
- *Vendor 篩選收斂*: 三家齊評但實際 weight 偏 TiDB；CRDB/YBDB 角色為 backup vendor candidate (Q14 連動)

### Q14: all-in TiDB — **Unknown / 資訊不足**
- *拍板理由*: 目前 DBA 持有資訊**不足以上 CTO / IT 治理委員會決議**
- *阻塞點*: 缺以下背書資料：
  1. PingCAP 商業實體最新狀態（2026 Q1/Q2 財務 / 客戶留存率 / 裁員後組織恢復）
  2. 中資 vendor 在公司「敏感系統採用清單」的政策依據（HR/法務/Audit 三方共識）
  3. TiDB enterprise license 5-yr TCO vs CRDB/YBDB 實際報價對比（Q7 待啟動）
  4. 三家在台客戶 reference call 結果（特別是大型金融/電商客戶經驗）
  5. all-in vs dual-vendor 維運成本量化對比（人力 / 訓練 / on-call）
- *下一步*: 啟動「Q14 預備工作」（補上述 5 項背書資料後重議；估 ~4-6 週）
  - 工作 1: 採購 / 法務 / DBA 聯合啟動 vendor 詢價 + 參考實況查訪（Q7 觸發）
  - 工作 2: HR/法務寫「中資 vendor 採用評估準則」內部備忘
  - 工作 3: 邀請 vendor 來司 briefing × 3 家（含 reference customer）

### Q4: DBA 擴編 + self-managed — **(a) 擴編 + self-managed**
- *拍板理由*: 公司保留 know-how；長期成本較低；vendor lock-in 風險低
- *Action items*:
  1. JD 起草「distributed DB DBA (Senior)」職缺（TiDB / CRDB / YBDB 任一精通即可）— DBA 主管 + HR
  2. 預算: senior DBA × 1-2 名年薪 ~150-220k USD × 5 年 = ~1.5-2.2M USD（內部成本）
  3. 既有 DBA 訓練 plan: TiDB Univ / Cockroach U / Yugabyte U 自學 + vendor on-site workshop（~10-20 days × team N 人）
  4. 招聘 timeline: HR 啟動 2 個月內鎖定候選；3-4 個月 onboard
- *HR 挑戰*: 台灣 distributed DB DBA 人才市場估 < 50 人可用；考慮 (i) 海外遠端 (ii) vendor 派遣 (iii) 培養既有 senior MySQL DBA 轉型

### Q5: 跨部門對齊會議 — **memo: 準備材料清單**（未拍時程，僅 memo）

User 拍板「先 memo 材料清單，等準備好再啟動」。

#### A. 共用 pre-read (6 件)
| # | 材料 | 工時 | 狀態 |
|---|---|---|---|
| A1 | 本 minutes (2026-06-09-distributed-db-adoption-non-technical.md) | done | ✓ |
| A2 | PoC Technical Report (30+ pg, 三家完整對比) | 3-5d | 須整合 results/README.md + PoC-DESIGN.md |
| A3 | Executive Summary (1-2 pg, 高階管理者用) | 1d | 從 A2 抽 |
| A4 | Risk Register | 1d | 新寫 |
| A5 | Decision Matrix (3 vendor × 8 軸) | 0.5d | 新寫 |
| A6 | FAQ + Glossary | 0.5d | 新寫 |

#### B. CTO 戰略 (3 件)
| # | 材料 | 工時 |
|---|---|---|
| B7 | 5-yr distributed DB Roadmap | 1d |
| B8 | Vendor Landscape Report (商業背景/財務/客戶 case) | 1-2d |
| B9 | Business case slides (Q1 業務必要性 + Q4 擴編) | 1d |

#### C. Infra 基礎建設 (4 件)
| # | 材料 | 工時 |
|---|---|---|
| C10 | 架構圖 現行 vs proposed (含 multi-rack DR) | 1d |
| C11 | 5-yr capacity plan | 1-2d |
| C12 | Network requirements (multi-rack VLAN + 未來 IDC↔GCP) | 0.5d |
| C13 | Backup / DR plan | 1d |

#### D. 應用 Migration (4 件)
| # | 材料 | 工時 |
|---|---|---|
| D14 | 應用棧 inventory (MySQL/PG/Oracle 占比；PG<5% 已知) | 0.5-1d |
| D15 | Migration complexity matrix (per app SQL/ORM/SP/trigger 評估) | 2-3d |
| D16 | Pilot candidate list (3-5 個低風險 app) | 1d |
| D17 | SQL 方言 caveat list (TiDB vs MySQL/PG) | 0.5d |

#### E. CFO 財務 (4 件)
| # | 材料 | 工時 |
|---|---|---|
| E18 | 5-yr TCO Matrix (self vs managed × 3 vendors) | 2d (含詢價) |
| E19 | Capex vs Opex breakdown | 1d |
| E20 | Risk-adjusted ROI | 1-2d |
| E21 | Budget timing (Q4 編列 → 隔年 H1 pilot kickoff) | 0.5d |

#### F. 法務 / Compliance (4 件)
| # | 材料 | 工時 |
|---|---|---|
| F22 | 個資跨境 pre-review brief (Q3 No 但中長期 nice-to-have) | 1-2d |
| F23 | Vendor 商業實體 background (中資 / BSL / 終止條款) | 1d |
| F24 | Contract risks list (SLA 違約/vendor 倒/lock-in) | 0.5d |
| F25 | Audit / compliance readiness | 1d (與 Audit 確認) |

#### 總計
25 件 / ~24-32 工作天（多人並行可縮 ~3 週）

#### Critical Path
| Phase | wall-clock |
|---|---|
| Week 1: 共用 A + CTO B | 1 週 |
| Week 2-3: Infra C + 應用 D + CFO E + 法務 F (並行) | 2 週 |
| Week 4: Review + 整合 + pre-read 發放 | 1 週 |
| Week 5: 第一次 working session (alignment meeting) | T+5 週 |

### Q6: PoC report 對內 / 對外版本 — **(a) 拆 3 份**
- Technical Report（DBA/SRE/應用 用，30+ pg 完整版）
- Executive Summary（CTO/CFO 用，1-2 pg）
- Vendor Briefing（需求面而非結果面，給 3 家 vendor）

### Q7: Vendor 正式詢價 — **(c) No, 狀態未明不詢價**
- 與 Q14 (all-in TiDB) Unknown 連動
- Q5 對齊會議拍板前不啟動詢價
- E18 TCO Matrix blocked until Q7 解 lock

### Q8: TLS / at-rest encryption PoC 補測 — **No, 不補**
- 不啟動 9h 補測
- PoC report 寫 caveat-only：「production TLS 預估 -5-15%」（可選擇加 or 不加）

### Q9: Sharded MySQL baseline 補測 — **No, 不需**
- 不啟動 3-5 day 補測
- 不在 PoC report 中加「未對照」caveat（user 不需要）

### Q10: Pilot 試點應用 — **未定 / 待更多資料**
- memo: 應用主管尚未介入；等 Q5 對齊會議啟動後由應用 leader 提名候選
- Action item: 跨部門對齊會議後 30 天內收集 3-5 個 pilot 候選

### Q11: distributed DB on-call rotation 是否獨立 — **No 不拆**
- 混入現有 RDBMS rotation
- runbook 仍需獨立寫（distributed DB 故障場景與 RDBMS 不同），但 rotation 同班
- Risk: pager fatigue 接受；如 incident 太頻繁則 re-evaluate

### Q12: Q4 預算編列窗口 — **(c) 不動作, pilot 狀態未明**
- 整體計畫延後 12 個月（2027 Q4 預算窗口）
- 利用延後時段：補 Q14 背書資料、Q5 對齊會議籌備、A1-F25 材料整合
- Risk: 業務面若 2027 H1 真的撞單機天花板 → 緊急採購流程接受

---

## 10. 全 14 題 user 拍板 summary（2026-06-09）

| Q | Decision | Action / Status |
|---|---|---|
| Q1 業務必要性 | Yes + Likely | 推進；補 RDBMS scale 上限盤點 |
| Q2 Vendor 排除 | 三家齊評 | 補 §9 維運後勤表 |
| Q13 PG→TiDB | TiDB 著重（PG<5%）| TiDB 為首選 |
| Q14 all-in TiDB | **Unknown**（資訊不足）| **補 5 項背書 4-6 週**：(1) PingCAP 商業實體 (2) 中資政策 (3) 5-yr TCO 對比 (4) reference call (5) all-in vs dual-vendor 量化 |
| Q3 跨區 DR | No 現行 + 中長期必需 | 10 周邊規劃；phase-crossregion framework 保留 |
| Q4 DBA 擴編 | (a) 擴編 + self-managed | 招 1-2 senior + 既有訓練 |
| Q5 對齊會議 | **memo 材料清單**（25 件 / 24-32 工作天）| 未拍時程，等準備 |
| Q6 PoC report | (a) 拆 3 份 | DBA 主導 |
| Q7 詢價 | No 不啟動 | Q14 解 lock 後啟動 |
| Q8 TLS 補測 | No | report caveat-only 可選 |
| Q9 sharded MySQL 對照 | No | 不在 report 加 caveat |
| Q10 Pilot 應用 | 未定 | Q5 對齊後 30 天收候選 |
| Q11 on-call 獨立 | No 不拆 | 混入既有 + runbook 獨立 |
| Q12 預算 Q4 編列 | (c) 不動作 | 延後 12 個月，2027 Q4 編列 |

---

## 11. Critical Path 收斂版（user 拍板後）

```
T+0:  user 拍板 (14 題已完)
T+1 月: 補 Q14 背書資料 (1/5: 5-yr TCO 詢價; vendor 訪談; HR/法務 vendor 政策)
T+1.5 月: Q14 背書資料完整收齊 + 重議 all-in TiDB
T+2 月: 啟動 Q5 對齊會議材料準備 (25 件 / 並行 3 週)
T+2.5 月: 第一次 working session (CTO + Infra + 應用 + CFO + 法務)
T+3 月: 對齊會議拍板 Q14 / Q10 Pilot 應用 / Q12 預算啟動
T+5 月: Q7 vendor 正式詢價 + RFP
T+6 月: HR 招 senior DBA + 既有 DBA 訓練 plan
T+9 月: 2027 H1 預算審批 (or 緊急流程)
T+12 月: Pilot kickoff
```

加上 5-yr roadmap，總計  pilot → production 約 18-24 月（保守路線）。

---

## 變更歷史

| 日期 | 變更 |
|---|---|
| 2026-06-09 | 初稿（draft v1）— sub-agent ab18210067fd25784 起草，主 agent 整合寫入 |
| 2026-06-09 | §8 user Q&A 紀錄開始 — Q1 拍板 Yes+Likely |
