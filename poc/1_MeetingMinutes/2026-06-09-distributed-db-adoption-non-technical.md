# 2026-06-09 分散式資料庫導入：非技術討論 minutes

> Status: **14 Q&A 已拍板**（2026-06-09 互動式 session；初稿 commit cdb13e3）
> 涵蓋：戰略 / Vendor 政策 / 組織人力 / 成本預算 / 合規 / 遷移風險 / DR / 變更管理 / 採購 / 對外溝通

---

## 1. 緣起

PoC 已完成 4 phase（S-BASE 全 cell N=1 / T-THRD spec / S-K8S 6 cell / X-CROSS 規劃拍板）。**技術面已成熟**，transition 至「該不該真正導入營運」需組織與業務層級對齊；本文件為起點。

## 2. 9 軸非技術討論面向

| # | 軸 | 主要決策 | 對應 Q |
|---|---|---|---|
| 1 | 戰略需求 | 5 年 OLTP 是否超出單機 RDBMS 能力？ | Q1 |
| 2 | Vendor 政策 | 排除哪些（中資 / BSL / 規模 / 商業實體）？ | Q2, Q13, Q14 |
| 3 | 組織 / 人力 | DBA 擴編 vs vendor managed cloud？ | Q4 |
| 4 | 成本 / 預算 | 5 年 TCO（授權 + egress + 人力）| Q7, Q12 |
| 5 | 合規 / 法規 | 跨境個資 / 資料留存 / 稽核 | Q3, Q6 |
| 6 | 遷移風險 | 既有 MySQL / PG / Oracle SQL 方言相容 | Q8 |
| 7 | DR / BC | 跨區 RTO / RPO 是否 hard requirement | Q3 |
| 8 | 變更管理 / SRE | DBA workflow paradigm shift；on-call | Q11 |
| 9 | 採購 / 對外溝通 | 預算編列、stakeholder 對齊、報告呈現 | Q5, Q6, Q12 |

---

## 3. 14 Q&A 拍板紀錄（2026-06-09）

### 戰略 / Vendor

**Q1**：業務必要性 — ✅ **Yes + Likely**
   - distributed DB 需求成立（部分 hard requirement 已存在）；仍需盤點現有 RDBMS vertical scale + read replica 上限作對照

**Q2**：Vendor 排除政策 — ✅ **三家齊頭評估**
   - 公司無「禁止中資 / 排除 BSL / 排除私募」硬政策；fair compare
   - 維運 / 後勤層次對照詳 §4

**Q13**：PG 應用導入 TiDB 可行性 — ✅ **TiDB 著重**（MySQL 相容性為主）
   - 公司現行業務 MySQL stack 為主，PG stack < 5%
   - 推論：TiDB 為首選；PG-stack 5% 應用列為「不導入 distributed DB」或獨立評估

**Q14**：all-in TiDB 公司樂見否 — ⚠️ **Unknown / 資訊不足**
   - 拍板理由：DBA 持有資訊不足以上 CTO / IT 治理委員會
   - 阻塞：缺商業實體狀態 / 中資政策依據 / 5-yr TCO 對比 / reference call / dual-vendor 量化共 5 項背書
   - 動作：啟動「Q14 預備工作」4-6 週（詳 §5）

### 組織 / 成本

**Q4**：DBA 擴編 + self-managed — ✅ **(a) 擴編 + self-managed**
   - 保留 know-how / 長期成本較低 / vendor lock-in 風險低
   - JD：senior DBA × 1-2；HR 2 個月內鎖定、3-4 個月 onboard
   - 既有 DBA 訓練：TiDB Univ / Cockroach U / Yugabyte U + vendor workshop ~10-20 day

**Q7**：Vendor 正式詢價 — ✅ **(c) No 不啟動**
   - 與 Q14 Unknown 連動；Q5 對齊會議拍板前不詢價

**Q12**：Q4 預算編列窗口 — ✅ **(c) 不動作 / pilot 狀態未明**
   - 整體計畫延後 12 個月（2027 Q4 預算窗口）；利用延後時段補 Q14 背書 + Q5 對齊籌備
   - Risk：業務若 2027 H1 撞單機天花板 → 緊急採購流程接受

### DR / 合規 / 遷移

**Q3**：跨區 IDC↔GCP DR — ✅ **No（現行）/ 中長期必需**
   - 拍板理由：distributed DB 導入 focus 在 IDC，累積維運經驗與架構穩定性
   - **phase-crossregion 處置**：framework 保留作能力儲備（5 GCP VM iac + tidb-vm6 ansible + placement SQL + dry-run gate + chrony gate）；**不 destroy** commit 0c17ae9；業務面 ready 時隨時啟動
   - 衍生 10 項周邊規劃詳 §6

**Q8**：TLS / at-rest encryption 補測 — ✅ **No 不補**（降權，**可補 caveat-only**）
   - 不啟動 9h 補測；PoC report 寫 caveat：「production TLS 預估 −5 ~ −15%」（可選加）

**Q9**：sharded MySQL baseline 補測 — ✅ **No 不需**
   - 不啟動 3-5 day 補測；report 不加「未對照」caveat

### 採購 / 溝通 / 對外

**Q5**：跨部門對齊會議 — 📝 **memo 材料清單**（未拍時程）
   - User 拍板「先準備材料、後啟動」；25 件材料 ~24-32 工作天（並行可縮 ~3 週）詳 §7

**Q6**：PoC report 對內 / 對外版本 — ✅ **(a) 拆 3 份**
   - Technical Report（DBA/SRE/應用，30+ pg）
   - Executive Summary（CTO/CFO，1-2 pg）
   - Vendor Briefing（需求面，給 3 家 vendor）

**Q10**：Pilot 試點應用 — ⏳ **未定 / 待更多資料**
   - 應用主管尚未介入；Q5 對齊會議後 30 天內收集 3-5 個候選

**Q11**：distributed DB on-call rotation 獨立否 — ✅ **No 不拆**
   - 混入現有 RDBMS rotation；runbook 獨立寫；如 incident 頻繁則 re-evaluate

**Q12（報告呈現形式）**：給誰看 + 多深 — ✅ **三層皆做**（不同 audience）
   - BOD summary（1-2 pg）/ executive deep dive（10 pg）/ technical detail（30+ pg）

---

## 4. Vendor 維運 / 後勤對比

| 維度 | TiDB (PingCAP) | CockroachDB (Cockroach Labs) | YugabyteDB (Yugabyte Inc.) |
|---|---|---|---|
| 24×7 SLA | enterprise OK | premium OK | platinum OK |
| 中文文件 / 中文支援 | ✓ 完整中文團隊 | ✗ 僅英文 | △ 部分中文 |
| 台灣 partner / reseller | ✓ 多家 | ⚠️ 無 | ⚠️ 無 |
| on-prem enterprise | ✓ TiDB Enterprise Server | ✓ self-hosted Enterprise | ✓ self-hosted Enterprise |
| Critical CVE SLA | 1-2 週 | 1-2 週 | 1-4 週 |
| Major LTS 支援週期 | 18-36 月 | 12 月 | 24-36 月 |
| 顧問費 daily rate | $1.5-3k AP | $2.5-5k US | $2-4k US |
| 台灣客戶 case | ✓ 中信 / 富邦 / 玉山 / 台達 | ⚠️ 無公開 | ⚠️ 無公開 |
| Commercial status | 私募 Series F；2024 裁員 ~20% | IPO filed；2024 營收 ~150M cash burn | 私募 Series C；近兩年動態低調 |
| 授權純度 | OSS + Enterprise | BSL+ELv2（有 use 限制） | Apache 2.0 OSS + Enterprise 可選 |

### Vendor 評估下一步建議（Q14 預備工作觸發）

1. 三家詢價 SPIN（cluster scale + tier + 5-yr quote）— 1 週
2. 維運 ecosystem demo（installer / monitoring / DR / upgrade）— 各 1 週
3. 客戶 reference call（台灣優先）— 3-4 週
4. CVE / EOL 政策書面承諾 — 2 週

---

## 5. Q14 預備工作（補背書 4-6 週）

| # | 背書資料 | Owner | 工時 |
|---|---|---|---|
| 1 | PingCAP 商業實體最新狀態（2026 Q1/Q2 財務、客戶留存率、裁員後組織恢復）| 採購 + 法務 | 1-2 週 |
| 2 | 中資 vendor 在「敏感系統採用清單」之政策依據（HR / 法務 / Audit 三方共識）| HR + 法務 | 2 週 |
| 3 | TiDB enterprise license 5-yr TCO vs CRDB / YBDB 實際報價（Q7 觸發） | 採購 + DBA | 3-4 週 |
| 4 | 三家在台客戶 reference call 結果（特別大型金融 / 電商）| 採購 + DBA | 3-4 週 |
| 5 | all-in vs dual-vendor 維運成本量化（人力 / 訓練 / on-call）| DBA + Infra | 1-2 週 |

**收齊後重議 Q14**（all-in TiDB 是否上 CTO / IT 治理委員會）。

---

## 6. Q3 衍生 — IDC-first + cross-region 中長期 周邊規劃

| # | 項目 | 啟動時機 |
|---|---|---|
| 1 | IDC 內多機房 DR（multi-rack / AZ）— RF=3 對應不同機櫃 / 電源組 | pilot 同期 |
| 2 | IDC backup → GCS / S3 冷備（非 active DR）— TiDB BR / cockroach backup / yb-admin → S3 | pilot + 3-6 月 |
| 3 | observability 跨區（metrics / log ship 到 GCP）— Prometheus / Grafana federation | pilot 同期 |
| 4 | DBA cross-region lab 訓練 — phase-crossregion framework 跑 lab，不上 prod | DBA 擴編後 |
| 5 | 法務 / 個資跨境 pre-review — 個資法 / GDPR / 資料留存預先 review | 跨部門對齊後 |
| 6 | CFO cross-region cost model 教育 — egress / replicate / storage 預估 | 跨部門對齊後 |
| 7 | Vendor 詢價含 multi-region SLA — enterprise tier 必含 | vendor 詢價同步 |
| 8 | 網路架構規劃（IDC↔GCP VPN / Cloud Interconnect）— IT / Network team 預想 | pilot + 6 月 |
| 9 | 應用 DB 連接抽象層（proxy / connection string config）— 未來改 multi-region 不改 app code | pilot 同期（**必做**）|
| 10 | Chaos engineering 先在 IDC 練 — 跨機櫃 node down / network partition lab | pilot + 1 月 |

---

## 7. Q5 對齊會議材料清單（25 件 / 並行 ~3 週）

| 區塊 | 件數 | 範例 |
|---|---|---|
| A. 共用 pre-read | 6 | PoC overview / technical report 30+ pg / executive summary 1-2 pg / risk register / decision matrix / FAQ |
| B. CTO 戰略 | 3 | 5-yr roadmap / vendor landscape report / business case slides |
| C. Infra 基礎建設 | 4 | 架構圖 現行 vs proposed / capacity plan / network requirements / backup-DR plan |
| D. 應用 migration | 4 | 應用棧 inventory / migration complexity matrix / pilot candidate list / SQL 方言 caveat list |
| E. CFO 財務 | 4 | 5-yr TCO matrix / capex vs opex / risk-adjusted ROI / budget timing |
| F. 法務 / Compliance | 4 | 個資跨境 pre-review / vendor 商業實體 background / contract risks / audit readiness |

**Critical path**（並行可縮 ~3 週）：

- Week 1：A 共用 + B CTO
- Week 2-3：C / D / E / F 並行
- Week 4：Review + 整合 + pre-read 發放
- Week 5：第一次 working session

---

## 8. 利害關係人對齊表

| Stakeholder | 對齊狀態 | 下次 sync 內容 |
|---|---|---|
| CTO | ❓ 未啟動 | Q1 戰略 / Q2 vendor 政策 |
| Infra 主管 | ❓ 未啟動 | Q4 self vs managed / Q7 預算 |
| DBA 主管 | ✓ PoC own | 全部議題（PoC 主導者）|
| SRE 主管 | ❓ 未啟動 | Q4 on-call / Q8 變更管理 |
| 應用開發主管 | ❓ 未啟動 | Q8 遷移風險 / Q13 PG→TiDB |
| CFO / 採購 | ❓ 未啟動 | Q7 5-yr TCO / Q14 all-in TiDB |
| 法務 / Compliance | ❓ 未啟動 | Q3 跨境個資（中長期）|
| Audit | ❓ 未啟動 | Q5 稽核日誌 |
| 業務（各 BU） | ❓ 未啟動 | Q1 業務必要性 / Q3 SLA |

---

## 9. Critical Path 收斂版

```
T+0:    user 拍板 (14 題已完, 2026-06-09)
T+1 月: 補 Q14 背書資料 (1/5: 5-yr TCO 詢價; vendor 訪談; HR/法務 vendor 政策)
T+1.5月: Q14 背書資料完整收齊 + 重議 all-in TiDB
T+2 月: 啟動 Q5 對齊會議材料準備 (25 件 / 並行 3 週)
T+2.5月: 第一次 working session (CTO + Infra + 應用 + CFO + 法務)
T+3 月: 對齊會議拍板 Q14 / Q10 Pilot 應用 / Q12 預算啟動
T+5 月: Q7 vendor 正式詢價 + RFP
T+6 月: HR 招 senior DBA + 既有 DBA 訓練 plan
T+9 月: 2027 H1 預算審批 (or 緊急流程)
T+12月: Pilot kickoff
```

加上 5-yr roadmap，pilot → production 總計約 18-24 月（保守路線）。

---

## 10. 14 題 summary

| Q | Decision | Action / Status |
|---|---|---|
| Q1 業務必要性 | Yes + Likely | 推進；補 RDBMS scale 上限盤點 |
| Q2 Vendor 排除 | 三家齊評 | §4 維運後勤表已備 |
| Q3 跨區 DR | No 現行 + 中長期必需 | §6 10 周邊；phase-crossregion framework 保留 |
| Q4 DBA 擴編 | (a) 擴編 + self-managed | 招 1-2 senior + 既有訓練 |
| Q5 對齊會議 | memo 材料清單 | §7 25 件，未拍時程 |
| Q6 PoC report | (a) 拆 3 份 | DBA 主導 |
| Q7 詢價 | No 不啟動 | Q14 解 lock 後啟動 |
| Q8 TLS 補測 | No（降權）| report caveat-only 可選 |
| Q9 sharded MySQL | No | 不在 report 加 caveat |
| Q10 Pilot 應用 | 未定 | Q5 對齊後 30 天收候選 |
| Q11 on-call 獨立 | No 不拆 | 混入既有 + runbook 獨立 |
| Q12 預算 Q4 編列 | (c) 不動作 | 2027 Q4 編列；report 三層皆做 |
| Q13 PG→TiDB | TiDB 著重（PG<5%）| TiDB 為首選 |
| Q14 all-in TiDB | **Unknown** 資訊不足 | §5 補 5 項背書 4-6 週 |

---

## 變更歷史

| 日期 | 變更 |
|---|---|
| 2026-06-09 | 初稿 + 14 Q&A 拍板（commit cdb13e3）|
| 2026-06-15 | §3.2 / §3.10 / Q12 三節縮減（commit 85825a0）|
| 2026-06-15 | 整體結構重組：移除 §3 各軸詳述 / §5 預測答 / §6 推薦下一步 / §7 references（已被 §3 拍板紀錄覆蓋）；保留 §4 vendor 表、§5 Q14 預備工作、§6 Q3 衍生 10 項、§7 Q5 材料清單、§8 利害關係人、§9 critical path、§10 summary |
