# Y25 多寫多讀混合雲 POC — 總結彙整

**資料來源**

| 來源 | 內容 |
|---|---|
| `2601_多寫多讀混合雲POC專案總結.pdf`（SSD + TSD，2026-01） | 官方定案總結簡報，8 頁 |
| Jira `labels = "Y25_多寫多讀POC"` | 42 單（Task 8 / Sub-task 34），**全部 Done** |
| Jira comments | 34 單有留言，主戰場 ISGDMGR-1520（16 則會議紀錄） |

- Jira 擷取日期：2026-08-25；單據期間 2024-09-27 建立 → 2026-01-09 最後更新
- 參與專案：ITDBA(17)、ISGDMGR(11)、ITSE(7)、ITNET(2)、ITHVM(1)
- Jira 查詢：<https://104corp.atlassian.net/issues/?jql=labels%20%3D%20%22Y25_%E5%A4%9A%E5%AF%AB%E5%A4%9A%E8%AE%80POC%22>

---

## 0. 官方專案總結（2601 簡報，最終定案）

### 0.1 專案定位

- 配合公司**長期技術策略**，長期規劃關鍵網站服務朝向多寫多讀混合雲架構運行
- 本專案為長期技術策略**子案**，旨在**填補 Cloud Foundation Layer 技術缺口**
  - Cloud Foundation Layer 用來隔離「應用程式」與「基礎建設」直接關連，從而讓應用程式具有可攜性
- 期待未來達到 **104 封站時，使用關鍵服務的客戶不受影響**

### 0.2 Y25 POC 範疇 / 驗證小結（三大範疇）

| 範疇 | 做法 | 小結 |
|---|---|---|
| **分散式資料庫（MySQL、TiDB）與 MQ** | 透過 ac-api 流量鏡像整合測試，驗證跨雲資料同步的可靠性與效能表現 | 配合新增 AI 專案調整資源配置，**Y25 測至 STG**，觀測結果見下 |
| **跨機房分流機制** | 建立測試用對外應用程式 `whereami`，實測多區域流量分配的效果與穩定性 | **8/M 完成 Cloudflare LB 測試，符合分流及 ip sticky 需求**；**F5 未能滿足需求情境** |
| **其他 SSD 自行驗證組件功能** | 針對多雲環境所需的各項基礎設施組件做內部驗證 | **10/B 完成 PROD 環境內部驗證，無議題** |

**分散式資料庫觀測結果（簡報原文三點）**

1. **TiDB 作為分散式資料庫，在多寫多讀架構上表現出優勢**
   - 跨區存取回應速度落差小
   - 無任何漏寫或寫錯的紀錄
   - 相較傳統 DB（ProxySQL + MariaDB），處理速度更快
2. **在分散式架構下，跨機房使用類似 DX 之專線服務是必要投資**
3. **本次測試具備部分代表性**
   - 能處理 AC 最複雜的寫入場景，其它單純寫入跟讀取應不太會出錯
   - 雖未擴大流量測試，但預期可透過水平擴展計算或儲存節點來應對

### 0.3 Y26 測試安排（定案）

1. **續存 ac-api LAB & STG 測試環境**以持續收集問題 —— **AWS & GCP Y26 有估預算**
2. **DBA 自控 MongoDB Multi-Cloud（IDC + EDC）架構測試**
3. **ac-api 整合及流量 mirror 至 PROD 預定 Y27 再安排**（實際視未來策略及專案優先規劃調整而定）

> 註：此處與 Jira 2026-01-08 留言「Y26 年中再決策是否保留環境」不同 —— **簡報為後續定案版本，環境確定續存且已編列預算**。

### 0.4 預期的混合雲樣貌轉變過程 (Needed)

| 期間 | 網站可觀測性與 API 架構改善 | IT 基礎建設 | 預期結果 |
|---|---|---|---|
| **2024** | 使用 Service Mesh 讓 K8s 應用程式獲得服務拓樸圖 | AC 雲地都部署，資料**一寫多讀** | IDC 失效時 AC 服務降級，關鍵服務受影響變小 |
| **2025–2026** | 拓樸資料識別潛在弱點並提出改進；Grafana Loki 投入使用 | 多寫多讀技術選型及架構規劃，範圍選定**分散式 RDBMS**、**RabbitMQ** | 對多寫多讀架構的可行性跟功能範圍進行探索與學習 → 確認技術架構對本司應用程式是否可行 |
| **2026–future** | **因應 AI Agent Task Force 調整內容** | **因應 AI Agent Task Force 調整內容** | 累積多寫多讀架構的日常維運經驗並進行災難演練 → **AC 多地部署、多寫多讀，當 IDC 機房失效時 AC 能持續運作不降級** |

### 0.5 SSD 自行驗證組件 —— 盤點原則與排程 (Needed)

**盤點原則**
- 確認地端 Infra 組件功能或已知應用情境，雲端是否能滿足；若否則確認解決方案（**解決方案不一定需滿足多寫多讀**）
- 考量 POC 搭配少數關鍵產品測試，不會測到所有情境，會盡可能在可測範圍做情境驗證
- 除資料庫預期搭配流量鏡像測試，其他項目由 SSD 自行做功能驗證

| 確認單位 | 驗證標的 | 排程 |
|---|---|---|
| HVM | 外部 DNS / 內部 DNS / Proxy / NTP | Y25 |
| NET | GSLB / SLB / Firewall | Y25 |
| **DBA** | **MongoDB** | **Y26** |
| SE + Search | Search | Y25 |
| SE | OMS | Y25 |
| SE + TSD | Vault | Y25 |

### 0.6 SSD 不驗證項目（明確排除） (Needed)

| 單位 | 標的 / 應用情境 | 不驗證原因 |
|---|---|---|
| SE | OMS 寫檔寄信 | 未來都轉 SMTP，SMTP 已在目前驗證範圍 |
| SE | Assessment | 網站設計過時、無法支援 AA mode、未來不續存；**為產品端需處理問題** |
| SE | Memcache | 無法支援 AA mode、未來不續存，預期轉移至 Redis |
| SE | **AP** | 未來都轉入 K8s 即享快速遷移部署之機制 |
| HVM | NetApp | 檔案規劃以 MVS 作為主要存儲媒介 |
| HVM | VMWare | 已確認有對應雲端服務可訂閱 |
| HVM | Pure Storage | 已確認有對應雲端服務可訂閱 |
| **DBA** | **Redis** | **待有實際需求發生時再規劃安排** |

---

## 1. Jira 全單彙整 — 結論

1. **全案已結案**：42 張單全數 Done，主線收斂在 ISGDMGR-1520（PM 主單）與 ITDBA-3149（DBA PoC 主單）。
2. **驗證範圍**：DB（MySQL 8.4 Galera / PXC / Group Replication、TiDB）＋周邊元件（RabbitMQ、Vault、Search、OMS）＋基礎設施（GCP FW/LB、DNS、Proxy、NetApp、虛擬化）。
3. **產品標的**：原訂 ATS 專業版，**2025-03-10 決議排除**，改以 **AC / ac-api** 為 MySQL 與 MQ 的主要驗證標的（MySQL 5.7 不測）；TiDB 側接洽 CAPP intra-video、SMS API、APIM2。
4. **未完部分已展延**：ac-api PROD 因專案優先序（AI Agent Task Force）**延至 Y27**；RabbitMQ PROD 延至 Y26/Q3，資源先釋放。
5. **環境去留（已定案）**：Jira 12/19 留言尚在爭論保留與否（GCP 約 **330,408 元/年**，含 AWS 估 **50 萬/年**，替代方案為改測 IDC + EDC）；**2601 簡報定案為續存 ac-api LAB & STG，AWS & GCP Y26 已編預算**（見 §0.3）。
6. **策略風險**：若 AWS 下雲力道大 → 趨向單一機房，多寫多讀混合雲效益下降（曜祥意見）；James 認為 AWS 下雲 Phase 2 後不易執行，仍會留服務。

---

## 2. 專案北極星目標（ITHVM-316）

- 不因任何一 Region / DC 維護或作業而封站
- 多地多機房可解析；引導流量就近存取
- 不因 DC 間 Latency / Delay 產生影響
- 盡量在現有商務邏輯下，減少 RD 重構工程即完成資料庫架構重構
- **能 Multi Write 就不考慮 Major Write + Multi Read**
- 清楚掌握 Cross-DC 的 Latency / 2PC issue
- 避免過度設計

---

## 3. 單據結構

### 3.1 主單

| Key | Summary | Owner |
|---|---|---|
| ISGDMGR-1520 | Y25 多寫多讀混合雲POC（Critical，PM 總管理） | Ellen Lin 林鈺涵 |
| ITDBA-3149 | [Y25][PoC] TiDB Cluster & MySQL 8.4 LTS + Galera Survey & PoC Planning | Wn Lin 林武男 |
| ITNET-2018 | Y25-多讀多寫混合雲POC | Adam Chen 陳柏玗 |
| ITHVM-316 | [Y25_HVM專案] Y25 多寫多讀混合雲POC | Andy Luo 駱昱帆 |
| ITSE-2324/2325/2326/2327 | SE 專案：RabbitMQ / vault / Search / OMS | Robin、Austin、Hill |

### 3.2 DBA 線（ITDBA，全由 Wn Lin 承接）

| Key | 分類 | 內容 |
|---|---|---|
| ITDBA-3196 | 常規維護 | 定期會議記錄（每週 30 分鐘） |
| ITDBA-3197 | Survey | 事前 Survey 與環境準備 for MySQL |
| ITDBA-3093 | Survey | MySQL 8.4 Migrate Plan |
| ITDBA-3094 | Survey | TiDB 8 Migrate Plan |
| ITDBA-3198 | 實作 | 技術驗證與環境搭建 for MySQL |
| ITDBA-3199 | 實作 | 架構混沌測試 for MySQL |
| ITDBA-3200 | 實作 | 故障恢復與一致性驗證 for MySQL |
| ITDBA-3203~3206 | 實作 | TiDB：環境準備 / 技術驗證 / 混沌+效能 / 故障恢復 |
| ITDBA-3169 | 實作 | Distributed System Architecture implement |
| ITDBA-3202 | 產品驗證 | AC-API 功能及可用性驗證 |
| ITDBA-3208 | 產品驗證 | PoC 產品功能及可用性驗證（壓測 + Failover 通過率） |
| ITDBA-3170 / 3171 | 產品驗證 | ATS Pro Web / APP PoC |
| ITDBA-3168 | 結論 | PoC Report |
| ITDBA-3201 / 3207 | 結論 | MySQL / TiDB 結果分析與報告 |

### 3.3 PM 線（ISGDMGR 子任務，時程規劃）

| Key | 項目 | 期程 |
|---|---|---|
| ISGDMGR-1595 | GCP 架構規劃 | 1/10~2/14 |
| ISGDMGR-1579 | 協作產品討論及接洽 | 1/13~2/27 |
| ISGDMGR-1572 | GCP LAB 環境建置 | ~2/27 |
| ISGDMGR-1573 | GCP STG 環境建置 | 3/3~3/31 |
| ISGDMGR-1575 | LAB 跨雲測試 POC / TiDB 測試 | 3/3~4/30 / 8/1~10/31 |
| ISGDMGR-1576 | STG 跨雲測試 POC | 4/1~5/30 |
| ISGDMGR-1580 | 產品 POC 及綜合驗證 | 6/2~ |
| ISGDMGR-1578 | POC credit 申請 | 7/15~9/30 |
| ISGDMGR-1574 | GCP PROD 環境建置 | 9/1~9/12 |
| ISGDMGR-1577 | PROD 跨雲測試 POC | 9/12~10/31 |
| ISGDMGR-1581 | 下半年及 Y26 驗證安排 | 10/1~ |

---

## 4. 技術驗證重點

### 4.1 MySQL 8.4 多寫（ITDBA-3093 / 3198 / 3199 / 3200）

**候選方案（四選）**
- MySQL 8.4 Group Replication
- mysql-wsrep-8.4 + Galera-4
- Percona XtraDB Cluster 8.4
- Percona Distribution for MySQL 8.4

**實驗設計**
- 實驗組：Percona XtraDB Cluster；對照組：Galera Cluster、Group Replication
- 環境：IDC vSphere（3 nodes；2 nodes + garbd 1）＋ GCP Compute Engine **Spot VM**，並串成跨雲單一 cluster
- IaC 部署流程設計，保留往 AWS EC2 延伸的彈性
- 監控：PMM3；設計 P95/P99 呈現與 Growth Rate 模型

**Benchmark 指標**
- 吞吐量：TPS、QPS、批量寫入
- 延遲：讀 / 寫 / 跨區域同步延遲，SLI 取 P95 / P99
- 一致性：一致性檢查結果、衝突解決時間、同步完成時間
- 可用性：可用性百分比、故障轉移時間、RTO / RPO

**混沌 / 故障測試場景**
- 正常：標準負載、混合讀寫
- 異常：網路延遲模擬、節點故障恢復、區域故障切換、資料衝突解決

**已知風險（來自 ITSE-2324 注意事項）**
- Multi-write 下需注意 `AUTO_INCREMENT`、`ON UPDATE`、`ON DELETE`
- 節點間 **clock skew** 會提高 cert 驗證失敗與資料衝突機率

**遷移作業程序（ITDBA-3093）**
1. DBA 產品維運情境設計 & 規劃
2. 新開發產品 ATS Pro 導入方式
3. MariaDB → MySQL 8.4 Cluster（資料同步 → 狀態驗證 → 流量切換）
4. MySQL 5.7 → MySQL 8.4 Cluster（同上三步）※ 後續決議 5.7 不測

### 4.2 RabbitMQ（ITSE-2324，四階段全數完成）

- 版本：RabbitMQ 3.13.7 / Erlang 26.2.5.6
- 原則：**不用雲商 MQ（避免 vendor lock-in）**；Client 不跨 Region 連線；GCP 優先，AWS Taipei 後議，不測 AWS Tokyo
- 架構：跨雲單一集群，GCP 2 nodes + IDC 1 node，Site-to-Site VPN
- 技術：Quorum queue、Shovel、Federation
- 測試（PerfTest + tc）
  - 吞吐量：地端 / 雲端 / 雲地集群 1000~10000 msg/s；含「不連 leader node」情境
  - 網路：server-side 延遲 100~5000ms；client-side 延遲 50~400ms、遺失率 0.1~5%、混合測試
  - 故障：單節點 / 多數節點 / 全節點故障；GCP 防火牆與 iptables 兩種網路分區模擬；3+2 節點分區異常
- 產品測試以 AC 為主，K8s service mesh 將流量 **mirror** 到 PoC 環境
- Lab / Stg 完成（10 月底整合測試 + 流量 mirror）；**Prod 延至 Y26 Q3（10/7 決議，資源先釋放）**

### 4.3 Vault（ITSE-2325 / 2351-2353，Lab/Stg/Prod 三環境）

| 架構 | 雲地斷線結果 |
|---|---|
| 同一 cluster：IDC 2 nodes + GCP 1 node | 多數節點側正常；單節點側服務失效，需**手動啟用 standalone cluster** 恢復；資料同步交由底層 raft；復線需手動刪 raft 資料、改設定檔再加回 cluster |
| 兩個獨立 cluster：IDC 3 + GCP 3 | 兩側皆正常運作；以 **medusa** 定時排程同步，備份倒回皆可取得 secret；復線以一邊資料為主做備份倒回 |

- 另：secret vault 獨立 cluster + script 非即時同步；pki / key 獨立 cluster

### 4.4 Search（ITSE-2326，議題盤點為主）

- 雲地各自 rebuild & copy index 於各自雲內完成，讀同一份 DB 資料，避免跨 Zone 頻寬爆量
- 待解：即時 index 同步機制、rebuild 後 index 的儲存空間

### 4.5 OMS / 郵件（ITSE-2327）

- 問題：Javamail mount 同一 NA 資料夾造成重複發信；SPF/DKIM 需在 DNS 多註冊；MX 多組設定
- 方向：雲上只做 SMTP 發送，Javamail 留地端（解重複發信）
- 待議：信件種類分流（系統驗證信優先）、雲端 Public IP 寄信限制、EDM 大量發信以 SD 備援、MTS3.0 相容性

### 4.6 網路 / 基礎設施（ITNET-2114、ISGDMGR-1573、ITHVM-316）

- GCP Firewall 選型：VPC firewall rule、Firewall policy、Fortigate BYOL（PAYG USD 744.60/mo）、Cloud Armor
- **決議走 GCP 雲原生 Solution**，不用 IDC Solution（Fortigate 744.6/月、A10 883.3/月；第三方較貴，且 NET 不以維運一致性為必要理由）
- **A10 Ignore-TCP-MSL 風險**：已確認 GCP SLB 無此功能。該功能用於忽略 1 秒內重用剛關閉 source port 的連線以避免 alert；Angus 認為屬 A10 獨有機制，AWS 經驗未遇類似狀況，建議以壓測驗證
- GSLB（Cloudflare & F5）預定 3 月底測完
- GCP DR 改用 EDC proxy，不另建 proxy（7/2 決議）
- HVM 分工：DNS/NTP、Proxy、NetApp 儲存、虛擬化/網路層

### 4.7 對外服務分流驗證（ISGDMGR-1577）

- 分流：由 NET 在 Cloudflare / F5 設定並驗證指定比例導向 IDC / GCP
- **IP sticky**：user 端 IP 分群 A/B/C 各自 stick 至指定機房，僅單機房不通時全數導向另一機房；以測試應用程式呈現落點，SSD 全員以手機參與測試
- 測試應用程式：`whereami.104.com.tw`（由 whoami.104.com.tw 遮罩敏感資訊後另部署）
- CF 可處理 Layer 7 client 資訊、F5 處理 Layer 4；規劃初期**以 F5 驗證為優先**
- **最終結果：F5 未能滿足需求情境，改由 Cloudflare LB 於 8/M 通過驗證**（見 §0.2、§8.6）

---

## 5. 成本

| 項目 | 金額 |
|---|---|
| GCP 環境保留 | 330,408 元/年 |
| 加計 AWS 估算 | 約 50 萬元/年 |
| POC credit 申請 | USD 7,000（5,000 已於 12 月帳單折抵、2,000 於 3 月帳單折抵） |
| Fortigate（GCP PAYG） | USD 744.60/月 |
| A10（比較基準） | 883.3/月 |

---

## 6. Y26 規劃 —— 討論過程與最終定案

> **定案版本請看 §0.3（2601 簡報）**；本節保留 Jira 上的討論脈絡與被否決的選項。

**Jira 討論過程（ISGDMGR-1520 / 1581，2026-01-08 專案總結會議）**

1. **是否保留 AWS & GCP 環境續測**（當時未定）
   - 留：可觀察 AC 調程式後的影響、避免重啟專案時全部重建
   - 不留：重啟專案本來就會全部重測才安心
   - 曾評估改到 **IDC + EDC** 的可行性與 effort（SE/DBA 建地端設備 → TSD 設 mirror 及部署程式（可能需 AC 協助） → HVM/NET 將 EDC 對外）
   - 當時結論：年中再確認觀測情況與策略方向，決定是否撤環境
2. **展延項目**：ac-api PROD 於 Y26/Q3 後才有機會續行，2027 年再重啟整個剩餘項目
3. **剩餘測項**：Mongo、AP 由 DBA/SE 評估 Y26 測項；NetApp 無法進 MVS 的檔案由 HVM 評估（見 ITHVM-350）
4. **DBA 方向**：Jimmy 回饋 DBA 將逐步以 **MongoDB** 測試 IDC + EDC 分流 / AS / AA 架構可行性
5. 結論彙整參閱 ISGDMGR-1570

**最終定案（2601 簡報）**

| 議題 | Jira 討論 | 簡報定案 |
|---|---|---|
| 環境去留 | 年中再議，或改 IDC+EDC | **續存 ac-api LAB & STG，AWS & GCP Y26 有估預算** |
| ac-api PROD | Y26/Q3 或 Y27 | **Y27 再安排** |
| MongoDB | Jimmy 提議 DBA 測 IDC+EDC | **DBA 自控 MongoDB Multi-Cloud（IDC+EDC）架構測試** |
| Redis | 12/19 改為不驗證 | **待有實際需求發生時再規劃安排** |

---

## 7. 重要外部連結

- PoC 報告：<https://github.com/104corp/dba-documents/blob/master/3.Project/Distributed_Database_Architecture/PoC.md>
- GCP 架構規劃（Vic）：<https://codimd.104.com.tw/s/P6LM9mFsZ>
- 雲多讀 POC GCP 架構規劃：<https://codimd.104.com.tw/DkNy8WHvTECTJoy584QHlQ?view>
- MySQL 基準測試矩陣：<https://codimd.104.com.tw/s/Td1Cn2MTc>
- 測試報告格式：<https://codimd.104.com.tw/s/B4dlMS9nw>
- 環境建置需求：<https://codimd.104.com.tw/s/D_KK2_G-w>
- RabbitMQ 跨雲架構調查：<https://codimd.104.com.tw/BvqZJh0_QtKwIuE2CqaVQQ>
- RabbitMQ 測試計劃：<https://codimd.104.com.tw/s/vkYTvta8o>
- tc 網路模擬工具：<https://codimd.104.com.tw/s/SonDFAswt>
- Galera vs Standalone MySQL 差異：<https://codimd.104.com.tw/Pz8M0cqWRDSVqLrJs7PwmA?view>
- TiDB 相關：<https://codimd.104.com.tw/EQaiivv7Sje0N-G9M2cxlg>
- Vault 測試 issue：<https://github.com/104corp/k8s-vault-secrets/issues/1507#issuecomment-2683996955>
- whereami 測試程式：<https://github.com/104corp/104tsd/issues/20>

---

## 8. 各單 comments 中的關鍵結論

> 說明：以下為 description 未載、僅出現在留言的決議與數據。留言總量 42 單中 34 單有留言，主要集中在 ISGDMGR-1520（16 則會議紀錄）。

### 8.1 資料庫：最終技術結論（ISGDMGR-1520，2025-12-19 會議）

TiDB mirror + 效能觀測小結（Ellen 規劃 Y26/1 向 James 報告）：

1. **TiDB 在多寫多讀架構上表現出優勢**
   - 跨區存取回應速度落差小
   - **無任何漏寫或寫錯的紀錄**
   - 相較傳統 DB（ProxySQL + MariaDB）處理速度更快
2. **跨機房專線（類似 DX）是必要投資**：觀察到高 Latency / 低頻寬環境下**寫入速度大幅下降，讀取仍保有效率**；導入前須考量網路短暫不穩定的影響
3. **代表性有限但具部分代表性**
   - 刻意挑選 AC API 中**最複雜寫入場景**的 API 測試，過程無漏寫/寫錯
   - 僅涵蓋 **4 個特定 API**：壓測時 MariaDB 收到近 **6K QPS**，轉換後 MariaDB 內部剩 **2K QPS**，mirror 到 TiDB 後**只剩 113**
   - 「灌入 AC API 總量」的驗證因資源挪動未執行，Y27 重啟時再安排
   - 預期可透過水平擴展計算 / 儲存節點處理
4. Wn 補充：目前完成的是**資料庫架構層級的初步效能對照**，非完整一對一比較；架構與設定仍有優化空間
5. 撤 GCP 節點的疑慮已澄清：測試期間 DB 架構與 GCP 持續同步；即使移除 GCP TiDB 節點仍可正常觀測，僅退化為單一 IDC TiDB 叢集，**無相依性疑慮**

### 8.2 MySQL Galera vs TiDB 的取捨（ISGDMGR-1581，2025-08-11）

| 議題 | 結論 |
|---|---|
| TiDB 壓測 error rate | **thread 200/250 之後開始出現 error**；預期熟悉後可用參數緩解 |
| 設備規格 | TiDB **需要比 MySQL 更高規格**的設備 |
| MySQL Galera 是否續測 | **以 TiDB 為優先**。調成貼近 AP 特性可提升部分 performance，但**看不出投入的明顯效益** |
| acapi concurrency 衰減 | MySQL 在 **寫入情況下衰減特別多**（ISGDMGR-1520，8/4） |

### 8.3 concurrency 無法對標（ISGDMGR-1520，9/1 會議）

- 各服務行為與資料差異大，**無法明確定義產品 concurrency 該定多少**才符合效能指標
- 分散式效能與架構設計、流量特徵高度相關，**非單一指標可充分評估**
- 工具壓測所得僅代表特定情境
- 實際效能表現應以 **Mirror 搭配真實流量**模擬產品行為與資料做壓測來檢視

### 8.4 AC-API 為了多寫必須做的程式改造（ITSE-2324 / ISGDMGR-1580）

雲地同時寫入 DB 遇到問題，根因與解法：

1. **移除 AUTO_INCREMENT → 改用 ULID**（7/10 會議，以 `cellphone_verification` 為例，四步驟）
   - 加 `ulid` 欄位 + unique key → 工程寫 AP 洗資料 → 程式端產 ulid 並改以 ulid 查詢 → 上版後移除 `id`、`ulid` 設為 P.K.
2. **pid / idno**：改用**變型 Snowflake 演算法**做 workaround（需先討論參數 bit 分配）
3. **deadlock、pdo 連線錯誤**：待 1、2 調整後再確認
4. 排測結論：**只有「HA 設定帳號」「建立 VIP 帳號」兩個功能有問題**，更新（寫入既有資料）與讀取沒問題

**測試通過時點**
- 2025-08-20 AC API 調整後 LAB 複測通過；2025-08-26 TiDB 測試通過
- 2025-10 月底完成 STG istio ingressgateway；**PROD 不做**（評估 STG 與 PROD 架構/流量無異，代表性已足）

### 8.5 ATS Pro 的兩次轉折

| 時點 | 決議 |
|---|---|
| 2025-01-22 | DBA 判斷相關 DB 皆已 EOL，進 MySQL 8.4 LTS 較合適；但 Y25/Q2 上線仍以 IDC 流量為主，避免跨雲降低可用性 |
| 2025-03-10 | **ATS 專業版先不納入多寫多讀測試範疇**（改以 AC API 滿足 MySQL 測試），年底再視成果評估是否納入報告 |
| 2025-06 | LAB 提供跨區約 **6ms** 延遲情境給開發團隊；ATS Pro 尚在開發，需進壓測階段才有回饋 |
| 2025-08-11 | Wn：**多寫的 deadlock 已會影響上線**；共識等走到 STG 再揭露跳回 |
| 2025-11-19 | **ATSP 確定改回 Single Write 架構** |
| 2025-11-19 | ATS Pro 定期會議最後一次；產品上線與 PoC 進度脫鉤 |

ATSP 上線規格（2025-09-17）：staging/prod 各 `mysql × 3`（8C/64G/550G）+ `proxysql`（2C/4~8G/20G）
ATSP 時程：Web Y25/Q4（10 月 STG、11 月 PROD）、Mobile Y26/Q1

### 8.6 網路 / 分流的實測結論

| 項目 | 結論 |
|---|---|
| Ignore-TCP-MSL、syn-cookie | **無法在 GCP 重現**；TSD 評估**影響不大**（4/29） |
| F5 GSLB | 已驗證沒問題；IDC 實作分流 + sticky 有效（費用 0） |
| **Cloudflare + F5 架構** | **Sticky session 無法生效** — 同一客戶端多次請求未持續綁定同一叢集（8/4）。原因：來源 IP 到 F5 只看得到 Cloudflare 的 IP |
| Cloudflare public LB | 8/13 啟用測試**符合需求**；架構調整較小、計價與 private LB 相同 → **不再測 private LB** |
| Cloudflare 計價（Enterprise） | 只計 IP：**10 IP = NTD 39,600/月**、20 IP = NTD 66,000/月（未稅）；同一 IP 出現在兩地 Pools 需算兩個 |
| 潛在費用推估 | AC、VIP、B APP、主網、C APP 五個產品雙地部署 → 可能 **20 IP = 66,000/月** |
| F5 測試設定 | IDC : GCP = **9:1**，ip sticky 預設 1 小時；為驗證 sticky 建議改 6:4 |
| 驗收條件 | IP/session inactive 一定時間（先以 10 min）後再次存取仍固定在同一機房 |
| 測試工具 | `whereami.104.com.tw`（7/9 建置完成，不能用公司內部網路連） |

**Cloud Armor 實測限制（ITNET-2114）**
- 單一 rule 的 **expression 最多 5 個**，每個 `inIpRange()` 都算 1 條（不論 AND/OR）→ base mode 只能放 10 個 range
- 自動更新 Cloudflare IP 的兩條路都有代價：address group 需啟 API（**USD 1.75/hr**）、Google Threat Intelligence（**USD 200/月**），且 Armor Policy 建立不成功
- **最終做法**：以腳本 `fw-rule-update cloudflare ip whitelist-script.txt` 在地端定期執行更新 firewall rule
- site24x7 來源 IP **不支援 FQDN** 形式

### 8.7 其他元件

- **Search（ITSE-2326）**：GCP 上 build index → 寫入 tomesrch web local disk → web loading index OK；index watch 機制正常；接地端 queue 正常
- **OMS（ITSE-2327）**：雲端無法代理對外寄信，需第三方（類似 SES）；dev 測試 relayhost 至地端 `mail.104-dev.com.tw` OK。**LAB 驗證即滿足需求**，不往 STG/PROD
- **RabbitMQ 環境**：Lab `mq-jb-c.104dc-dev.com`（GCP 2 nodes + IDC 1）、Staging `mq-jb-c.104dc-staging.com`；Cluster 間 Latency **7ms**
- **混沌測試工具建議（曜祥，ITDBA-3199）**：對外連線加 TCP Proxy 模擬網路狀況，推薦 **toxiproxy**（slow / bandwidth / timeout）

### 8.8 收尾與資源撤除

- **2025-10-21：不使用的 GCP PROD 專案已全數刪除**
- 撤除前月費：SE **TWD 7,383** / HVM **4,058** / Infra **2,720**
- SE 撤掉、HVM 討論後回報、Infra 評估與 K8s 整併（讓三環境架構一致）
- **Redis 改為不驗證**（2025-12-19），待有實際需求再規劃
- **MongoDB 只能單寫多讀**，Y26 測試重點放在 **failover 功能測試**（9/24）；先不估預算除非曜祥發話
- Y26 GCP 預算：**PROD Infra 以外的費用全刪**；AWS 預算不調整（保留 acapi mirror 資源收集資訊）
- **GCP 帳號額度警訊**：AD 認證免費額度 50U 已用 48U（多寫多讀佔 18U），可刪 10U；否則新增使用者需買 Premium licenses（**未編預算**）
- SE + HVM Y26 不排測項，但需預留支援 acapi 環境的 MQ 問題排除資源
- DBA Y26 方向：TiDB 持續營運測試（K8s 部署流程、RD Self-Managed 流程、observability 效能分析）、**MongoDB Multi-Cloud（IDC+EDC）架構測試**

### 8.9 驗收成功的定義（ISGDMGR-1520，2024-12-18）

> 假設 IDC 不見，或 AWS TPE 不見，服務是否還可 work，若可，就驗證成功。

測項規劃原則（2/24 確認）：
1. **先以整體切換設計，不考慮單點切換**，避免架構與管理過於複雜化
2. 需搭配產品 DB + WEB 整合測試者安排在 Y25/Q3 後
3. 地端既有功能雲端是否能滿足；不能滿足需確認解決方案
4. 地端既有組件在雲上若有多種測試情境，全部列入避免遺漏

### 8.10 管理層回饋（James）

| 時點 | 內容 |
|---|---|
| 2025-04-11 | 期待 **2026 年底 AC 可以多寫多讀**（封站時不降級）；確認流量鏡像測試用應用程式獨立於客戶實際環境（用 PROD 資源建置） |
| 2025-10-30 | 對 AI 插案造成的影響沒問題 —— 因 **AC 雲地解耦**與 **AP 排程調整（封站提前到 4 點開始）**兩項優化已減少客戶影響，為此專案爭取更多時間 |
| 2026-01-08 | 質疑保留環境的必要性（詳見第 6 節） |

### 8.11 補充連結（僅見於留言）

- MySQL LAB 測試結論：<https://hackmd.io/@skhUTGhBTuKf0SIjiqI3-g/Bykuvfixex>
- acapi 整合測試（含進度追蹤）：<https://hackmd.io/hvfqQL0lSwyVDaXDz003lw>
- 對外分流場景模擬設計：<https://hackmd.io/SipxElhoQCy-ZBe8bcAFKg>
- 產品綜合驗證規劃：<https://hackmd.io/oimiHTVwR6u0b71R7_TdxQ>
- TiDB 最終報告：<https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md>
- TiDB 分項報告：<https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-1.md>
- TiDB 壓測結論現況：<https://codimd.104.com.tw/s/6uYJicCpD>
- Galera 討論：<https://codimd.104.com.tw/Pz8M0cqWRDSVqLrJs7PwmA>
- Group Replication 討論：<https://codimd.104.com.tw/SEWxlrnLT6um4t3wKHvQoA>
- 混沌測試報告：<https://codimd.104.com.tw/s/wopi-K1Je>
- 故障恢復報告：<https://codimd.104.com.tw/s/WOjtI_1GV>
- concurrency 對標討論：<https://codimd.104.com.tw/s/qoiyZRNMw>
- F5 分流及 ip sticky：<https://codimd.104.com.tw/zDDpehKuStuVadc1yDj4fA>
- 變型 Snowflake ID 產生 pid：<https://hackmd.io/0dq2VTEeQE6IiPGQOCxT8g>
- ATSP 改回 Single Write：<https://codimd.104.com.tw/s/pMor4NJNE>
