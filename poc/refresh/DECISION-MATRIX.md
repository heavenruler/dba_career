# 分散式資料庫選型決策表

> 對象：ITDBA-3596 / Y25 多寫多讀混合雲 POC 後續決策
> 資料截止：2026-08-25
> 證據來源：`poc/DISTRIBUTED-DB-SCORING.md`、`poc/MILESTONES.md`、`poc/gitbook/`、`poc/results/`、`poc/phase-crossregion/`
> **口徑警告**：所有效能/RTO 數字皆為 `N=1`（單次獨立 suite），`X-CROSS` scope 為 `baseline_eligible=false`。表格中的 O／X 是**在本 PoC 已測條件下的方向性判讀**，不是產品排名，也不是採購結論。

---

## 1. Recap

### 1.1 業務目標

> 「停機維護是 104 的事，不影響到客戶使用權益」

對應 Y25 多寫多讀混合雲 POC 的北極星：**不因任何一 Region / DC 維護或作業而封站**；能 Multi Write 就不考慮 Major Write + Multi Read。

### 主軸描述


### 1.2 本年度 PoC 做了什麼

| 期間 | 階段 | 狀態 |
|---|---|---|
| 03-30～04-10 | 前期研究：定義分散式 SQL、跨區寫入、follower read、HA/DR 評估面向 | ✅ |
| 04-21～04-27 | IaC 與測試鏈 v1（VM / K8s / HAProxy / 獨立壓測 client） | ✅ |
| 05-06～05-17 | 三資料庫框架（TiDB、CockroachDB、YugabyteDB），統一 go-tpc 與結果結構 | ✅ |
| 05-18～05-21 | 單節點 × RC/RR/strict 對標 + active isolation gate | ✅ |
| 05-22～06-02 | 三節點 controlled experiment（1s1r / 1s3r / 3s1r / 3s3r / HAProxy 3s3r） | ✅ `N=1` |
| 06-06～06-07 | Phase isolation：分離 S-BASE / S-K8S / T-THRD / X-CROSS 四個 scope | ✅ |
| 06-08～06-14 | Kubernetes limit / unlimit 六組 suite | ✅ 6/6 |
| 06-08～06-17 | 跨區框架：GCP 5 VM、六節點部署、placement、WAN、pre-flight | ✅ |
| 07-11～07-18 | P-A × A-S 正式輪（三家同批 W=128） | ✅ `N=1` |
| 07-23～07-24 | P-A × A-A-RO 修正後第二輪 | ✅ `N=1` |
| 07-27～08-01 | P-B 全 workload（A-S / A-A-RO / A-A） | ✅ `N=1` 探索性 |
| 08-08～08-11 | Chaos / Failover 實跑 + 稽核撤回 + 真實重跑 | ✅ |
| 08-12～08-13 | MySQL Galera（PXC 8.4）補測：跨區 P-A/P-B 吞吐 + G1-G5 chaos | ✅ |

### 1.3 名詞

| 縮寫 | 意義 |
|---|---|
| **P-A** | leader / lease 固定在 IDC，GCP 持 1 份 voter 副本 |
| **P-B** | leader 跨區混合分布（IDC/GCP 30–70%） |
| **A-S** | Active-Standby，流量只打 IDC 端 |
| **A-A-RO** | 雙端，GCP 端只讀 |
| **A-A** | 雙端同時讀寫（真・多寫多讀） |
| **G1–G5** | Galera 專用 chaos 情境（Galera 無 leader，F1/C4 不適用） |

---

## 2. 目前已完成的評估選項

| 代號 | 候選 | 協定 | 已完成的實測 scope |
|---|---|---|---|
| **A** | MySQL Galera Cluster（Percona XtraDB Cluster 8.4） | MySQL wire | S-BASE（vm-1node / vm-3node-haproxy-3s3r）、X-CROSS（vm-6node P-A/P-B 吞吐）、chaos G1–G5 |
| **B** | TiDB | MySQL wire | S-BASE 全拓樸、S-K8S、X-CROSS（P-A/P-B × 3 workload）、chaos F1/C4/F2/C1/C7 |
| **C** | YugabyteDB（YBDB） | PostgreSQL wire | S-BASE 全拓樸、S-K8S、X-CROSS（P-A/P-B × 3 workload）、chaos（2026-08-11 重跑，`N=2`） |
| **D** | CockroachDB（CRDB） | PostgreSQL wire | 同 C |

**分組原則**：A/B（MySQL 協定）與 C/D（PostgreSQL 協定）**不放在同一個星等或加權總分內直接比較** —— 協定不同代表遷移時應用層改動成本是「能不能直接換」的門檻差異，不是「效能差一點」的程度差異。

---

## 3. 決策表格
(include 0821_slide.pptx page 11)

### 3.1 主表：可行性與適配

| 目前評估項目 / 搭配 / 資源狀態 | A MySQL | B TiDB | C YBDB | D CRDB | 說明 |
|---|:---:|:---:|:---:|:---:|---|
| **目前多寫多讀可行性** | **X** | **O** | **X** | **X** | MySQL（Galera）同步 certification + flow control 使多寫代價過高（見 §3.2 各列）；其他 PostgreSQL 類別目前業務量尚無需考量，且需換協定 |
| 免改應用即可導入（協定） | O | O | X | X | A/B 同為 MySQL wire；C/D 為 PostgreSQL wire，應用層改動量級完全不同。**相容性矩陣本 PoC 尚未實測，四家皆「待測」** |
| 跨區散置寫入（原生 placement） | **X** | O | O | O | Galera 原生不支援跨區散置寫入架構（本 PoC 6-node 單叢集下 GCP 3 台無法自組 Primary，majority=4） |
| 單機房多寫（同城 3 節點） | △ | O | O | O | Galera 在 naive multi-writer（HAProxy round-robin）下 **0.49× 負向擴展**；改單寫或以 shard key 分流結果可能不同（未測） |
| 真・雙端同時寫（A-A） | **X** | △ | △ | △ | 見 §3.2「跨區雙寫錯誤率」；B/C/D 皆有非零 GCP 側錯誤率，TiDB 另有 th=128 吞吐劣化假說未定位根因 |
| HTAP / 分析型負載 | n/a | 待測 | n/a | n/a | 僅 TiDB 有原生 TiFlash，但本 PoC 未執行 OLAP 測試 |
| 現行維運工具鏈可沿用 | O | 待測 | X | X | A 為現況；B 官方宣稱高度 MySQL 相容但**本 PoC 未實測驗證** |

圖例：**O** = 本 PoC 條件下可行 ／ **X** = 本 PoC 條件下不建議或不適用 ／ **△** = 有條件可行，需補測 ／ **待測** = 尚未排入測試矩陣 ／ **n/a** = 架構上不適用

### 3.2 效能與可用性實測（原始數字，跨組僅供交叉參考）

| 量測項目 | A MySQL | B TiDB | C YBDB | D CRDB | 口徑 |
|---|---:|---:|---:|---:|---|
| 單節點 tpmC | **53,791.9** | 13,064 | 11,436 | 9,134 | vm-1node RC，各自飽和甜點 thread |
| 單節點 NEW_ORDER p99 | **37.7 ms** | 597 ms | 216 ms | 440 ms | 同上 |
| 3 節點 HAProxy tpmC (t=128) | 26,166.2 | **26,947** | 15,632 | 15,033 | vm-3node-haproxy-3s3r |
| **水平擴展倍率** | **0.49×** ⚠ | **2.06×** | 1.37× | 1.65× | 1node → 3node-haproxy |
| 5 輪變異 range/mean (t=128) | **43.2%** ⚠ | 7.4% | 7.1% | 6.9% | 越低越穩 |
| all-txn error rate (t=128) | **0.037%** ⚠ | 0.000% | 0.000% | 0.000% | 四家中唯一非零 |
| 跨區單寫 tpmC (P-A×A-S, t=128) | **298.8** | **12,526.5** | 12,769.5 | 10,163.4 | vm-6node；A vs B 差 **41.9 倍** |
| 跨區雙寫 GCP 側失敗率 (P-B×A-A) | **47.0%** ⚠ | 0.158% | 0.134% | 0.111% | A 高出 B 約 **300 倍** |
| Failover 復原時間 | 22.169 s（G2，t_kill 起算） | 39.1–44.3 s（F2，t_restart 起算）／198–202 s（t_kill 起算） | **≈3.0 s** | ≈7.0 s | **口徑不等價，不可直接排名** |
| 單節點 kill 可觀測中斷 | 無（G1，432/432 探測成功） | 6.68–8.4 s | 無（<100ms 解析度） | 無（<100ms 解析度） | TiDB SQL/儲存層分離的架構體現 |
| quorum 遺失時寫入拒絕 | ⚠ 出現 `UNEXPECTED_WRITE_SUCCEEDED` | 乾淨拒絕 | 乾淨拒絕 | ⚠ `ambiguous`，需應用層處理 | 正確性底線 |
| 部分加權總分 | 44.5 | 75.5 | 87.1 | 87.1 | **A/B 為 62% 權重、C/D 為 82% 權重，兩組不可互比** |

### 3.3 尚未測、會影響決策的缺口

| 項目 | A | B | C | D | 權重影響 |
|---|:---:|:---:|:---:|:---:|---|
| SQL / ORM 相容性矩陣 | 待測 | 待測 | 待測 | 待測 | MySQL 組 20%、PostgreSQL 組 10% |
| PITR / 備份還原 | 待測 | 待測 | 待測 | 待測 | 兩組各 3% |
| Online DDL 與維運工具 | 待測 | 待測 | 待測 | 待測 | 兩組各 5% |
| Failover 等價口徑重測 | 待重評 | 待重評 | ✅ | ✅ | MySQL 組 5% |
| 三節點候選配置 `N=3` | ⚪ | ⚪ | ⚪ | ⚪ | 全表證據等級 |

> MySQL 組未計分權重合計 **38%**；PostgreSQL 組未計分權重合計 **18%**。

---

## 4. 各終點結論與效益

### 終點 1 — 維持 MySQL Galera / PXC（現況）{remove it.}

| 面向 | 內容 |
|---|---|
| **適用情境** | 單機房、單寫入點、低到中併發；小型部署或報表庫 |
| **效益** | 零遷移成本；單節點延遲遠優於其他三家（p99 37.7ms，是 TiDB 的 1/15.8） |
| **代價** | 多寫入點時 **0.49× 負向擴展**；t=128 五輪變異 43.2%（t=16 甚至 117.5%）；四家中唯一非零錯誤率 |
| **跨區** | 跨區單寫吞吐僅 298.8 tpmC（TiDB 的 1/41.9）；跨區雙寫 GCP 側失敗率 **47.0%**（PAYMENT 81.5%），應用層需大量重試邏輯 |
| **結論** | **不支援多寫多讀混合雲目標**。可續用於單寫場景，但不是本專案的解 |

> 佐證但未定案：wsrep counter 顯示 `cert_failures=234`／`bf_aborts=265`（僅佔 commits 0.015~0.017%），`flow_control_paused=22.4%`；0.49× 衰退**更可能主要來自 flow control 與寫入排序同步成本**，certification 衝突只是部分貢獻 —— 佔比未經證據拆解，不應斷言單一根因。

### 終點 2 — 轉 TiDB（MySQL 協定不變）
(重點描述分階段執行策略 ; 及周邊產品單位期待)
| 面向 | 內容 |
|---|---|
| **適用情境** | 需水平擴展、高併發穩定性、跨區 placement 的關鍵服務 |
| **效益** | 擴展倍率 **2.06×**（四家最高）；t=128 變異 7.4%、error 0%；跨區單寫吞吐是 Galera 的 41.9 倍；跨區雙寫 GCP 側錯誤率 0.158%；**協定不變，應用改動成本最低**；唯一具原生 HTAP |
| **代價** | 單節點延遲差（p99 597ms，推論為 PD/TiKV/TiDB-server 同 VM 協調開銷）；單節點 kill 有 6.68–8.4s 真實可觀測中斷（SQL 層與共識層分離的架構體現）；F2 復原 39–44s |
| **已知風險** | P-B × A-A-RO/A-A 在 th=128 出現吞吐劣化（五輪 tpmC 9003→14948→2113→954→1480，R3-R5 未恢復），命中 `PessimisticLockNotFound`／`LockTsMismatch` —— **僅止於跨區鎖競爭假說，未定位根因，控制實驗待辦** |
| **結論** | **本 PoC 條件下唯一同時滿足「多寫多讀」與「協定不變」的選項**；ac-api 整合測試亦已於 2026-08-26 通過（Y25 POC） |

### 終點 3 — 轉 PostgreSQL 系（YugabyteDB / CockroachDB）
(仍需要 ; 雖然應用面向少 ; 但重要 EX: B/C Agent.)
| 面向 | 內容 |
|---|---|
| **適用情境** | 願意承擔協定切換成本、以 RTO 為第一優先的場景 |
| **效益** | Failover 表現最佳：YBDB F2 ≈3s、CRDB ≈7s，兩家單節點 kill 皆觀測不到中斷；兩家部分加權總分同為 87.1 |
| **代價** | **應用層需全面改造**（PostgreSQL wire）；既有 MySQL 維運工具鏈不可沿用；CRDB quorum 遺失時回報 `ambiguous`，需應用層額外處理重試/查詢邏輯（三家中唯一） |
| **已知風險** | YBDB 曾於 2026-08-08 出現一次 master 執行緒暴增穩定性異常（08-11 重跑未重現，屬間歇性）；YBDB 在 K8s 部署層 retention 遠低於 TiDB/CRDB |
| **結論** | **目前業務量尚無需考量**。技術上可行且 Failover 最佳，但協定切換成本無法由現有效益差距正當化 |

### 終點 4 — 不換 DB，改由應用層規避

| 面向 | 內容 |
|---|---|
| **做法** | 維持單寫（A-S）+ 跨機房分流（Cloudflare LB / ip sticky）+ 就近讀 |
| **效益** | 零 DB 遷移；Y25 POC 已驗證 Cloudflare LB 符合分流及 ip sticky 需求（8/M） |
| **代價** | 達不到「任一機房失效不封站」的北極星；Galera 0.49× 的問題只是被繞開不是被解決 |
| **結論** | 過渡方案，非終局架構 |

---

## 5. 決策建議

1. **多寫多讀路線 → TiDB**。這是唯一在「協定不變 + 水平擴展 + 跨區 placement + 低跨區錯誤率」四項同時成立的候選。
2. **PostgreSQL 系維持觀察**，不投入遷移資源，直到業務量或 RTO 需求明確超出 TiDB 可提供的範圍。
3. **Galera 不作為多寫多讀方案**，但保留為單寫/小型部署的既有選項。
4. **決策前必補的三項測試**（合計 MySQL 組 28% 權重）：
   - SQL / ORM 相容性矩陣（遷移時最先浮現的痛點）
   - Online DDL 對前台負載的影響
   - Failover 等價口徑重測（統一 `t_kill` → 首次成功寫入、禁止人工恢復的觀測窗、相同探測位置）
5. **證據等級提醒**：目前全部為 `N=1`。核准正式導入前需補 `N=3` 獨立重跑，檢查跨 run 差異與結論是否翻轉。

---

## 6. 不能下的結論

- 不能因 §3.2 的 44.5 / 75.5 就宣稱「TiDB 整體優於 Galera」—— MySQL 組尚有 38% 權重未計分，且 #2（單節點延遲）是 Galera 大幅領先、#3/#4 才是 TiDB 領先，**不是相加抵銷**。
- 不能因 Galera 在 naive multi-writer 下負向擴展就推論「Galera 完全不能多寫」—— 本測試刻意用 HAProxy round-robin 製造最大化衝突，改單寫或 shard key 分流結果可能截然不同。
- 不能把 Galera 的 `Error 1213 Deadlock` 全部定性為 wsrep certification failure —— InnoDB local deadlock 對 client 呈現相同錯誤碼，無 wsrep counter delta 佐證無法區分。
- 不能把 A/B 組與 C/D 組的加權總分互相比較。
- 不能把 X-CROSS 數字放進 S-BASE 正式跨家排名（`baseline_eligible=false`）。
- 不能由 P-A 推論 P-B，也不能由 A-S 推論 A-A-RO 或 A-A。
- 不能宣稱 P-B 能在整區故障下秒級接手 —— **未驗證，且 RF=3、兩 failure domain 下數學上不保證**。

---

## 7. 證據入口

| 文件 | 內容 |
|---|---|
| [`poc/DISTRIBUTED-DB-SCORING.md`](../DISTRIBUTED-DB-SCORING.md) | 四家評分表、加權總分、逐項證據連結 |
| [`poc/MILESTONES.md`](../MILESTONES.md) | 專案歷程、可下/不可下結論、下一決策門檻 |
| [`poc/gitbook/`](../gitbook/) | 17 章結構化交付文件（含 09 跨區、16 決策框架） |
| [`poc/results/README.md`](../results/README.md) | 已驗證結果索引與樣本限制 |
| [`poc/results/PHASES.md`](../results/PHASES.md) | Phase registry，scope 與 baseline eligibility 的唯一準則 |
| [`poc/results/x-cross/README.md`](../results/x-cross/README.md) | 跨區已採用批次清單與 lineage caveat |
| [`poc/phase-crossregion/`](../phase-crossregion/) | 各 placement × workload 結案報告 |
| [`Y25_多寫多讀POC_摘要.md`](./Y25_多寫多讀POC_摘要.md) | Y25 專案側（Jira + 官方總結簡報）彙整 |
