# 0827_slide_codex_v2 內容基準

> 用途：作為 `0827_slide_codex_v2.pptx` 後續內容重構的唯一文字基準。
>
> 本檔只整理內容，不調整投影片數量、順序、顯示狀態或版型。

## 1. 結構鎖定

| 項目 | 基準 |
|---|---|
| 主檔 | `refresh/0827_slide_codex_v2.pptx` |
| 投影片總數 | 19 頁 |
| 顯示頁 | Slide 1–10 |
| 隱藏頁 | Slide 11–19 |
| 結構原則 | 不新增、不刪除、不重排、不自行取消隱藏 |
| 重構範圍 | 精簡文字、改善層級、修正誤植、凸顯結論與證據 |

後續若要調整頁數、順序或顯示狀態，必須另行確認，不得在內容重構時一併處理。

## 2. 內容規範

- A 方案統一寫作 **PXC / Galera**，避免只寫「MySQL」造成產品範圍不清。
- `A/A-RO`、`A/S-RO` 統一寫作 **A/A (RO)**。
- `gate` 統一寫作 **門檻**。
- `YBDB`、`CRDB` 第一次出現時，分別使用 **YugabyteDB**、**CockroachDB**。
- 實測數據只描述本 PoC 條件，不外推為跨產品總排名。
- Failover 數字若計時起點不同，不得直接並排排名。
- 「待測」表示尚無本 PoC 證據，不等於不可行。
- 不使用 `N=1` 作為投影片上的免責文字；證據範圍直接用測試條件與來源界定。
- 官方文件用於解釋產品機制，實際結論仍以本 PoC 記錄與原始結果為準。

## 3. 資料來源優先序

1. 本檔：投影片重構文字與敘事基準。
2. [0827_slide.md](./0827_slide.md)：完整簡報素材與數據說明。
3. [SLIDE-BRIEF-2026.md](./SLIDE-BRIEF-2026.md)：Y25–Y26 敘事與導入路線。
4. [DECISION-MATRIX.md](./DECISION-MATRIX.md)：四家候選決策表。
5. [DISTRIBUTED-DB-SCORING.md](../DISTRIBUTED-DB-SCORING.md)：評分、證據與限制。

若數字或判讀不一致，必須回到來源確認，不得自行平均、補值或改寫結論。

---

## Slide 1｜封面

**狀態：顯示**

### 標題

多寫多讀混合雲

### 副標

Y25 紀錄 Recap × Y26 PoC 決策彙整

### 核心訊息

從「雙區多寫」目標，收斂為可交付的 **A/S → A/A (RO)** 路線。

### 必留資訊

- SSD 技術審查
- Y25 與 Y26 的承接關係
- 這是一份決策彙整，不是單純測試數據報告

---

## Slide 2｜Y25 → Y26 大事紀

**狀態：顯示｜現有頁碼標記：04**

### 核心訊息

專案從降低單點影響，逐步進入跨雲驗證、四家資料庫實測與分階段交付。

### 時程

| 時間 | 階段 | 主要內容 |
|---|---|---|
| 2024 | 先降低單點影響 | Service Mesh、AC 雲地部署、資料一寫多讀 |
| Y25 | 驗證跨雲組件 | Cloudflare LB 通過；`ac-api` 測至 STG |
| Y26 | 四家資料庫實測 | S-BASE、S-K8S、X-CROSS、Chaos、Failover、Galera 對照 |
| Next | 分階段交付 | Phase 0 → S0 Pilot → S1 A/S → S2 A/A (RO) |

### 結論句

Y25 證明應用改造與流量導向可行；Y26 確認資料庫主線，以及完整 Infra 架構仍需解除的限制。

### 來源

- [Y25_多寫多讀POC_摘要.md](./Y25_多寫多讀POC_摘要.md)
- `MILESTONES.md`
- [SLIDE-BRIEF-2026.md §1](./SLIDE-BRIEF-2026.md#1-y25-結論彙整)

---

## Slide 3｜北極星

**狀態：顯示｜現有頁碼標記：03**

### 標題

北極星沒變，只有達成方式被證據修正

### 三層目標

| 層級 | 目標 |
|---|---|
| 策略層 | 隔離應用與基礎建設的直接關聯，讓應用具備可攜性 |
| 業務層 | 封站或機房維護時，關鍵服務客戶不受影響 |
| 維運層 | 停機維護是內部作業，不應轉嫁為客戶權益損失 |

### Y25 → Y26 修正

- Y25 原訂：驗證 A/A 雙區同時寫。
- Y26 收斂：先交付 A/S，再以 A/A (RO) 活化 EDC 讀取能力。
- A/A 保留為條件式長期選項，不列入目前交付承諾。

### 邊界

Failover、staleness 與 fallback 的實際成效，仍須在 Pilot 與產品情境下驗收。

### 來源

[SLIDE-BRIEF-2026.md §0.1–§0.3](./SLIDE-BRIEF-2026.md#0-北極星目標重申)

---

## Slide 4｜為什麼不是 A/A

**狀態：顯示｜現有頁碼標記：06**

### 標題

目前雙活機房架構 A/A 尚有阻礙

### 阻礙

| 面向 | 已知限制 |
|---|---|
| 應用組件 | Memcache 不支援 A/A；OMS 寫檔寄信需改 SMTP |
| 儲存與網路 | 部分 NetApp 檔案無法轉入；F5 sticky 失效；GCP SLB 無 Ignore-TCP-MSL |
| 故障域 | RF=3 但只有 IDC、EDC 兩個 failure domain，整區故障秒級接手無法科學保證 |
| 專線 | 本 PoC 使用 VPN，RTT 8.5 ms、探測 190–227 Mbps；正式專線投資與可用性待確認 |

### 結論句

先把 A/S 與 A/A (RO) 做成可營運能力；A/A 保留為需求與前置條件明確後的選項。

### 來源

[SLIDE-BRIEF-2026.md §1.3、§2.3](./SLIDE-BRIEF-2026.md#13-ssd-不驗證項目明確排除)

---

## Slide 5｜Executive Answer

**狀態：顯示｜現有頁碼標記：02**

### 標題

目標不變；交付路線改為 A/S → A/A (RO)

### 核心判斷

TiDB 是 MySQL 相容路線的主線候選；現行架構先採 A/S，再依產品需求與驗收結果進入 A/A (RO)。

### MySQL 相容主線：三個代表證據

| 證據 | 數值 | 判讀 |
|---|---:|---|
| TiDB 水平擴展 | 2.06× | 1 node → 3 node HAProxy，四家最高 |
| 高併發交易錯誤率 | 0.000% | t=128；五輪 range/mean 7.4% |
| 跨區實務終點 | A/S → A/A (RO) | A/A 只保留為條件式長期選項 |

### PostgreSQL 相容群組：其他資料庫代表數據

YugabyteDB、CockroachDB 屬於另一條 PostgreSQL 相容路線。下列數據用於說明技術特性與應用選擇條件，不與 MySQL 相容群組計算總排名。

| 候選 | 單節點 p99 | 水平擴展 | P-A × A/S | F2 復原觀察 | 判讀 |
|---|---:|---:|---:|---:|---|
| YugabyteDB | 216 ms | 1.37× | 12,769.5 tpmC | 約 3 s | 延遲較低、F2 復原較快；曾觀察到 YB-Master 執行緒暴增，正式採用前需增加長時間穩定性驗證 |
| CockroachDB | 440 ms | 1.65× | 10,163.4 tpmC | 約 7 s | 擴展倍率較高；quorum 遺失時可能回報 `ambiguous`，應用必須確認交易最終狀態 |

> F2 數字僅在 PostgreSQL 相容群組內作方向性觀察；不得與 TiDB、PXC / Galera 的不同計時方法直接比較。

### 應用層級卡片

#### YugabyteDB｜適用與改造考量

- **適用情境**：已有 PostgreSQL 技術棧，且重視跨區資料分布、較低延遲與區域恢復速度的應用。
- **必要改造**：現有 MySQL 應用必須更換 PostgreSQL driver / ORM 設定，並重新驗證 SQL、資料型別、序列與 ID 生成方式。
- **交易處理**：quorum 遺失時本輪觀察為乾淨拒絕；應用仍需具備可重試、冪等與逾時處理。
- **進入條件**：完成實際產品 SQL / ORM 相容性矩陣，並針對曾觀察到的 YB-Master 執行緒異常進行長時間穩定性測試。

#### CockroachDB｜適用與改造考量

- **適用情境**：已有 PostgreSQL 技術棧，且重視水平擴展、跨區 placement 與一致性控制的應用。
- **必要改造**：現有 MySQL 應用必須更換 PostgreSQL driver / ORM 設定，並重新驗證 SQL、資料型別與交易語意。
- **交易處理**：quorum 遺失可能回報 `ambiguous`；應用必須使用冪等鍵、交易狀態查詢或補償流程，不能直接重送並假設前次未提交。
- **進入條件**：完成實際產品 SQL / ORM 相容性矩陣，並驗證 retry、`ambiguous` 與故障復原流程。

### 分群決策

- **MySQL 相容需求**：比較 PXC / Galera 與 TiDB；目前主線為 TiDB Pilot。
- **PostgreSQL 相容需求**：比較 YugabyteDB 與 CockroachDB；待實際應用與 RTO 需求觸發。
- 兩個群組的協定、應用改造量及驗證方法不同，不合併計算整體排名。

### 決策句

先選代表性 MySQL 應用進行 Pilot；通過後才進入 IDC + EDC 跨區架構。

### 來源

- [SLIDE-BRIEF-2026.md §2.2、§2.4、§4](./SLIDE-BRIEF-2026.md#22-決策表可行性與適配兩級)
- [DECISION-MATRIX.md §3–§5](./DECISION-MATRIX.md#3-決策表格)
- [DISTRIBUTED-DB-SCORING.md §3.2、§3.3.1、§5.2](../DISTRIBUTED-DB-SCORING.md#32-量化評分)

---

## Slide 6｜跨區證據

**狀態：顯示｜現有頁碼標記：09**

### 標題

Placement 策略會改變資料路徑與效能

### 三個代表點

| 情境 | 數值 | 條件 |
|---|---:|---|
| P-A × A/S | 12,526.5 tpmC | TiDB、IDC 單邊讀寫、threads=128、0 error |
| P-A × A/A (RO) | 31,571.3 read_tpmTotal | GCP 就近讀、全程 0 error |
| P-B × A/A | 0.158% | GCP 側錯誤率；雙區寫入，workload 與 A/S 不同 |

### TiDB A/S placement 對照

| 指標 | P-A × A/S | P-B × A/S | 差異 |
|---|---:|---:|---:|
| tpmC | 12,526.5 | 15,107.4 | P-B +20.6% |
| NEW_ORDER p99 | 677.8 ms | 664.4 ms | P-B -2.0% |
| all-txn error rate | 0% | 0% | 相同 |

### 結論句

A/S 是目前 workload 定義相同、最適合觀察 placement 差異的對照軸；不得用不同 workload 的數字推導 placement 優劣。

### 來源

- [SLIDE-BRIEF-2026.md §2.2、§2.4](./SLIDE-BRIEF-2026.md#22-決策表可行性與適配兩級)
- `results/x-cross/` P-A、P-B 結案記錄

---

## Slide 7｜水平擴展證據

**狀態：顯示｜現有頁碼標記：08**

### 指標

```text
水平擴展倍率 = 三節點 HAProxy tpmC ÷ 單節點 tpmC
```

| 資料庫 | 單節點 tpmC | 三節點 tpmC | 增減幅 | 擴展倍率 |
|---|---:|---:|---:|---:|
| PXC / Galera | 53,791.9 | 26,166.2 | -51% | 0.49× |
| TiDB | 13,064 | 26,947 | +106% | 2.06× |
| YugabyteDB | 11,436 | 15,632 | +37% | 1.37× |
| CockroachDB | 9,134 | 15,033 | +65% | 1.65× |

### 判讀

- `>1×`：本次配置增加節點後吞吐提高。
- `<1×`：本次配置增加節點後吞吐下降。
- 倍率描述擴展特性，不等於跨產品總排名。
- PXC / Galera 與 TiDB 的三節點絕對吞吐接近：26,166.2 vs 26,947 tpmC。

### 結論句

PXC / Galera 在低延遲仍有優勢；TiDB 在本次三節點配置的擴展倍率最高。

### 來源

- [DISTRIBUTED-DB-SCORING.md §3.2](../DISTRIBUTED-DB-SCORING.md#32-量化評分)
- 各資料庫 `results/<db>-tc1/S-BASE/` 流程記錄

---

## Slide 8｜目標路線

**狀態：顯示｜現有頁碼標記：11**

### 標題

主線按風險遞進：S0 → S1 → S2；A/A 延後

| 階段 | 架構 | 驗收重點 |
|---|---|---|
| S0 | IDC Only | 維運、備份、監控、代表性應用 Pilot |
| S1 | IDC + EDC A/S | IDC 主寫；EDC 副本；切換演練 |
| S2 | A/A (RO) | EDC 就近讀；staleness；fallback |
| S3 | A/A | 只有非 DB 阻礙解除且出現雙寫需求時才評估 |

### 共同前置｜Phase 0

在 S0 Pilot 前，先完成 SQL / ORM 相容性、PITR / 備份還原與 Online DDL 三項技術補件。若應用改造量或維運缺口超出可接受範圍，回到決策表重新評估，不直接進入 Pilot。

### 各階段驗收目標與非 DBA 協作需求

| 階段 | 驗收目標 | 非 DBA 協作單位 | 協作需求 |
|---|---|---|---|
| Phase 0 | 相容性、備份還原、Online DDL 都有可追溯結果與替代方案 | TSD / RD、Infra、SRE、原廠 | 提供真實 SQL、ORM、driver、交易模式與資料量；提供備份儲存、監控及維護窗口 |
| S0｜IDC Only | 代表性應用完成部署、壓測、故障恢復與退場；以服務恢復時間驗收 | 產品 Owner、TSD / RD、DevOps、SRE | 指定 Pilot 應用與業務 SLO；完成應用改造、CI/CD、監控告警、變更與回復程序 |
| S1｜A/S | placement 與 EDC 副本實際存在；切換可執行且可回退；EDC 資料可供讀取型工作負載 | Infra / Cloud、Network、產品 Owner、TSD / RD、SRE | 提供跨區網路 SLA 與故障演練窗口；定義 EDC 可承載的讀取或批次工作；確認流量切換與服務恢復驗收點 |
| S2｜A/A (RO) | near-read 確實命中 EDC；staleness 在業務容忍範圍；fallback 與跨區分斷恢復通過 | 產品 Owner、TSD / RD、Network / LB、SRE | 分離可就近讀的 API / query；定義 staleness 與 read-your-write 需求；完成流量路由、synthetic probe、降級與 fallback |
| S3｜A/A | 只有雙區寫入需求、ROI 與非 DB 前置條件都成立才重新立項 | 產品 Sponsor、架構治理、TSD / RD、Infra / Network / Storage、SRE | 提出不可由 A/S 或 A/A (RO) 滿足的業務需求；完成冪等、衝突處理與補償設計；解除應用組件、儲存、網路及 failure domain 限制 |

### 非 DBA 協作責任摘要

- **產品 Owner / Sponsor**：定義業務情境、服務恢復時間、資料延遲容忍度、ROI 與退場條件。
- **TSD / RD**：提供真實應用語法與交易模型，完成 driver / ORM、ID、retry、冪等與 fallback 改造。
- **Infra / Cloud / Network / Storage**：提供運算、跨區網路、DNS / LB、儲存、時間同步與 failure domain 條件。
- **DevOps / Platform**：建立部署、變更、版本回復與 Database Self-Service 流程。
- **SRE / Observability**：以使用者可感知的服務恢復時間、錯誤率、延遲與資料一致性建立監控及演練證據。

### 階段門檻

- 前一階段驗收完成，才允許進入下一階段。
- 任一階段缺少應用 Owner、業務 SLO、回復程序或跨單位演練窗口，視為尚未具備啟動條件。
- DBA 負責資料庫與證據門檻，但不能替產品端定義業務需求、資料延遲容忍度或應用改造成本。

### 結論句

前一階段驗收是下一階段的進入條件；目前 S3 不納入規劃。

### 來源

- [SLIDE-BRIEF-2026.md §3.1–§3.4](./SLIDE-BRIEF-2026.md#3-推進路線三軌)
- [SLIDE-BRIEF-2026.md §4.1–§4.6](./SLIDE-BRIEF-2026.md#4-採用-tidb-的分階段實施辦法)

---

## Slide 9｜Operating Model

**狀態：顯示｜現有頁碼標記：12**

### 標題

技術主線、產品服務化、維運後勤可以並行

| 軌道 | 內容 |
|---|---|
| 技術主線 | S0 IDC Only → S1 A/S → S2 A/A (RO)；每一步都有進入條件、驗收與退場 |
| 產品期待 | Database Self-Service、EDC 資源活化、Observability；從 S0 起逐步交付 |
| 維運後勤 | 自控：PITR、Online DDL；協作：相容性、隔離級；原廠：方案、SLA |

### 結論句

先建立可驗收的能力，不預設採購或全面導入。

### 來源

[SLIDE-BRIEF-2026.md §3.1、§3.3、§3.4](./SLIDE-BRIEF-2026.md#3-推進路線三軌)

---

## Slide 10｜結尾

**狀態：顯示**

### 內容

Thanks.

---

## Slide 11｜S1 → S2 驗收

**狀態：隱藏｜現有頁碼標記：13**

### 標題

跨區先證明副本與切換，再開放就近讀

### S1｜A/S

- IDC 主寫；EDC 持副本。
- placement 設定與 readback。
- 副本數與實際位置驗證。
- EDC 讀取型 workload 分析。
- 切換與回復程序。

### S2｜A/A (RO)

- 寫入仍在 IDC；EDC 承接就近讀。
- near-read probe 必須證明讀取命中 EDC。
- 驗證 read-your-write、staleness 與 fallback。
- 驗證跨區分斷、恢復及 EDC 資料回抄 IDC。

### 原則

設定存在不等於功能生效；必須以執行面證據通過 fail-closed 驗證門檻。

### 來源

[SLIDE-BRIEF-2026.md §4.3–§4.4](./SLIDE-BRIEF-2026.md#43-phase-2-跨區-as-s1)

---

## Slide 12｜決策表 ①：業務適配與應用改造

**狀態：隱藏｜現有頁碼標記：14**

### 圖例

`O` 可行　`X` 不適用或不建議　`△` 有條件可行　`待測` 尚無本 PoC 證據

### 決策內容

| 決策問題 | PXC / Galera | TiDB | YugabyteDB / CockroachDB | 為什麼 |
|---|:---:|:---:|:---:|---|
| 能雙區同時寫嗎？ | X | **O** | △ | PXC / Galera 的 certification、衝突與 flow control 成本會受節點數及跨區 RTT 放大 |
| 能跨區放置資料嗎？ | X | **O** | O | PXC / Galera 不提供等同 placement 的資料散置能力 |
| 能跨區單寫＋副本嗎？ | △ | **O** | O | PXC / Galera 可做，但本輪跨區吞吐只有 298.8 tpmC |
| 能跨區就近讀嗎？ | X | **O** | O | PXC / Galera 無 follower / stale read 機制 |
| 單機房能多寫嗎？ | △ | **O** | O | PXC / Galera 在本次 HAProxy round-robin 多寫配置呈 0.49× 負向擴展 |
| 要換 driver / ORM 嗎？ | 免改 | **免改** | **需要** | PXC / Galera、TiDB 為 MySQL wire；YugabyteDB、CockroachDB 為 PostgreSQL wire |
| 錯誤重試要改多少？ | 高 | **低** | YugabyteDB 低；CockroachDB 中 | CockroachDB 在 quorum 遺失時可能回報 `ambiguous`，需應用層確認最終狀態 |
| 既有維運工具鏈可沿用嗎？ | O | 待測 | X | PXC / Galera 為現況；其他方案需要補齊工具與 runbook |

### 共同前置

SQL / ORM 相容性矩陣與 ID 生成改造屬四家共同前置，放入 Phase 0，不作為本表的產品鑑別列。

### 結論句

跨區四種核心情境只有 TiDB 全數可行；PXC / Galera 受同步複寫設計限制，PostgreSQL 系需要更換協定。

### 必須避免的舊誤植

- YugabyteDB、CockroachDB 的「協定不變」必須是 `X`，不可寫成 `O` 或 `△`。
- YugabyteDB 重試成本是低；CockroachDB 才是中。

### 來源

- [0827_slide.md「決策表 ①」](./0827_slide.md#y26決策表-業務適配--應用改造成本)
- [DECISION-MATRIX.md §3.1](./DECISION-MATRIX.md#31-主表可行性與適配)

---

## Slide 13｜決策表 ②：效能、跨區與復原取捨

**狀態：隱藏｜現有頁碼標記：15**

### 單區效能

| 指標 | PXC / Galera | TiDB | YugabyteDB | CockroachDB | 判讀 |
|---|---:|---:|---:|---:|---|
| 單節點 p99，越低越好 | **37.7 ms** | 597 ms | 216 ms | 440 ms | PXC / Galera 明顯領先 |
| 單節點 → 三節點 tpmC | 53,791.9 → 26,166.2 | 13,064 → 26,947 | 11,436 → 15,632 | 9,134 → 15,033 | PXC / Galera 與 TiDB 的三節點絕對值接近 |
| 水平擴展倍率 | 0.49× | **2.06×** | 1.37× | 1.65× | TiDB 本輪最高；倍率不是產品總排名 |
| t=128 五輪變異，越低越穩 | 43.2% | 7.4% | 7.1% | 6.9% | PXC / Galera 變異最高 |
| all-txn error rate | 0.037% | **0.000%** | 0.000% | 0.000% | PXC / Galera 是唯一非零 |

### 跨區

| 情境 | PXC / Galera | TiDB | YugabyteDB | CockroachDB |
|---|---:|---:|---:|---:|
| P-A × A/S，tpmC | 298.8 | **12,526.5** | 12,769.5 | 10,163.4 |
| P-A × A/A (RO)，GCP read_tpmTotal | n/a | **31,571.3** | 56,787.9 | 41,056.3 |
| P-B × A/A，GCP 側錯誤率 | **47.0%** | **0.158%** | 0.134% | 0.111% |

### 正確性

- PXC / Galera：quorum 遺失時曾出現非預期寫入成功，需重新確認保護條件。
- TiDB、YugabyteDB：乾淨拒絕寫入。
- CockroachDB：可能回報 `ambiguous`，需應用層確認最終狀態。

### Failover 判讀邊界

區域停止後復原的計時起點不同，不作跨產品排名：

- PXC / Galera：從 `t_kill` 起算 22.2 s。
- TiDB：從 `t_restart` 起算 39–44 s；從 `t_kill` 起算為 198–202 s。
- YugabyteDB：3.0 s，採另一套量測方法。
- CockroachDB：7.0 s，採另一套量測方法。

### 結論句

PXC / Galera 的單節點延遲最具優勢；TiDB 同時呈現正向擴展、低變異、零錯誤及跨區低錯誤率，較符合目前主線需求。

### 必須避免的舊誤植

- YugabyteDB 五輪變異為 7.1%，CockroachDB 為 6.9%，不可寫「待補」。
- YugabyteDB、CockroachDB error rate 都是 0.000%，不可寫「待補」。
- 水平擴展不得只列倍率，必須保留單節點與三節點分母。

### 來源

- [0827_slide.md「決策表 ②」](./0827_slide.md#y26決策表-效能與擴展--可用性與正確性)
- [DECISION-MATRIX.md §3.2](./DECISION-MATRIX.md#32-效能與可用性實測原始數字跨組僅供交叉參考)

---

## Slide 14｜候選定位

**狀態：隱藏｜現有頁碼標記：07**

### 標題

四家不是同一賽道：先按協定與使用情境定位

| 候選 | 協定 | 本輪角色 | 適用定位 |
|---|---|---|---|
| TiDB | MySQL | 主線 | 水平擴展、跨區 A/S、A/A (RO) |
| PXC / Galera | MySQL | 對照與保留選項 | 單寫、單機房、低延遲 |
| YugabyteDB | PostgreSQL | 備選 | 高關鍵度 PostgreSQL 或 AI 應用需求 |
| CockroachDB | PostgreSQL | 備選 | 同上；待需求觸發 |

### 結論句

公司目前 MySQL 業務占比約 95%；PostgreSQL 路線不與 TiDB 同時展開完整導入矩陣。

### 來源

[SLIDE-BRIEF-2026.md §2.1](./SLIDE-BRIEF-2026.md#21-候選與定位區隔)

---

## Slide 15｜決策表 ③：維運後勤與證據缺口

**狀態：隱藏｜現有頁碼標記：16**

| 項目 | 目前狀態 | 需要補的證據 |
|---|---|---|
| PITR / 備份還原 | 待測 | 全量、增量、資料對帳與可重複 runbook |
| Online DDL | 待測 | DDL 期間 tpmC、p99、錯誤率與影響持續時間 |
| HTAP / 分析型負載 | TiDB 待測 | 其他方案不列入本輪 |
| 原廠在地支援 | TiDB 已有 24×7 中文與台灣 SA | 其他方案依需求觸發 |
| 既有 DBA 技能承接 | PXC / Galera：O；TiDB：△ | PostgreSQL 路線需另建能力 |
| SQL / ORM 相容性 | 四家待測 | Phase 0 必須補件 |

### 結論句

相容性、PITR / 備份還原、Online DDL 是目前最大的證據缺口；完成前不得提出正式導入承諾。

### 來源

- [0827_slide.md「決策表 ③」](./0827_slide.md#y26決策表-維運後勤)
- [DISTRIBUTED-DB-SCORING.md](../DISTRIBUTED-DB-SCORING.md)

---

## Slide 16｜Y25 證據

**狀態：隱藏｜現有頁碼標記：05**

### 標題

Y25 已解兩個前提，也留下明確邊界

| 面向 | 結論 |
|---|---|
| 應用改造 | `ac-api` 完成 ULID / Snowflake 改造；deadlock 與連線錯誤已處理；2026-08-26 TiDB 複測通過 |
| 跨機房分流 | Cloudflare LB 通過分流與 IP sticky；F5 不符合需求 |
| 單寫先行 | ATS Pro 因 multi-write deadlock 回到 single write；產品不必等待 A/A 才推進 |

### 邊界

- 僅涵蓋 4 支特定 AC API。
- 流量鏡像到 TiDB 後只剩 113 QPS。
- 「灌入 AC API 總量」未執行，不能外推為正式容量。

### 來源

[SLIDE-BRIEF-2026.md §1.1、§1.5](./SLIDE-BRIEF-2026.md#11-y25-poc-範疇--驗證小結)

---

## Slide 17｜交付邊界

**狀態：隱藏｜現有頁碼標記：10**

### 目前可交付

- MySQL 協定路線與分散式資料庫架構改造方法。
- 水平擴展與高併發穩定性證據。
- 跨區 A/S、placement 與副本存在驗證。
- 跨區就近讀的測試路徑。
- Kubernetes 部署與資源配額控制。
- 原廠在地技術協作入口。

### 正式導入前仍需補證

- 端到端 A/A 或整區秒級自動接手。
- SQL / ORM 完整相容性。
- PITR 還原與 Online DDL 影響。
- 跨區 WAN 成本的同條件 paired control。
- P-B 高併發下降的控制實驗。
- Failover 統一口徑。

### 結論句

技術可行性、可營運性與正式導入承諾必須分開表述。

### 來源

[SLIDE-BRIEF-2026.md §2.4.1–§2.4.2](./SLIDE-BRIEF-2026.md#24-能做什麼--不能做什麼)

---

## Slide 18｜TiDB 目前可完成的事

**狀態：隱藏｜現有頁碼標記：17**

### 能力與證據

| 能力 | 證據 |
|---|---|
| 跨區資料同步不漏寫、不寫錯 | Y25 AC API 複雜寫入場景完成鏡像驗證 |
| 應用不改協定即可接上 | MySQL wire；完成 ID 改造後 TiDB 複測通過 |
| 水平擴展與高併發穩定 | 1 node → 3 node 2.06×；t=128 error rate 0.000% |
| 跨區 A/S | P-A × A/S 完成；副本、placement 與近讀探測通過 |
| 跨區 A/A (RO) | GCP read_tpmTotal 31,571.3；全程 0 error |
| 資料位置控制 | P-A、P-B 皆可設定並 readback 驗證 |
| quorum 遺失保護 | 寫入乾淨拒絕，不會靜默成功 |
| Kubernetes | S-K8S limit / unlimit suite 完成，保留 throttling、OOM、storage 證據 |
| EDC 活化 | 將備援副本逐步轉為讀取型工作負載 |

### 來源

- [0827_slide.md「可以完成的事」](./0827_slide.md#y26根據目前-tidb-的評估我們可以完成的事)
- [SLIDE-BRIEF-2026.md §2.4.1](./SLIDE-BRIEF-2026.md#241-根據目前-tidb-的評估我們可以完成的事)

---

## Slide 19｜現有架構限制

**狀態：隱藏｜現有頁碼標記：18**

### 架構限制

- 目前不能承諾端到端 A/A。
- 目前不能承諾整區故障秒級自動接手。
- 單節點故障仍可能被 client 感知。
- 低延遲敏感場景不能直接以 TiDB 取代 PXC / Galera。
- Cloudflare + F5 sticky session 與 GCP Ignore-TCP-MSL 無法對等移植。

### 證據缺口

- SQL / ORM 相容性。
- PITR / 備份還原。
- Online DDL。
- WAN 成本 paired control。
- P-B 高併發下降根因。
- HTAP / 向量檢索。
- Failover 統一口徑。

### 本輪不做

- PostgreSQL 路線：待明確業務需求後排程。
- Redis 多寫多讀：待需求發生後規劃。
- `ac-api` PROD 整合與流量 mirror：Y27 再安排。

### 結論句

結論強度必須與證據等級一致；待測不等於不可行，已測也不等於可以直接導入。

### 來源

- [0827_slide.md「不能完成的事」](./0827_slide.md#y26根據現有架構我們不能完成的事)
- [SLIDE-BRIEF-2026.md §2.4.2](./SLIDE-BRIEF-2026.md#242-根據現有架構我們不能完成的事)

---

## 4. 重構驗收基準

後續修改 `0827_slide_codex_v2.pptx` 時，至少檢查以下項目：

1. 19 頁順序與顯示／隱藏狀態維持不變。
2. 每頁只保留一個核心結論，數字必須附單位與測試情境。
3. 決策表保留四產品比較，不得改成只呈現 TiDB 的卡片。
4. TiDB 可凸顯為本輪主線，但必須同時呈現 PXC / Galera 的低延遲優勢與 TiDB 的已知缺口。
5. 不把不同 workload、placement 或 Failover 計時口徑直接比較。
6. Slide 12、13 的誤植修正必須套用。
7. 來源行、測試條件與判讀邊界不得為了版面精簡而移除。
8. 不新增內部 prompt、review、版本說明或 AI 作業文字到投影片。
