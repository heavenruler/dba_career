---
marp: true
theme: default
paginate: true
size: 16:9
header: '多寫多讀混合雲：Y25 結案 × Y26 PoC 決策'
footer: '2026-08-27'
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
  section.tight table { font-size: 14px; }
  section.mid table { font-size: 16px; }
  section.map { font-size: 19px; }
  code { font-size: 0.9em; }
---

<!-- _class: lead -->

# 多寫多讀混合雲
## Y25 結案 × Y26 PoC 決策

2026-08-27 ・ SSD 技術審查

---

# 今天要回答的三個問題

1. **為什麼目標從 A/A 調整為 A/S → A/A-RO？** 釐清 Y25 既有成果與 Y26 實測限制。
2. **各資料庫適合什麼應用情境？** 依協定相容性、延遲、擴展、可用性與維運成本分群判斷。
3. **下一步如何落地？** 以 TiDB 為 MySQL 主線，依序完成 Phase 0、Pilot、A/S 與 A/A-RO 驗收。

> 本次重點：從「技術能不能做」轉向「業務是否需要、應用是否適配、投入是否值得」。

---

<!-- _class: lead -->

# 北極星

---

# 北極星｜同一個目標的三個高度

| 高度 | 表述 |
|---|---|
| **策略層** | 填補 **Cloud Foundation Layer** 技術缺口 —— 隔離「應用程式」與「基礎建設」的直接關連，讓應用程式具有可攜性 |
| **業務層** | 期待未來達到 **104 封站時，使用關鍵服務的客戶不受影響** |
| **維運層** | 「**停機維護是 104 的事，不影響到客戶使用權益**」 |

**Y25 訂下的七條原則**

1. 不因任何一 Region or DC 維護或作業而封站　2. 多地多機房可解析、引導流量就近存取
3. 不因 DC 間 Latency / Delay 產生影響　4. 減少 RD 重構工程完成資料庫架構重構
**5. 如果能 Multi Write 就不考慮 Major Write + Multi Read**
6. 清楚掌握 Cross DC 的 Latency / 2PC issue　7. 避免過度設計

---

# 北極星｜Y26 驗證後的唯一修正：原則 5

**原則 5 保留為目標，實務終點修正為 A/A-RO**

Y26 PoC 驗證後確認：**Multi Write（雙區同時寫入）受周邊 Infra 架構限制，在可見期內不可達**。

| | 原訂 | 修正後 |
|---|---|---|
| 寫入 | 雙區同時寫（A/A） | **單寫，集中 IDC（A/S）** |
| 讀取 | 雙區讀 | **雙區讀，EDC 就近讀（A/A-RO）** |
| 業務目標達成 | ✅ | **✅ 同樣達成** |

原則 **1／2／3／6 完整成立**；原則 5 降為長期目標，不是本輪交付。

> 客戶在任一機房維護時仍可讀取；寫入路徑集中且一致性可保證。

---

<!-- _class: lead -->

# Y25 結論

---

# Y25｜三大範疇驗證小結

| 範疇 | 做法 | 小結 |
|---|---|---|
| **分散式資料庫與 MQ** | ac-api 流量鏡像整合測試，驗證跨雲資料同步的可靠性與效能 | 配合新增 AI 專案調整資源配置，**Y25 測至 STG** |
| **跨機房分流機制** | 建立測試用對外應用程式 `whereami`，實測多區域流量分配 | **8/M Cloudflare LB 通過**，符合分流及 ip sticky 需求；**F5 未能滿足** |
| **其他 SSD 組件** | 多雲環境所需基礎設施組件內部驗證 | **10/B 完成 PROD 環境內部驗證，無議題** |

**資料庫觀測結果**

1. **TiDB 在多寫多讀架構上表現出優勢** —— 跨區回應速度落差小、無漏寫或寫錯、比 ProxySQL+MariaDB 快
2. **跨機房使用類似 DX 之專線服務是必要投資**
3. **具備部分代表性** —— 能處理 AC 最複雜寫入場景；未擴大流量測試，預期可水平擴展應對

---

<!-- _class: mid -->

# Y25｜SSD 自行驗證組件：盤點原則與排程

**盤點原則**

- 確認地端 Infra 組件功能或已知應用情境，雲端是否能滿足；若否則確認解決方案 —— **解決方案不一定需滿足多寫多讀**
- 考量 POC 搭配少數關鍵產品測試，不會測到所有情境，會盡可能在可測範圍做情境驗證
- 除資料庫預期搭配流量鏡像測試，**其他項目由 SSD 自行做功能驗證**

**驗證排程** —— 除 MongoDB 排 Y26，其餘皆於 Y25 完成

| 單位 | 驗證標的 | 排程 | | 單位 | 驗證標的 | 排程 |
|---|---|:---:|---|---|---|:---:|
| HVM | 外部 DNS | Y25 | | NET | Firewall | Y25 |
| HVM | 內部 DNS | Y25 | | **DBA** | **MongoDB** | **Y26** |
| HVM | Proxy | Y25 | | SE + Search | Search | Y25 |
| HVM | NTP | Y25 | | SE | OMS | Y25 |
| NET | GSLB | Y25 | | SE + TSD | Vault | Y25 |
| NET | SLB | Y25 | | | | |

---

# Y25｜SSD 不驗證項目（明確排除）

| 單位 | 標的 / 應用情境 | 不驗證原因 |
|---|---|---|
| SE | OMS 寫檔寄信 | 未來都轉 SMTP；SMTP 已在目前驗證範圍 |
| SE | Assessment | 網站設計過時、**無法支援 AA mode**、未來不續存；**為產品端需處理問題** |
| SE | Memcache | **無法支援 AA mode**、未來不續存，預期轉移至 Redis |
| SE | **AP** | 未來都轉入 K8s 即享快速遷移部署之機制 |
| HVM | NetApp | 檔案規劃以 MVS 作為主要存儲媒介 |
| HVM | VMWare | 已確認有對應雲端服務可訂閱 |
| HVM | Pure Storage | 已確認有對應雲端服務可訂閱 |
| **DBA** | **Redis** | **待有實際需求發生時再規劃安排** |

> 這張表同時是「A/A 為何不可達」的主要依據 —— **無法支援 AA mode 的組件都不在資料庫層**。

---

<!-- _class: map -->

# Y25｜預期的混合雲樣貌轉變過程

| 期間 | 可觀測性與 API 架構 | IT 基礎建設 | 預期結果 |
|---|---|---|---|
| **2024** | Service Mesh 讓 K8s 應用取得服務拓樸圖 | AC 雲地都部署，資料**一寫多讀** | IDC 失效時 AC 服務降級，關鍵服務受影響變小 |
| **2025–2026** | 拓樸資料識別潛在弱點；Grafana Loki 投入 | 多寫多讀技術選型及架構規劃，範圍選定**分散式 RDBMS**、**RabbitMQ** | 對可行性與功能範圍探索與學習 → 確認技術架構對本司應用程式是否可行 |
| **2026–future** | **因應 AI Agent Task Force 調整** | **因應 AI Agent Task Force 調整** | 累積日常維運經驗並進行災難演練 → **IDC 機房失效時 AC 持續運作不降級** |

---

# Y25｜留給 Y26 的三個既成事實

| # | 事實 | 對 Y26 的意義 |
|---|---|---|
| **1** | **ac-api 已完成應用層多寫改造並通過測試**<br>AUTO_INCREMENT→ULID 四步驟、pid/idno 改變型 Snowflake、deadlock 與 pdo 連線錯誤已解<br>2026-08-20 MySQL 複測通過、08-26 TiDB 測試通過 | 應用層改造的方法論**已驗證可行**，不是未知數 |
| **2** | **跨機房分流機制已備妥**<br>Cloudflare LB 通過分流與 ip sticky 驗證（F5 出局） | **A/S 的流量導向前提已成立** |
| **3** | **ATS Pro 已回到 Single Write**<br>多寫的 deadlock 影響上線，2025-11-19 定案 | 產品可在單寫架構下**先上線，不必等主線遞進** |

---

<!-- _class: lead -->

# Y26 PoC 結論

---

# Y26｜候選與定位區隔

Y26 PoC 立項時的候選是三家分散式 SQL；**MySQL Galera（PXC 8.4）於 2026-08 補測進來作為對照基準**。

| 代號 | 候選 | 協定 | 定位 |
|---|---|---|---|
| **A** | MySQL Galera Cluster（PXC 8.4） | MySQL | **單寫 / 單機房場景的有效選項**，不擔任多寫多讀 |
| **B** | **TiDB** | MySQL | **多寫多讀路線的主要候選** |
| **C** | YugabyteDB | PostgreSQL | 備選，待業務出現 PostgreSQL／高關鍵度需求 |
| **D** | CockroachDB | PostgreSQL | 同 C |

**關於 C／D**：協定切換是「能不能直接換」的門檻差異，不是「效能差一點」的程度差異。
公司現行業務以 MySQL 為主，**PostgreSQL 應用佔比 < 5%**（2026-06-09 拍板 D3），目前業務量尚無需考量。

---

# Y26｜A 是定位區隔，不是淘汰

**Galera 的設計**：同步複寫 + certification-based 樂觀併發 —— 為維持 cluster-wide 強一致性，**每筆寫入都必須跨節點認證**。

| 情境 | 這個設計的代價 | 實測 |
|---|---|---|
| **單寫入點** | 幾乎為零（wsrep 近乎空轉） | 單節點 NEW_ORDER p99 **37.7 ms**，四家最快（TiDB 597 ms） |
| **多寫入點** | 隨節點數放大 | 三節點 HAProxy round-robin → 吞吐降到單節點的 **0.49×**（負向擴展） |
| **跨區多寫** | 再疊加 WAN RTT | 跨區單寫 **298.8 tpmC**（TiDB 的 1/41.9）；跨區雙寫 GCP 端失敗率 **47.0%**（PAYMENT 81.5%） |

> **結論**：Galera 繼續作為單寫、單機房、低延遲敏感服務的架構選項；多寫多讀路線由 TiDB 承接。
> 兩者是**定位區隔**，不是取代關係。

---

<!-- _class: mid -->

# Y26｜決策表 ①　業務適配 ・ 應用改造成本

**O** 可行　**X** 不適用或不建議　**△** 有條件可行　**待測** 尚未排入測試矩陣

| 大類 | 細項 | A MySQL | B TiDB | C YBDB | D CRDB | 備註 |
|---|---|:---:|:---:|:---:|:---:|---|
| **A. 業務適配** | 多寫多讀（雙區同時寫） | **X** | **O** | △ | △ | C/D 技術可行但需換協定 |
| | 跨區散置寫入（placement） | X | O | O | O | Galera 原生不支援 |
| | 跨區單寫 + standby（A/S） | △ | O | O | O | A 跨區吞吐僅 298.8 tpmC |
| | 跨區就近讀（A/A-RO） | X | O | O | O | A 無 follower/stale read |
| | 單機房多寫 | △ | O | O | O | A 在 naive multi-writer 下 0.49× |
| | 單機房單寫（現況） | O | O | O | O | A 延遲最優 |
| **B. 應用改造** | 協定不變（免改 driver/ORM） | **O** | **O** | **X** | **X** | A/B 為 MySQL wire |
| | SQL / ORM 相容性矩陣 | 待測 | 待測 | 待測 | 待測 | 四家皆未實測 |
| | ID 生成改造（AUTO_INC→ULID） | 需要 | 需要 | 需要 | 需要 | 分散式共通議題 |
| | 重試 / 錯誤處理量 | **高** | 低 | 低 | 中 | D quorum 遺失回報 `ambiguous` |
| | 既有維運工具鏈可沿用 | O | 待測 | X | X | A 為現況（PMM3 等） |

---

<!-- _class: mid -->

# Y26｜決策表 ②　效能與擴展 ・ 可用性與正確性

| 大類 | 細項 | A MySQL | B TiDB | C YBDB | D CRDB | 備註 |
|---|---|:---:|:---:|:---:|:---:|---|
| **C. 效能擴展** | 單節點延遲（p99） | **37.7 ms** | 597 ms | 216 ms | 440 ms | A 大幅領先 |
| | 水平擴展倍率 | **0.49×** | **2.06×** | 1.37× | 1.65× | 分母與判讀見下頁 |
| | 高併發穩定性（range/mean） | 43.2% | 7.4% | 7.1% | 6.9% | t=128 五輪變異 |
| | all-txn error rate | 0.037% | 0.000% | 0.000% | 0.000% | A 為四家唯一非零 |
| | 跨區單寫吞吐（P-A×A-S） | 298.8 | 12,526.5 | 12,769.5 | 10,163.4 | tpmC, t=128 |
| | 跨區就近讀吞吐（A/A-RO） | n/a | 31,571.3 | 56,787.9 | 41,056.3 | GCP 側 read_tpmTotal |
| **D. 可用/正確** | 單節點 kill 可觀測中斷 | 無 | **6.68–8.4 s** | 無 | 無 | B 為 SQL/共識層分離的體現 |
| | 區域級停止後復原 | 22.2 s | 39–44 s | **3.0 s** | 7.0 s | **口徑不等價**（見備註頁） |
| | quorum 遺失寫入拒絕 | **⚠ 曾非預期成功** | 乾淨拒絕 | 乾淨拒絕 | **⚠ ambiguous** | A/D 需應用層額外處理 |
| | 跨區分斷後自動恢復 | O | 待補 | 待補 | 待補 | A 解除後 20–30 秒 IST/SST |
| | 跨區雙寫 GCP 側失敗率 | **47.0%** | 0.158% | 0.134% | 0.111% | A 高出 B 約 300 倍 |

> 「區域級停止後復原」口徑不等價：A 從 `t_kill` 起算、B 從 `t_restart` 起算（B 從 `t_kill` 為 198–202 s）。

---

<!-- _class: mid -->

# Y26｜水平擴展：倍率的分母與判讀

**指標定義**

```text
水平擴展倍率 ＝ 三節點 HAProxy tpmC ÷ 單節點 tpmC
```

| 資料庫 | 單節點 tpmC | 三節點 tpmC（t=128） | 增減幅 | 擴展倍率 |
|---|---:|---:|---:|---:|
| **A** MySQL Galera | 53,791.9 | 26,166.2 | **−51%** | **0.49×** |
| **B** TiDB | 13,064 | 26,947 | **+106%** | **2.06×** |
| **C** YugabyteDB | 11,436 | 15,632 | +37% | 1.37× |
| **D** CockroachDB | 9,134 | 15,033 | +65% | 1.65× |

**判讀**　`> 1×` 加節點後吞吐提高，正向擴展　／　`= 1×` 無增益　／　`< 1×` 加節點後吞吐下降，負向擴展

> Galera 單節點吞吐與延遲占優，但在本次 HAProxy round-robin 多寫配置下呈**負向擴展**；
> TiDB 單節點成本較高，新增節點後能有效提升吞吐。
> **注意三節點的絕對吞吐兩者其實接近（26,166 vs 26,947）** —— 倍率描述的是擴展特性，不是跨產品整體排名。

---

# Y26｜決策表 ③　維運後勤

| 大類 | 細項 | A MySQL | B TiDB | C YBDB | D CRDB |
|---|---|:---:|:---:|:---:|:---:|
| **E. 維運後勤** | PITR / 備份還原 | 待測 | 待測 | 待測 | 待測 |
| | Online DDL 與維運工具 | 待測 | 待測 | 待測 | 待測 |
| | HTAP / 分析型負載 | n/a | 待測 | n/a | n/a |
| | 原廠在地支援 | 社群 / Percona | **24×7 中文 + 台灣 SA** | 無在地 | 無在地 |
| | 現有 DBA 技能可承接 | O | △ | X | X |

**E 大類是本輪最大的證據缺口** —— PITR、Online DDL、相容性矩陣三項都還沒有測試檔案，
這三項正是 Phase 0 的全部內容（見實施辦法）。

---

<!-- _class: tight -->

# Y26｜根據目前 TiDB 的評估，我們可以完成的事

| # | 可以完成 | 依據 |
|---|---|---|
| 1 | **跨區資料同步不漏寫、不寫錯** | Y25 ac-api 流量鏡像：挑 AC API 最複雜寫入場景，全程無漏寫或寫錯 |
| 2 | **應用不改協定即可接上** | MySQL wire；ac-api 完成 ULID/Snowflake 改造後，2026-08-26 TiDB 測試直接通過 |
| 3 | **水平擴展** | 1node→3node 擴展倍率 **2.06×**，四家最高；跨區單寫吞吐是 Galera 的 41.9 倍 |
| 4 | **高併發下維持穩定與零錯誤** | t=128 五輪變異 **7.4%**、all-txn error rate **0.000%** |
| 5 | **跨區單寫（A/S）並確保副本真的到位** | P-A×A-S 跨區 W=128 完成，12,526.5 tpmC、0 error；placement + 副本存在 + 近讀 probe 三重驗證 |
| 6 | **跨區就近讀（A/A-RO）** | IDC 側 15,182.5 tpmC、GCP 側 read_tpmTotal 31,571.3、**全程 0 錯誤** |
| 7 | **控制資料放置位置** | Placement Rules 實測：P-A（leader 固定 IDC）與 P-B（跨區 30–70% 混合）皆可設定並驗證 |
| 8 | **quorum 遺失時乾淨拒絕寫入** | `write_correctly_rejected` —— 不會靜默寫入成功 |
| 9 | **跨區雙寫時把錯誤率壓在低檔** | P-B×A-A GCP 側 **0.158%**，型態為跨區鎖等待逾時，非衝突拒絕 |
| 10 | **K8s 部署與資源配額控制** | S-K8S limit/unlimit 六組 suite 完成，含 throttling / OOM / storage 證據 |
| 11 | **取得原廠在地後勤支援** | PingCAP 24×7 中文、Premier S1 30 分鐘 SLA、台灣本地 SA 已到職 |
| 12 | **把 DR 備援資源轉成有產出的資源** | A/S 的 standby 資料端置於 EDC，可承載讀取型商務邏輯 |

---

<!-- _class: tight -->

# Y26｜根據現有架構，我們不能完成的事

**（一）架構層面 —— 短期內無法解除**

| # | 不能完成 | 原因 |
|---|---|---|
| 1 | **端到端雙區同時寫（A/A）** | **限制不在資料庫**。Assessment / Memcache 架構上無法支援 AA mode；OMS 雲端無法代理對外寄信；NetApp 部分檔案無法轉入 MVS |
| 2 | **整區故障秒級自動接手** | RF=3、僅 IDC + EDC 兩個 failure domain，**數學上不保證**。F2 是「停 3 台 IDC process 再由 operator 重啟」的恢復力測試，**不是自動區域 failover**；從 `t_kill` 起算 198–202 秒 |
| 3 | **單節點故障對 client 完全零感知** | TiDB SQL 層與共識層分離，單節點 kill 有 **6.68–8.4 秒**可觀測中斷。是架構特性不是缺陷，但**設計 SLO 時必須納入** |
| 4 | **在低延遲敏感場景取代 Galera** | 單節點 p99 **597 ms** vs Galera **37.7 ms**（15.8 倍） |
| 5 | **Cloudflare + F5 的 sticky session** | 來源 IP 到 F5 只看得到 Cloudflare 的 IP；需改用 Cloudflare LB |
| 6 | **在 GCP 重現 A10 的 Ignore-TCP-MSL** | GCP SLB 無此功能；TSD 已評估影響不大，但無法對等移植 |

---

<!-- _class: tight -->

# Y26｜不能完成的事（續）

**（二）證據層面 —— 補測即可解除**

| # | 尚不能宣稱 | 缺什麼 |
|---|---|---|
| 7 | SQL / ORM 相容性已驗證 | 相容性矩陣未執行；MariaDB 10.4 / 10.11 待原廠線下評估 |
| 8 | 備份可還原、PITR 可用 | 完全未排入測試矩陣（無 spec、無 script、無 artifact） |
| 9 | Online DDL 不影響前台 | 未量測 DDL 期間對 tpmC / p99 的影響幅度與持續時間 |
| 10 | 跨區部署的 WAN 成本是多少 | 缺 IDC-only 六節點 paired control |
| 11 | P-B 高併發吞吐劣化的根因 | th=128 劣化（9003→14948→2113→954→1480），命中 `PessimisticLockNotFound`／`LockTsMismatch`，**未定位根因** |
| 12 | HTAP / 向量檢索可用 | TiFlash 未執行分析型查詢；向量檢索僅原廠說明，本 PoC 無實測 |
| 13 | Failover 數字可跨產品比較 | 各家計時起點不等價，需先統一口徑重測 |

**（三）本輪不做 —— 屬決策而非能力限制**

| # | 不做 | 理由 |
|---|---|---|
| 14 | PostgreSQL 路線（YBDB / CRDB） | PostgreSQL 應用佔比 < 5%；協定切換成本無法由現有效益差距正當化 |
| 15 | Redis 多寫多讀驗證 | 待有實際需求發生時再規劃安排（2025-12-19 定案） |
| 16 | ac-api PROD 整合與流量 mirror | 定案 Y27 再安排 |

---

<!-- _class: mid -->

# Y26｜Placement 對照：P-A vs P-B（同一 workload）

**A/S 是目前唯一 workload 定義完全相同、可直接觀察 placement 差異的軸** —— 兩者皆為 IDC client 128 threads、GCP client 不發負載。

| 指標（TiDB, threads=128） | P-A × A/S | P-B × A/S | 差異 |
|---|---:|---:|---:|
| tpmC | 12,526.5 | **15,107.4** | **P-B +20.6%** |
| NEW_ORDER p99 | 677.8 ms | **664.4 ms** | P-B −2.0% |
| all-txn error rate | 0% | 0% | 相同 |

| Placement | 語意 |
|---|---|
| **P-A** | leader / lease 固定 IDC，EDC 持 1 份 voter 副本 —— commit quorum 留在 IDC，不等 WAN |
| **P-B** | leader 跨區混合分布（IDC / EDC 30–70%） |

> **對 S1 的意涵**：單寫情境下 P-B 不但沒有比較慢，反而較快且 p99 略低。**S1 的 placement 不宜僅憑架構直覺預設 P-A**，須納入此對照評估。
> 跨三家 24 個對照點中 P-B ≥ P-A 為 12/24；但 **TiDB 在 A/S 的四個 thread 檔位全數 P-B 較高**。兩批次日期不同（07-17／07-27），屬階段性觀察。

---

# Y26｜A/A 卡在哪：限制不在資料庫

資料庫層已證明 TiDB 具備雙區寫入能力（跨區雙寫 GCP 側失敗率 0.158%）。**擋住的是周邊 Infra**：

| 層級 | 已知不可行 / 未就緒 |
|---|---|
| **應用組件** | **Assessment 無法支援 AA mode**（設計過時、未來不續存，屬產品端議題）<br>**Memcache 無法支援 AA mode**（未來不續存，預期轉 Redis）<br>OMS 寫檔寄信 —— 雲端無法代理對外寄信 |
| **儲存** | NetApp 檔案規劃以 MVS 為主要存儲媒介，部分檔案無法轉入 |
| **網路** | GCP SLB **無 Ignore-TCP-MSL**；Cloudflare + F5 架構下 **sticky session 無法生效** |
| **故障域** | RF=3、僅 IDC + EDC 兩個 failure domain，整區故障秒級接手**數學上不保證** |
| **專線** | 跨區實測 RTT 8.5 ms、頻寬 190–227 Mbps；「類似 DX 之專線是必要投資」但尚未取得 |

> **資料庫層已經準備好做 A/S 與就近讀；擋住 A/A 的是資料庫以外的組件與故障域數量。**

---

<!-- _class: lead -->

# 推進路線

---

<!-- _class: map -->

# 路線｜三軌並行全景

```
                 【進入條件】                【進入條件】
                 相容性矩陣                  Failover 等價口徑重測
                 PITR / 備份還原             跨區分斷演練
                 Online DDL                  就近讀 staleness 驗證
                      │                           │
主線  S0 IDC Only ────┼──▶ S1 IDC+EDC P-A×A/S ────┼──▶ S2 IDC+EDC P-A×A/A-RO
（技術）  現行         │                           │
                      │                           │        ⛔ S3 P-B×A/A
                      │                           │        不列入本輪
                      ▼                           ▼
branch   B1 Self-Service          B2 DB 申請 CI/CD 平台
（產品）  B4 Observability          B3 EDC 資源活化（A/S 資料端）
                      │                           │
                      ▼                           ▼
後勤     能力缺口盤點 ──▶ 自控驗證項 ──▶ 原廠協作項（不採購）
```

---

# 路線｜技術主線

| 階段 | 內容 | 進入條件 | 驗收 |
|---|---|---|---|
| **S0**<br>IDC Only | TiDB 單區叢集營運，累積維運經驗與架構穩定性 | — | 叢集穩態營運、監控與告警上線、備份可還原 |
| **S1**<br>IDC+EDC<br>**P-A × A/S** | leader/lease 固定 IDC，EDC 持副本；流量只打 IDC | 相容性矩陣、PITR／備份還原、Online DDL **三項補測通過** | EDC 端確實持有資料副本（**副本存在門檻**）、placement 門檻通過、切換演練可回退 |
| **S2**<br>IDC+EDC<br>**P-A × A/A-RO** | EDC 端就近讀，寫入仍集中 IDC | Failover 等價口徑重測、跨區分斷演練、就近讀 staleness 與 fallback 驗證 | near-read probe 全數通過、staleness 在業務可接受範圍、fallback 有效 |
| ⛔ **S3**<br>P-B × A/A | 雙區同時寫入 | **不列入本輪** | 業務提出雙區寫入需求，且非 DB 層阻礙解除後再議 |

> **為何先 A/S 再 A/A-RO**：A/S 只需驗「副本真的到 EDC」與「切得回來」；A/A-RO 才要處理就近讀路由、staleness 語意與 fallback。前者是後者的前置，**兩階段失敗模式完全不同，合併會讓問題無法歸因**。
> **S1 的 placement 待複核**：表列以 P-A 為基準，但 A/S 實測 P-B 較 P-A 高 20.6%（見「Placement 對照」頁），S1 設計時須複核 placement 選擇。

---

# 路線｜產品期待 branch

四條乘載在同一套 TiDB 上，**不卡主線遞進**，可與 S0／S1 並行。

| Branch | 內容 | 依附 | 產品側可感知的價值 |
|---|---|---|---|
| **B1** Database Self-Service | 申請 / 權限 / 配額 / 備份 / 監控 / 退場的完整生命週期 | S0 起 | 把一次性 PoC 轉為**長期平台能力** |
| **B2** DB 服務申請 CI/CD 平台 | RD Self-Managed 流程串接（**不填 Jira 單**即可滿足需求）+ Deploy on K8s 流程 | S0 起 | 縮短交付週期，降低重複申請與維運成本 |
| **B3** EDC 資源活化（A/S 資料端） | A/S 的 standby 資料端置於 EDC，供商務邏輯讀取 | S1 起 | 把 **DR 備援資源轉成有產出的資源**；先挑可移至 EDC 持續運作的定期批次或低風險服務 |
| **B4** Observability / 效能分析 | 以 observability data 做效能分析與容量規劃 | S0 起 | B1 的前置能力；讓**服務恢復時間可量測**而非只有叢集健康燈號 |

> **B3 是 EDC 活化議題的直接出口** —— 不需要等到 A/A，A/S 的資料端就已經可以承載讀取型商務邏輯。

---

<!-- _class: mid -->

# 路線｜維運後勤軌：能力缺口 → 協作需求

TiDB 原廠（PingCAP）對接已完成，**尚無強需求進行採購**，但建議先確立維運後勤支援協作方式。

| 能力缺口 | 自控 / 原廠協作 | 現況 |
|---|---|---|
| PITR / 備份還原 | **自控驗證** | 待測，S1 進入條件 |
| Online DDL 對前台負載影響 | **自控驗證** | 待測，S1 進入條件 |
| SQL / ORM 相容性矩陣 | **原廠提供清單 + 自控驗證** | 原廠已列為 follow-up |
| Self-Managed 訂閱方案細節 | **原廠待補** | 2026-06-11 會議提出，會後補充 |
| 隔離級術語對齊（RR / SI / Serializable） | **原廠釐清** | TiDB 無原生 SERIALIZABLE，設 `tidb_skip_isolation_level_check` 後仍以 RR 行為執行 |
| MariaDB 10.4 / 10.11 相容性 | **原廠線下評估** | 已提出，待回覆 |
| SLA / 事件升級管道 | **先談協作方式，未採購** | 24×7 中文、Premier S1 30 分鐘、台灣本地 SA 已到職 |
| 跨雲連線方式 review | **自控 + 原廠確認** | PoC 走 GCP IAP tunnel；正式導入需 review VPC Peering / Private Link |

---

<!-- _class: lead -->

# 採用 TiDB 的分階段實施辦法

---

# 實施｜Phase 0：技術門檻補件

| 項目 | 內容 |
|---|---|
| **目標** | 補齊決策表 E 大類的三個「待測」項，讓 TiDB 具備可進入生產的完整技術檔案 |
| **工作項** | ① **相容性矩陣**：以現行應用實際使用的 SQL 語法子集、常用 ORM、既有備份/監控工具鏈跑相容性驗證<br>② **PITR / 備份還原**：定義 RPO 目標，實跑全量+增量還原演練<br>③ **Online DDL**：對含資料大表執行 `ADD COLUMN` / `ADD INDEX`，量測對前台負載的 tpmC/p99 影響幅度與持續時間 |
| **原廠協作** | 索取 MySQL 相容性清單、Self-Managed 訂閱方案細節、隔離級術語對齊 |
| **驗收** | 三項皆有可追溯的測試結果；相容性矩陣明列不支援的 SQL 特性與 workaround |
| **退場條件** | 若相容性矩陣顯示現行應用需大幅改寫，**回到決策表重新評估** |

---

# 實施｜Phase 1：代表性應用 Pilot（S0）

| 項目 | 內容 |
|---|---|
| **目標** | 在 IDC Only 架構下，導入一個代表性 MySQL 應用或定期批次，取得應用、維運與服務生命週期證據 |
| **選題原則** | 可驗證隔離與恢復的代表性服務；或故障影響範圍明確的服務；或可移至 EDC 持續運作的定期批次 |
| **協作** | 由 TSD 指派應用 owner，提供真實 SQL / ORM / Driver / Transaction 與改造限制 |
| **同步啟動** | **B1 Self-Service**、**B2 CI/CD 平台**、**B4 Observability** 三條 branch 的最小可用版本 |
| **驗收** | ① 定義使用者可感知的恢復驗收點（**以服務恢復時間取代單一叢集健康燈號**）<br>② **一致性優先**：先驗證一致性、拒寫與恢復，不以持續寫入為唯一目標<br>③ Self-Service 走完一次完整申請→交付→退場流程 |
| **退場條件** | Pilot 效益無法量化，或應用改造量超出 owner 可承擔範圍 |

---

# 實施｜Phase 2：跨區 A/S（S1）

| 項目 | 內容 |
|---|---|
| **目標** | IDC + EDC，leader/lease 固定 IDC，EDC 持副本，流量只打 IDC |
| **前置** | Phase 0 三項補測通過；跨區專線可用性確認（PingCAP 建議副本間延遲 ~10 ms） |
| **工作項** | ① placement 設定與門檻驗證<br>② **副本存在門檻**：逐 region 驗證資料確實到達 EDC，**不能只驗設定存在**<br>③ 切換與回滾演練 |
| **同步啟動** | **B3 EDC 資源活化** —— standby 資料端供商務邏輯讀取 |
| **驗收** | placement 門檻 + 副本存在門檻皆通過；切換演練可回退；EDC 端資料可供讀取型商務邏輯使用 |

> **關鍵教訓**：Y26 PoC 曾發生「設定存在但副本從未實體化」的效度事件 —— zone config 自相矛盾、read-replica 缺 placement_uuid，且探測因缺 DB client **靜默通過**。**驗證門檻必須 fail-closed，不可只驗設定。**

---

# 實施｜Phase 3：跨區就近讀 A/A-RO（S2）

| 項目 | 內容 |
|---|---|
| **目標** | EDC 端就近讀，寫入仍集中 IDC |
| **前置** | Phase 2 驗收通過；**Failover 等價口徑重測完成** |
| **工作項** | ① 就近讀路由設定與 near-read probe<br>② staleness 量測與業務可接受範圍定義<br>③ fallback 機制驗證<br>④ 跨區分斷演練 |
| **驗收** | near-read probe 全數通過；staleness 在業務可接受範圍；分斷後可自動恢復或有明確人工程序 |

> **關鍵教訓**：Y26 PoC 首輪 A/A-RO **近讀未生效** —— 「設定存在」不足以證明就近讀，**必須有執行面證據**。

---

# 實施｜Failover 口徑統一（跨 Phase 的方法論前置）

現行各家 Failover 數字口徑不等價，無法互相比較。**進入 Phase 2 前需先統一**：

| 項目 | 統一口徑 |
|---|---|
| **RTO 起點** | `t_kill`（故障注入時點）到首次成功寫入 |
| **觀測窗** | 禁止人工恢復介入的觀測窗 |
| **探測位置** | 相同探測位置，同時涵蓋 IDC 側與 EDC 側 client |
| **RPO 驗證** | 由相同交易序列驗證 |

**為什麼要先統一**

| 現況 | 問題 |
|---|---|
| Galera G2 從 `t_kill` 起算 = 22.2 s | 兩者的故障注入、恢復流程及計時起點**都不等價** |
| TiDB F2 從 `t_restart` 起算 = 39–44 s（從 `t_kill` 為 198–202 s） | 直接比較秒數會得出錯誤的產品優劣判斷 |
| YBDB 3.0 s / CRDB 7.0 s（另一套方法論） | 三套口徑並存，無法形成單一 SLA 依據 |

---

# 實施｜條件式選項（不列入本輪排程）

| 選項 | 觸發條件 |
|---|---|
| **P-B × A/A（雙區同時寫）** | 業務明確提出雙區寫入需求，**且**非 DB 層阻礙（AA mode 不支援組件、分流 sticky、故障域數量、專線）解除 |
| **PostgreSQL 路線**<br>（YugabyteDB / CockroachDB） | 出現高關鍵度 PostgreSQL 應用或 AI 應用需求；或 TiDB 在 Phase 0 相容性矩陣中被證明不適配 |
| **PXC / Galera 目標式對照** | 出現極低延遲優先的單寫場景，需要與 TiDB 做針對性比較 |

**推進順序總結**

```
Phase 0 補件 ──▶ Phase 1 Pilot（S0）──▶ Phase 2 A/S（S1）──▶ Phase 3 A/A-RO（S2）
                      │                        │
                 B1 B2 B4 啟動              B3 EDC 活化
```

---

<!-- _class: lead -->

# 附錄

---

# 附錄｜實測證據入口

| 文件 | 內容 |
|---|---|
| `poc/refresh/SLIDE-BRIEF-2026.md` | 本簡報底稿（完整版） |
| `poc/refresh/Y25_多寫多讀POC_摘要.md` | Y25 Jira 42 單 + 2601 專案總結簡報彙整 |
| `poc/refresh/DECISION-MATRIX.md` | Y26 四家候選決策表與終點結論 |
| `poc/DISTRIBUTED-DB-SCORING.md` | 四家評分表、加權總分、逐項證據連結 |
| `poc/MILESTONES.md` | 專案歷程、可下／不可下結論、下一決策門檻 |
| `poc/gitbook/` | 17 章結構化交付文件（09 跨區、16 決策框架） |
| `poc/results/` | 原始 `summary.json`、pipeline-log、驗證門檻證據 |
| `poc/phase-crossregion/` | 各 placement × workload 結案報告、chaos/failover 比較 |
| `poc/1_MeetingMinutes/0611-TiDBx104-summary.md` | PingCAP 原廠對接紀錄 |
| `poc/1_MeetingMinutes/2026-06-09-...-non-technical.md` | D1–D4 拍板紀錄（跨區階梯、TiDB 為主路線） |

---

# 附錄｜數字判讀邊界

| 項目 | 邊界 |
|---|---|
| **Failover 秒數** | 各家計時起點不等價：Galera 從 `t_kill`、TiDB 從 `t_restart`。跨產品比較前須統一口徑重測 |
| **跨區數據** | 屬 `X-CROSS` 探索性 scope，與單區 `S-BASE` 拓樸、節點數、quorum 皆不同，**不可互相換算 WAN penalty** |
| **Galera 0.49×** | 本測試刻意用 HAProxy round-robin 製造最大化多寫衝突；改單寫或以 shard key 分流結果可能截然不同 |
| **Galera `Error 1213`** | 型態與「多主複寫衝突」及「InnoDB local deadlock」皆相容；無 wsrep counter delta 佐證無法區分佔比 |
| **加權總分** | MySQL 組（A/B）與 PostgreSQL 組（C/D）驗證方法與協定皆不同，**兩組總分不可互相比較** |
| **P-B TiDB 劣化** | 與跨區鎖競爭假說相容，但各 profile 的 total offered concurrency 與 mix 不同，**非單變量對照，不可視為已確認根因** |
