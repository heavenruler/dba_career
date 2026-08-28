# 多寫多讀混合雲｜Y25 結案 × Y26 PoC 決策彙整

> 用途：slide 產出前的資訊彙整底稿
> 受眾：SSD 技術審查
> 資料來源：`Y25_多寫多讀POC_摘要.md`（Y25 Jira + 2601 專案總結簡報）、`DECISION-MATRIX.md`（Y26 PoC 實測）、`poc/DISTRIBUTED-DB-SCORING.md`、`poc/1_MeetingMinutes/`
> 更新：2026-08-27

---

## 0. 北極星目標（重申）

### 0.1 三層表述

| 高度 | 表述 | 出處 |
|---|---|---|
| **策略層** | 填補 **Cloud Foundation Layer** 技術缺口 —— 隔離「應用程式」與「基礎建設」的直接關連，讓應用程式具有可攜性 | 2601 專案總結簡報 |
| **業務層** | 期待未來達到 **104 封站時，使用關鍵服務的客戶不受影響** | 2601 專案總結簡報 |
| **維運層** | 「**停機維護是 104 的事，不影響到客戶使用權益**」 | PoC 立項（`0400-to-dba.md`） |

### 0.2 Y25 訂下的七條原則

1. 不因為任何一 Region or DC 維護或作業而封站
2. 多地多機房可解析；並引導流量就近存取
3. 不因任何 DC 間 Latency / Delay 產生影響
4. 如狀況允許，在現有商務邏輯下，減少 RD 重構工程完成資料庫架構重構
5. **如果能 Multi Write 就不考慮 Major Write + Multi Read**
6. 清楚掌握 Cross Data Center 的 Latency / 2PC issue
7. 避免過度設計

### 0.3 Y26 PoC 後的修正

> **原則 5 保留為目標，但實務終點修正為 A/A-RO。**

Y26 PoC 驗證後確認：**Multi Write（雙區同時寫入）受周邊 Infra 架構限制，在可見期內不可達**（詳見 §2.3、§2.4.2）。

實務上以 **單寫（A/S）＋ 就近讀（A/A-RO）** 達成同一業務目標 —— 客戶在任一機房維護時仍可讀取、寫入路徑集中且一致性可保證。原則 1／2／3／6 完整成立，原則 5 降為長期目標而非本輪交付。

---

## 1. Y25 結論彙整

### 1.1 Y25 POC 範疇 / 驗證小結

| 範疇 | 做法 | 小結 |
|---|---|---|
| **分散式資料庫（MySQL、TiDB）與 MQ** | 透過 ac-api 流量鏡像整合測試，驗證跨雲資料同步的可靠性與效能表現 | 配合新增 AI 專案調整資源配置，**Y25 測至 STG** |
| **跨機房分流機制** | 建立測試用對外應用程式 `whereami`，實測多區域流量分配的效果與穩定性 | **8/M 完成 Cloudflare LB 測試，符合分流及 ip sticky 需求**；**F5 未能滿足需求情境** |
| **其他 SSD 自行驗證組件功能** | 針對多雲環境所需的各項基礎設施組件做內部驗證 | **10/B 完成 PROD 環境內部驗證，無議題** |

**分散式資料庫觀測結果**

1. **TiDB 作為分散式資料庫，在多寫多讀架構上表現出優勢**
   - 跨區存取回應速度落差小
   - 無任何漏寫或寫錯的紀錄
   - 相較傳統 DB（ProxySQL + MariaDB），處理速度更快
2. **在分散式架構下，跨機房使用類似 DX 之專線服務是必要投資**
3. **本次測試具備部分代表性**
   - 能處理 AC 最複雜的寫入場景，其它單純寫入跟讀取應不太會出錯
   - 雖未擴大流量測試，但預期可透過水平擴展計算或儲存節點來應對

> 代表性邊界：僅涵蓋 4 支特定 API。壓測時 MariaDB 收到近 6K QPS，轉換後內部剩 2K QPS，mirror 到 TiDB 後只剩 113。「灌入 AC API 總量」的驗證因資源挪動未執行。

### 1.2 SSD 自行驗證組件 —— 盤點原則與排程

**盤點原則**

- 確認地端 Infra 組件功能或已知應用情境，雲端是否能滿足；若否則確認解決方案 —— **解決方案不一定需滿足多寫多讀**
- 考量 POC 搭配少數關鍵產品測試，不會測到所有情境，會盡可能在可測範圍做情境驗證
- 除資料庫預期搭配流量鏡像測試，其他項目由 SSD 自行做功能驗證

**排程**

| 確認單位 | 驗證標的 | 排程 |
|---|---|---|
| HVM | 外部 DNS | Y25 |
| HVM | 內部 DNS | Y25 |
| HVM | Proxy | Y25 |
| HVM | NTP | Y25 |
| NET | GSLB | Y25 |
| NET | SLB | Y25 |
| NET | Firewall | Y25 |
| **DBA** | **MongoDB** | **Y26** |
| SE + Search | Search | Y25 |
| SE | OMS | Y25 |
| SE + TSD | Vault | Y25 |

### 1.3 SSD 不驗證項目（明確排除）

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

> 這張表同時是 §2.3「A/A 為何不可達」的主要依據 —— 表中已明確標示無法支援 AA mode 的組件，都不在資料庫層。

### 1.4 Y25 預期的混合雲樣貌轉變過程

| 期間 | 網站可觀測性與 API 架構改善 | IT 基礎建設 | 預期結果 |
|---|---|---|---|
| **2024** | 使用 Service Mesh 讓 K8s 應用程式獲得服務拓樸圖 | AC 雲地都部署，資料**一寫多讀** | IDC 失效時 AC 服務降級，關鍵服務受影響變小 |
| **2025–2026** | 拓樸資料識別潛在弱點並提出改進；Grafana Loki 投入使用 | 多寫多讀技術選型及架構規劃，範圍選定**分散式 RDBMS**、**RabbitMQ** | 對多寫多讀架構的可行性跟功能範圍進行探索與學習 → 確認技術架構對本司應用程式是否可行 |
| **2026–future** | **因應 AI Agent Task Force 調整內容** | **因應 AI Agent Task Force 調整內容** | 累積多寫多讀架構的日常維運經驗並進行災難演練 → **AC 多地部署、多寫多讀，當 IDC 機房失效時 AC 能持續運作不降級** |

### 1.5 Y25 留給 Y26 的三個既成事實

| # | 事實 | 對 Y26 的意義 |
|---|---|---|
| 1 | **ac-api 已完成應用層多寫改造並通過測試** —— AUTO_INCREMENT→ULID 四步驟、pid/idno 改變型 Snowflake、deadlock 與 pdo 連線錯誤已解，2026-08-20 MySQL 複測通過、08-26 TiDB 測試通過 | 應用層改造的方法論已驗證可行，不是未知數 |
| 2 | **跨機房分流機制已備妥** —— Cloudflare LB 通過分流與 ip sticky 驗證（F5 出局） | A/S 的流量導向前提已成立 |
| 3 | **ATS Pro 已回到 Single Write** —— 多寫的 deadlock 影響上線，2025-11-19 定案 | 產品可在單寫架構下先上線，不必等主線遞進 |

---

## 2. Y26 PoC 結論彙整

### 2.1 候選與定位區隔

Y26 PoC 立項時的候選是三家分散式 SQL：**TiDB（MySQL wire）／YugabyteDB・CockroachDB（PostgreSQL wire）**。MySQL Galera（Percona XtraDB Cluster 8.4）於 2026-08 補測進來作為**對照基準**。

| 代號 | 候選 | 協定 | 定位 |
|---|---|---|---|
| **A** | MySQL Galera Cluster（PXC 8.4） | MySQL | **單寫 / 單機房場景的有效選項**，不擔任多寫多讀 |
| **B** | TiDB | MySQL | **多寫多讀路線的主要候選** |
| **C** | YugabyteDB | PostgreSQL | 備選，待業務出現 PostgreSQL／高關鍵度需求 |
| **D** | CockroachDB | PostgreSQL | 同 C |

**關於 A 的定位區隔（不是淘汰）**

Galera 的設計是**同步複寫 + certification-based 樂觀併發**：為維持 cluster-wide 強一致性，每個 writer 節點的寫入都必須跨節點認證。這個設計在**單寫入點**下代價幾乎為零 —— 實測單節點 NEW_ORDER p99 **37.7 ms**，是四家中最快，遠優於 TiDB 的 597 ms。

但同一個設計在**多寫入點**下成本隨節點數與跨區 RTT 放大，實測已驗證此判斷：

- 三節點 HAProxy round-robin 多寫 → 吞吐量降到單節點的 **0.49×**（負向擴展）
- 跨區單寫吞吐 **298.8 tpmC**，是 TiDB 的 1/41.9
- 跨區雙寫 GCP 端整體交易失敗率 **47.0%**（PAYMENT 交易 81.5%）

**結論**：Galera 繼續作為單寫、單機房、低延遲敏感服務的架構選項；多寫多讀路線由 TiDB 承接。兩者是**定位區隔**，不是取代關係。

**關於 C／D**：協定切換意味應用層改動是「能不能直接換」的門檻差異，不是「效能差一點」的程度差異。公司現行業務以 MySQL 為主，PostgreSQL 應用佔比 < 5%（2026-06-09 拍板 D3），目前業務量尚無需考量。

### 2.2 決策表：可行性與適配（兩級）

圖例：**O** 可行 ／ **X** 不適用或不建議 ／ **△** 有條件可行 ／ **待測** 尚未排入測試矩陣 ／ **n/a** 架構上不適用

| 大類 | 細項 | A MySQL | B TiDB | C YBDB | D CRDB | 備註 |
|---|---|:---:|:---:|:---:|:---:|---|
| **A. 業務適配** | 多寫多讀（雙區同時寫） | X | O | △ | △ | A 見 §2.1；C/D 技術可行但需換協定 |
| | 跨區散置寫入（placement） | X | O | O | O | Galera 原生不支援；6-node 下 GCP 3 台不足 majority=4 |
| | 跨區單寫 + standby（A/S） | △ | O | O | O | A 可做但跨區吞吐僅 298.8 tpmC |
| | 跨區就近讀（A/A-RO） | X | O | O | O | A 無 follower/stale read 機制 |
| | 單機房多寫 | △ | O | O | O | A 在 naive multi-writer 下 0.49× 負向擴展 |
| | 單機房單寫（現況） | O | O | O | O | A 為現行架構，延遲最優 |
| **B. 應用改造成本** | 協定不變（免改 driver/ORM） | O | O | X | X | A/B 為 MySQL wire |
| | SQL / ORM 相容性矩陣 | 待測 | 待測 | 待測 | 待測 | 四家皆未實測；B 官方宣稱高度相容 |
| | ID 生成改造（AUTO_INC→ULID） | 需要 | 需要 | 需要 | 需要 | 分散式共通議題，Y25 ac-api 已驗證方法可行 |
| | 重試 / 錯誤處理量 | 高 | 低 | 低 | 中 | A 跨區雙寫 47.0%；D quorum 遺失回報 `ambiguous` 需額外處理 |
| | 既有維運工具鏈可沿用 | O | 待測 | X | X | A 為現況（PMM3 等） |
| **C. 效能與擴展** | 單節點延遲（p99） | **37.7 ms** | 597 ms | 216 ms | 440 ms | A 大幅領先 |
| | 單節點 tpmC | 53,791.9 | 13,064 | 11,436 | 9,134 | 擴展倍率的分母 |
| | 三節點 HAProxy tpmC（t=128） | 26,166.2 | 26,947 | 15,632 | 15,033 | **A/B 絕對值其實接近** |
| | 水平擴展倍率（＝三節點 ÷ 單節點） | **0.49×**（−51%） | **2.06×**（+106%） | 1.37×（+37%） | 1.65×（+65%） | `>1×` 正向／`<1×` 負向擴展 |
| | 高併發穩定性（range/mean） | 43.2% | 7.4% | 7.1% | 6.9% | t=128 五輪變異，越低越穩 |
| | all-txn error rate | 0.037% | 0.000% | 0.000% | 0.000% | A 為四家中唯一非零 |
| | 跨區單寫吞吐（P-A×A-S） | 298.8 | 12,526.5 | 12,769.5 | 10,163.4 | tpmC，t=128 |
| | 跨區就近讀吞吐（A/A-RO） | n/a | 31,571.3 | 56,787.9 | 41,056.3 | GCP 側 read_tpmTotal |
| **D. 可用性與正確性** | 單節點 kill 可觀測中斷 | 無 | 6.68–8.4 s | 無 | 無 | B 為 SQL 層與共識層分離的架構體現 |
| | 區域級停止後復原 | 22.2 s | 39–44 s | **3.0 s** | 7.0 s | **口徑不等價**：A 從 `t_kill` 起算、B 從 `t_restart` 起算（B 從 `t_kill` 為 198–202 s） |
| | quorum 遺失寫入拒絕 | ⚠ 曾出現非預期成功 | 乾淨拒絕 | 乾淨拒絕 | ⚠ `ambiguous` | A/D 需應用層額外處理 |
| | 跨區分斷後自動恢復 | O | 待補 | 待補 | 待補 | A 分斷解除後 20–30 秒經 IST/SST 自動恢復 |
| | 跨區雙寫 GCP 側失敗率 | 47.0% | 0.158% | 0.134% | 0.111% | A 高出 B 約 300 倍 |
| **E. 維運後勤** | PITR / 備份還原 | 待測 | 待測 | 待測 | 待測 | 四家皆未排入測試矩陣 |
| | Online DDL 與維運工具 | 待測 | 待測 | 待測 | 待測 | 同上 |
| | HTAP / 分析型負載 | n/a | 待測 | n/a | n/a | 僅 B 有原生 TiFlash |
| | 原廠在地支援 | 社群 / Percona | **24×7 中文 + 台灣 SA** | 無在地 | 無在地 | B 已完成原廠對接（見 §3.4） |
| | 現有 DBA 技能可承接 | O | △ | X | X | B 需累積維運經驗，C/D 需重建技能樹 |

### 2.3 為何主線終點收在 A/A-RO —— DB 以外的 Infra 已知不可行項目

資料庫層在 §2.2 已證明 TiDB 具備雙區寫入能力（跨區雙寫 GCP 側失敗率 0.158%）。**限制不在資料庫，在周邊 Infra**：

| 層級 | 已知不可行 / 未就緒項目 | 來源 |
|---|---|---|
| **應用組件** | **Assessment 無法支援 AA mode**，網站設計過時、未來不續存 —— 屬產品端需處理問題 | Y25 SSD 不驗證項目表 |
| | **Memcache 無法支援 AA mode**，未來不續存，預期轉移至 Redis | 同上 |
| | OMS 寫檔寄信 —— 雲端無法代理對外寄信，未來都轉 SMTP | 同上 |
| **儲存** | NetApp 檔案規劃以 MVS 作為主要存儲媒介，部分檔案無法轉入 | 同上 + ITHVM-312/350 |
| **網路** | GCP SLB **無 Ignore-TCP-MSL 功能**（A10 獨有機制） | Y25 ITNET-2113 |
| | Cloudflare + F5 架構下 **sticky session 無法生效** —— 來源 IP 到 F5 只看得到 Cloudflare 的 IP | Y25 F5 分流實測 |
| **故障域** | RF=3、僅 IDC + EDC 兩個 failure domain，整區故障下秒級接手**數學上不保證** | X-CROSS 比較報告 §6.1 |
| **專線** | 跨區實測 RTT 8.5 ms、探測頻寬 190–227 Mbps；「類似 DX 之專線服務是必要投資」但尚未取得 | Y25 結論 + PingCAP 建議副本間延遲 ~10 ms |

**推論**：多個非資料庫組件在架構上就不支援 AA mode，且分流與故障域前提尚未成立。即使資料庫層可雙寫，端到端的 A/A 仍無法交付。因此 **A/A 不列入本輪路線**；先把 A/S 與 A/A-RO 做扎實，A/A 保留為業務提出雙區寫入需求時再啟動的條件式選項。

---

### 2.4 能做什麼 / 不能做什麼

#### 2.4.1 根據目前 TiDB 的評估，我們可以完成的事

| # | 可以完成 | 依據 |
|---|---|---|
| 1 | **跨區資料同步不漏寫、不寫錯** | Y25 ac-api 流量鏡像整合測試：刻意挑選 AC API 中最複雜寫入場景，全程無任何漏寫或寫錯的紀錄 |
| 2 | **應用不改協定即可接上** | MySQL wire protocol；ac-api 完成 ULID / Snowflake 改造後，2026-08-26 TiDB 測試直接通過 |
| 3 | **水平擴展** | 1node → 3node-haproxy 擴展倍率 **2.06×**，四家中最高；跨區單寫吞吐是 Galera 的 41.9 倍 |
| 4 | **高併發下維持穩定與零錯誤** | t=128 五輪變異 **7.4%**、all-txn error rate **0.000%** |
| 5 | **跨區單寫（A/S）並確保副本真的到位** | P-A × A-S 跨區 W=128 完成，12,526.5 tpmC、0 error；placement 門檻 + 副本存在門檻 + 近讀 probe 三重驗證通過 |
| 6 | **跨區就近讀（A/A-RO）** | P-A × A-A-RO 修正後全輪完成：IDC 側 15,182.5 tpmC、GCP 側 read_tpmTotal 31,571.3、**全程 0 錯誤** |
| 7 | **控制資料放置位置** | Placement Rules 實測：P-A（leader 固定 IDC）與 P-B（leader 跨區 30–70% 混合）皆可設定並驗證 |
| 8 | **quorum 遺失時乾淨拒絕寫入** | `write_correctly_rejected` —— 不會靜默寫入成功（對照：Galera 曾出現非預期成功、CockroachDB 回報 `ambiguous` 需應用層額外處理） |
| 9 | **跨區雙寫時把錯誤率壓在低檔** | P-B × A-A GCP 側整體錯誤率 **0.158%**，型態為跨區鎖等待逾時，非衝突拒絕（對照：Galera 47.0%） |
| 10 | **K8s 部署與資源配額控制** | S-K8S limit / unlimit 六組 suite 完成，含 throttling / OOM / storage 證據 |
| 11 | **取得原廠在地後勤支援** | PingCAP：24×7 中文技術支援、Premier S1 30 分鐘 SLA、台灣本地 SA 已到職、專業服務可按人天採購 |
| 12 | **把 DR 備援資源轉成有產出的資源** | A/S 的 standby 資料端置於 EDC，可承載讀取型商務邏輯（Branch B3） |

#### 2.4.2 根據現有架構，我們不能完成的事

**（一）架構層面 —— 短期內無法解除**

| # | 不能完成 | 原因 |
|---|---|---|
| 1 | **端到端雙區同時寫（A/A）** | 限制不在資料庫。Assessment / Memcache **架構上無法支援 AA mode**；OMS 雲端無法代理對外寄信；NetApp 部分檔案無法轉入 MVS（詳見 §2.3） |
| 2 | **整區故障秒級自動接手** | RF=3、僅 IDC + EDC 兩個 failure domain，**數學上不保證**。已完成的 F2 是「停止 3 台 IDC process 再由 operator 重啟」的恢復力測試，**不是自動區域 failover**；從 `t_kill` 起算為 198–202 秒 |
| 3 | **單節點故障對 client 完全零感知** | TiDB SQL 層與儲存/共識層分離，單節點 kill 有 **6.68–8.4 秒**真實可觀測中斷（YugabyteDB / CockroachDB 單一 process 整合架構觀測不到）。這是架構特性，不是缺陷，但設計 SLO 時必須納入 |
| 4 | **在低延遲敏感場景取代 Galera** | 單節點 NEW_ORDER p99 **597 ms** vs Galera **37.7 ms**（15.8 倍）。極低延遲優先的單寫服務，TiDB 不是較優解 |
| 5 | **Cloudflare + F5 架構下的 sticky session** | 來源 IP 到 F5 只看得到 Cloudflare 的 IP，sticky 無法生效；需改用 Cloudflare LB |
| 6 | **在 GCP 重現 A10 的 Ignore-TCP-MSL** | GCP SLB 無此功能（A10 獨有機制）；TSD 已評估影響不大，但無法對等移植 |

**（二）證據層面 —— 補測即可解除**

| # | 尚不能宣稱 | 缺什麼 |
|---|---|---|
| 7 | **SQL / ORM 相容性已驗證** | 相容性矩陣未執行。官方宣稱高度 MySQL 相容，但本 PoC 未實測；MariaDB 10.4 / 10.11 待原廠線下評估 |
| 8 | **備份可還原、PITR 可用** | 完全未排入測試矩陣（無 spec、無 script、無 artifact） |
| 9 | **Online DDL 不影響前台** | 未量測 DDL 執行期間對 tpmC / p99 的影響幅度與持續時間 |
| 10 | **跨區部署的 WAN 成本是多少** | 缺 IDC-only 六節點 paired control；節點數、quorum、硬體與 topology 皆不同，無法計算 WAN penalty |
| 11 | **P-B 高併發吞吐劣化的根因** | A-A-RO / A-A 於 th=128 出現吞吐劣化（五輪 9003→14948→2113→954→1480），命中 `PessimisticLockNotFound` / `LockTsMismatch`；與跨區鎖競爭假說相容但**未定位根因**，控制實驗待辦 |
| 12 | **HTAP / 向量檢索可用** | TiFlash 未執行分析型查詢測試；向量檢索僅原廠說明（HNSW / RAG / BM25），本 PoC 無實測 |
| 13 | **Failover 數字可跨產品比較** | 各家計時起點不等價（Galera 從 `t_kill`、TiDB 從 `t_restart`），需先統一口徑重測（見 §4.5） |

**（三）本輪不做 —— 屬決策而非能力限制**

| # | 不做 | 理由 |
|---|---|---|
| 14 | PostgreSQL 路線（YugabyteDB / CockroachDB） | 公司業務以 MySQL 為主，PostgreSQL 應用佔比 < 5%（2026-06-09 拍板 D3）；協定切換成本無法由現有效益差距正當化 |
| 15 | Redis 多寫多讀驗證 | 待有實際需求發生時再規劃安排（2025-12-19 定案） |
| 16 | ac-api PROD 整合與流量 mirror | 定案 Y27 再安排，視未來策略及專案優先規劃調整 |

#### 2.4.3 一句話總結

> **資料庫層已經準備好做 A/S 與就近讀；擋住 A/A 的是資料庫以外的組件與故障域數量。**
> 因此本輪把資源投在「把 A/S 與 A/A-RO 做扎實 + 把平台能力交付給產品」，而不是追 A/A。

---

### 2.5 Placement 對照：P-A vs P-B

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

**判讀**

- 單寫情境下 P-B 不但沒有比較慢，反而較快且 p99 略低 —— 與「P-A 的 commit 不等 WAN 所以較快」的架構直覺相反。
- 跨三家 24 個 `<profile, DB, threads>` 對照點中 P-B ≥ P-A 為 12/24（一半，非多數）；但 **TiDB 在 A/S 的四個 thread 檔位全數 P-B 較高**，是三家中方向最一致的。
- 兩批次執行日期不同（P-A `20260717T143238`、P-B `20260727T223650`），屬 placement 的階段性觀察，非 paired control。

> **對 §3.2 S1 的意涵**：主線表列以 P-A 為基準，但此對照顯示 **placement 選擇不宜僅憑架構直覺預設 P-A**，S1 設計時須複核。

來源：[`XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md`](../phase-crossregion/XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md)、P-A 採用批次 `summary.json`。

---

## 3. 推進路線（三軌）

### 3.1 全景

```
                 【進入條件】                【進入條件】
                 相容性矩陣                  Failover 等價口徑重測
                 PITR / 備份還原             跨區分斷演練
                 Online DDL                  就近讀 staleness 驗證
                      │                           │
主線  S0 IDC Only ────┼──▶ S1 IDC+EDC P-A×A/S ────┼──▶ S2 IDC+EDC P-A×A/A-RO
（技術）  現行         │                           │
                      │                           │        ⛔ S3 P-B×A/A
                      │                           │        不列入本輪（§2.3）
                      ▼                           ▼
branch   B1 Self-Service          B2 DB 申請 CI/CD 平台
（產品）  B4 Observability          B3 EDC 資源活化（A/S 資料端）
                      │                           │
                      ▼                           ▼
後勤     能力缺口盤點 ──▶ 自控驗證項 ──▶ 原廠協作項（不採購）
```

### 3.2 技術主線

| 階段 | 內容 | 進入條件 | 驗收 |
|---|---|---|---|
| **S0** IDC Only | TiDB 單區叢集營運，累積維運經驗與架構穩定性 | — | 叢集穩態營運、監控與告警上線、備份可還原 |
| **S1** IDC + EDC　**P-A × A/S** | leader/lease 固定 IDC，EDC 持副本；流量只打 IDC | 相容性矩陣、PITR／備份還原、Online DDL 三項補測通過 | EDC 端確實持有資料副本（副本存在門檻）、placement 門檻通過、切換演練可回退 |
| **S2** IDC + EDC　**P-A × A/A-RO** | EDC 端就近讀，寫入仍集中 IDC | Failover 等價口徑重測、跨區分斷演練、就近讀 staleness 與 fallback 驗證 | EDC 端 near-read probe 全數通過、staleness 在業務可接受範圍、fallback 機制有效 |
| ⛔ **S3** P-B × A/A | 雙區同時寫入 | **不列入本輪** | 業務提出雙區寫入需求，且 §2.3 的非 DB 層阻礙解除後再議 |

**遞進理由**：先 A/S 再 A/A-RO，是因為 A/S 只需驗證「副本真的到 EDC」與「切得回來」；A/A-RO 才需要處理就近讀路由、staleness 語意與 fallback。前者是後者的前置，兩階段的失敗模式完全不同，合併會讓問題無法歸因。

**S1 的 placement 待複核**：上表以 P-A 為基準，但 §2.5 顯示 A/S 實測 P-B 較 P-A 高 20.6%、p99 略低。S1 設計時須複核 placement 選擇，不預設 P-A。

### 3.3 產品期待 branch

這四條乘載在同一套 TiDB 上，**不卡主線遞進**，可與 S0／S1 並行。

| Branch | 內容 | 依附階段 | 產品側可感知的價值 |
|---|---|---|---|
| **B1** Database Self-Service | 申請 / 權限 / 配額 / 備份 / 監控 / 退場的完整生命週期 | S0 起 | 把一次性 PoC 轉為長期平台能力 |
| **B2** DB 服務申請 CI/CD 平台 | RD Self-Managed 流程串接（不填 Jira 單即可滿足需求）+ Deploy on K8s 流程 | S0 起 | 縮短交付週期，降低重複申請與維運成本 |
| **B3** EDC 資源活化（A/S 資料端） | A/S 的 standby 資料端置於 EDC，供商務邏輯讀取 | S1 起 | 把 DR 備援資源轉成有產出的資源；先挑可移至 EDC 持續運作的定期批次或低風險服務 |
| **B4** Observability / 效能分析 | 以 observability data 做效能分析與容量規劃 | S0 起 | B1 的前置能力；讓服務恢復時間可量測而非只有叢集健康燈號 |

> B3 是 EDC 活化議題的直接出口 —— 不需要等到 A/A，A/S 的資料端就已經可以承載讀取型商務邏輯。

### 3.4 維運後勤軌（能力缺口 → 協作需求）

TiDB 原廠（PingCAP）對接已完成，**尚無強需求進行採購**，但建議先確立維運後勤支援協作方式。

| 能力缺口 | 自控 / 原廠協作 | 現況 |
|---|---|---|
| PITR / 備份還原 | **自控驗證** | 待測，S1 進入條件 |
| Online DDL 對前台負載影響 | **自控驗證** | 待測，S1 進入條件 |
| SQL / ORM 相容性矩陣 | **原廠提供清單 + 自控驗證** | 原廠已列為 follow-up 項目 |
| Self-Managed 訂閱方案細節 | **原廠待補** | 2026-06-11 會議已提出，會後補充 |
| 隔離級術語對齊（RR / SI / Serializable） | **原廠釐清** | TiDB 無原生 SERIALIZABLE，設 `tidb_skip_isolation_level_check` 後仍以 REPEATABLE-READ 行為執行；與原廠說法需對齊 |
| MariaDB 10.4 / 10.11 相容性 | **原廠線下評估** | 已提出，待回覆 |
| SLA / 事件升級管道 | **先談協作方式，未採購** | 原廠已說明：24×7 中文技術支援、Premier S1 30 分鐘、Enterprise 1 小時、7 月台灣本地 SA 到職 |
| 跨雲連線方式 review | **自控 + 原廠確認** | PoC 走 GCP IAP tunnel；正式導入需 review VPC Peering / Private Link |

---

## 4. 採用 TiDB 的分階段實施辦法

### 4.1 Phase 0 —— 技術門檻補件

| 項目 | 內容 |
|---|---|
| **目標** | 補齊決策表中 E 大類的三個「待測」項，讓 TiDB 具備可進入生產的完整技術檔案 |
| **工作項** | ① 相容性矩陣：以現行應用實際使用的 SQL 語法子集、常用 ORM、既有備份/監控工具鏈跑相容性驗證<br>② PITR / 備份還原：定義 RPO 目標，實跑全量+增量還原演練<br>③ Online DDL：對含資料大表執行 `ADD COLUMN` / `ADD INDEX`，量測對前台負載的 tpmC/p99 影響幅度與持續時間 |
| **原廠協作** | 索取 MySQL 相容性清單、Self-Managed 訂閱方案細節、隔離級術語對齊 |
| **驗收** | 三項皆有可追溯的測試結果；相容性矩陣明列不支援的 SQL 特性與 workaround |
| **退場條件** | 若相容性矩陣顯示現行應用需大幅改寫，回到決策表重新評估 |

### 4.2 Phase 1 —— 代表性應用 Pilot（S0）

| 項目 | 內容 |
|---|---|
| **目標** | 在 IDC Only 架構下，導入一個代表性 MySQL 應用或定期批次，取得應用、維運與服務生命週期證據 |
| **選題原則** | 可驗證隔離與恢復的代表性服務；或故障影響範圍明確的服務；或可移至 EDC 持續運作的定期批次 |
| **協作** | 由 TSD 指派應用 owner，提供真實 SQL / ORM / Driver / Transaction 與改造限制 |
| **同步啟動** | **B1 Self-Service**、**B2 CI/CD 平台**、**B4 Observability** 三條 branch 的最小可用版本 |
| **驗收** | ① 定義使用者可感知的恢復驗收點（以服務恢復時間取代單一叢集健康燈號）<br>② 一致性優先：先驗證一致性、拒寫與恢復，不以持續寫入為唯一目標<br>③ Self-Service 走完一次完整申請→交付→退場流程 |
| **退場條件** | Pilot 效益無法量化，或應用改造量超出 owner 可承擔範圍 |

### 4.3 Phase 2 —— 跨區 A/S（S1）

| 項目 | 內容 |
|---|---|
| **目標** | IDC + EDC，leader/lease 固定 IDC，EDC 持副本，流量只打 IDC |
| **前置** | Phase 0 三項補測通過；跨區專線可用性確認（PingCAP 建議副本間延遲 ~10 ms） |
| **工作項** | ① placement 設定與門檻驗證<br>② **副本存在門檻**：逐 region 驗證資料確實到達 EDC，不能只驗設定存在<br>③ 切換與回滾演練 |
| **同步啟動** | **B3 EDC 資源活化** —— standby 資料端供商務邏輯讀取 |
| **驗收** | placement 門檻 + 副本存在門檻皆通過；切換演練可回退；EDC 端資料可供讀取型商務邏輯使用 |
| **關鍵教訓** | Y26 PoC 曾發生「設定存在但副本從未實體化」的效度事件（zone config 自相矛盾、read-replica 缺 placement_uuid），且探測因缺 DB client 靜默通過。**驗證門檻必須 fail-closed**，不可只驗設定 |

### 4.4 Phase 3 —— 跨區就近讀 A/A-RO（S2）

| 項目 | 內容 |
|---|---|
| **目標** | EDC 端就近讀，寫入仍集中 IDC |
| **前置** | Phase 2 驗收通過；Failover 等價口徑重測完成 |
| **工作項** | ① 就近讀路由設定與 near-read probe<br>② staleness 量測與業務可接受範圍定義<br>③ fallback 機制驗證<br>④ 跨區分斷演練 |
| **驗收** | near-read probe 全數通過；staleness 在業務可接受範圍；分斷後可自動恢復或有明確人工程序 |
| **關鍵教訓** | Y26 PoC 首輪 A/A-RO **近讀未生效** —— 「設定存在」不足以證明就近讀，必須有執行面證據 |

### 4.5 Failover 口徑統一（跨 Phase 的方法論前置）

現行各家 Failover 數字口徑不等價，無法互相比較。進入 Phase 2 前需先統一：

| 項目 | 統一口徑 |
|---|---|
| RTO 起點 | `t_kill`（故障注入時點）到首次成功寫入 |
| 觀測窗 | 禁止人工恢復介入的觀測窗 |
| 探測位置 | 相同探測位置，並同時涵蓋 IDC 側與 EDC 側 client |
| RPO 驗證 | 由相同交易序列驗證 |

### 4.6 條件式選項（不列入本輪排程）

| 選項 | 觸發條件 |
|---|---|
| **P-B × A/A（雙區同時寫）** | 業務明確提出雙區寫入需求，**且** §2.3 的非 DB 層阻礙（AA mode 不支援組件、分流 sticky、故障域數量、專線）解除 |
| **PostgreSQL 路線（YugabyteDB / CockroachDB）** | 出現高關鍵度 PostgreSQL 應用或 AI 應用需求；或 TiDB 在 Phase 0 相容性矩陣中被證明不適配 |
| **PXC / Galera 目標式對照** | 出現極低延遲優先的單寫場景，需要與 TiDB 做針對性比較 |

---

## 5. 附錄：實測證據入口

| 文件 | 內容 |
|---|---|
| `poc/refresh/Y25_多寫多讀POC_摘要.md` | Y25 Jira 42 單 + 2601 專案總結簡報彙整 |
| `poc/refresh/DECISION-MATRIX.md` | Y26 四家候選決策表與終點結論 |
| `poc/DISTRIBUTED-DB-SCORING.md` | 四家評分表、加權總分、逐項證據連結 |
| `poc/MILESTONES.md` | 專案歷程、可下／不可下結論、下一決策門檻 |
| `poc/gitbook/` | 17 章結構化交付文件（09 跨區、16 決策框架） |
| `poc/results/` | 原始 `summary.json`、pipeline-log、驗證門檻證據 |
| `poc/phase-crossregion/` | 各 placement × workload 結案報告、chaos/failover 比較 |
| `poc/1_MeetingMinutes/0611-TiDBx104-summary.md` | PingCAP 原廠對接紀錄 |
| `poc/1_MeetingMinutes/2026-06-09-distributed-db-adoption-non-technical.md` | D1–D4 拍板紀錄（跨區階梯、TiDB 為主路線） |
| `poc/1_MeetingMinutes/0821_slide.md` | 前一版簡報：Option 0/A/B/C/D 與 ROI 決策樹 |
