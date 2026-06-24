# Deprecated — CockroachDB TPC-C Pipeline Log (migrated to crdb-tc1)

> ⚠️ **DEPRECATED / 已移轉**：本檔為 PoC v4.7 前的歷史資料（單次 10min run、手動部署、無 detached suite wrapper、無 DB-host 雙邊監控）。**新 baseline 已遷至 [`results/crdb-tc1/S-BASE/pipeline-log.md`](../../crdb-tc1/S-BASE/pipeline-log.md)**，採 5-round 平均 + DB-host OS 監控 + isolation 雙閘 + 5×5min run × 4 thread groups。
> 本檔以下所有結論為**歷史資料**，**不納入 PoC v4.7 baseline 與跨家對比**，僅作流程演進記錄之用。

> **【歷史結論，已過時】** CockroachDB 單節點吞吐量介於 TiDB 與 YugabyteDB 之間 — 約為 TiDB 的 65%、YugabyteDB 的 22 倍；READ COMMITTED 隔離下無 abort 重試行為（前一輪 SERIALIZABLE 模式曾觀察到約 0.1% NEW_ORDER 因衝突被中止重做，切到 RC 後消失）。

---

## 各 variant 拓撲總覽

> CockroachDB 為對稱架構（symmetric architecture）— 每個節點同時負責 SQL 接收、儲存、元資料管理，無獨立元件（不像 TiDB 有 PD/TiDB/TiKV 分離）。下圖每個節點上的「cockroach」即包含 SQL + KV + Raft + Storage 完整堆疊。

```
vm-1node                                  client (go-tpc on .31)
                                                  │
                                                  ▼ :26257 (direct)
                              ┌───────────────────────────────────┐
                              │ .32:  cockroach (single-node)     │
                              └───────────────────────────────────┘
  deploy: cockroach start-single-node --insecure --advertise-addr=172.24.40.32
          (手動部署，無 ansible playbook)


vm-3node-direct                           client (go-tpc on .31)
                                                  │
                                                  ▼ :26257 (direct, no HAProxy)
                              ┌───────────────────────────────────┐
                              │ .32:  cockroach ◄─────────────────┤
                              │ .33:  cockroach                   │
                              │ .34:  cockroach                   │
                              │   每節點 --join=.32,.33,.34 RF=3   │
                              └───────────────────────────────────┘
  deploy: 每節點手動 cockroach start --insecure --join=...
          READ COMMITTED cluster setting 套於 .32


vm-3node                                  client (go-tpc on .31)
                                                  │
                                                  ▼ :15257
                              ┌───────────────────────────────────┐
                              │ .32:  HAProxy ──► roundrobin      │
                              │       cockroach          ▼  ▼     │
                              │ .33:  cockroach ◄─────────────────┤
                              │ .34:  cockroach ◄─────────────────┤
                              │   HAProxy 與 .32 cockroach 共機    │
                              │   (與 YugabyteDB 設計一致)          │
                              └───────────────────────────────────┘
  deploy: 同 vm-3node-direct 叢集（沿用同份資料）+ HAProxy on .32:15257
          backend 三節點 :26257（timeout 600s + clitcpka/srvtcpka）


k8s-3node-unlimit                         client (go-tpc on .31)
                                                  │
                                                  ▼ NodePort :30007
                              ┌───────────────────────────────────┐
                              │ k3s cluster (3 nodes)             │
                              │ ┌─ .32 master ─┐ ┌─ .33 worker ─┐ │
                              │ │ cockroachdb-x│ │ cockroachdb-y│ │  ← pod 由 scheduler 排程
                              │ └──────────────┘ └──────────────┘ │
                              │ ┌─ .34 worker ─┐                  │
                              │ │ cockroachdb-z│                  │
                              │ └──────────────┘                  │
                              │   StatefulSet replicas=3 / RF=3   │
                              │   30Gi PVC each / tls.enabled=    │
                              │   false (--insecure)              │
                              └───────────────────────────────────┘
  deploy: cockroach-k8s.yml + cockroach-tc1-k8s.ini + vars/cockroach-k8s-3node-unlimit.yml
          (helm chart cockroachdb/cockroachdb 15.0.5, image v26.1.4)
          init Job 不自動渲染 → role 手動 exec cockroach init
          NodePort 手動 kubectl patch 從隨機改 :30007 (SQL) / :30008 (admin UI)
          READ COMMITTED cluster setting 套於 cockroachdb-0


k8s-3node-limit                           同 k8s-3node-unlimit 拓撲
                                          差別：crdb_resource_limits=true
                                          每 pod limits: 2 CPU / 8GiB memory
                                          (對齊 TiDB TiKV K8s-limit 設定)
                                          deploy vars: cockroach-k8s-3node-limit.yml
                                          result: 20260512-2128
```

---

## vm-1node — 2026-05-08

### 環境
- 節點：.32 (172.24.40.32) 單節點，**insecure 模式**（無 TLS，方便快速比較；TLS overhead 對 OLTP 影響極小）
- 部署：`cockroach start-single-node --insecure --advertise-addr=172.24.40.32 --listen-addr=172.24.40.32:26257 --http-addr=172.24.40.32:8080 --store=/opt/cockroach/data --background`
- CockroachDB 版本：v26.1.4
- **Isolation**：READ COMMITTED（資料庫的「交易隔離等級」設定，決定多筆交易同時跑時彼此能看到對方未完成的資料到什麼程度。READ COMMITTED 是業界最常用的等級之一，本次與 YugabyteDB 對齊，確保對比基準一致。CockroachDB 預設等級為 SERIALIZABLE 但較嚴格，會在衝突時整筆中止重試。）

  以下三條設定使 CockroachDB 整體切換到 READ COMMITTED 模式：
  - cluster setting：`SET CLUSTER SETTING sql.txn.read_committed_isolation.enabled = true;`（設定整個叢集層級的隔離預設值）
  - 預設 role：`ALTER ROLE ALL SET default_transaction_isolation = 'read committed';`（讓所有使用者新建交易時自動套用 READ COMMITTED）
  - go-tpc：`--isolation 2`（測試工具端的對應設定，與資料庫端一致；go-tpc isolation level 2 = ReadCommitted）
- 測試工具：go-tpc (`-d postgres --conn-params sslmode=disable --isolation 2`)（`sslmode=disable`：測試環境關閉 SSL 連線加密以簡化設定，正式部署應啟用加密；本次與 insecure 部署模式一致）
- 連線入口：直連 172.24.40.32:26257
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`vm-1node/20260508-2057/`

### Prepare
- 時間：12m46s（128W）— 三家中最快（TiDB 19m、YugabyteDB 47m）
- check 階段全程通過

### Execute 結果

> ⚠️ **注意**：efficiency 欄位在無 think time（等待間隔）的壓力測試下會遠超 100%，這是正常現象（資料庫一刻不停地工作），不代表計算錯誤。
>
> （tpmC / tpmTotal：越高越好；NO avg / NO P99：越低越好）

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 8,559.5 | 19,034.1 | 520.0% | 62.3 | 125.8 |
| 32 | 8,732.5 | 19,423.5 | 530.5% | 126.0 | 260.0 |
| 64 | 8,555.3 | 19,082.9 | 519.7% | 265.0 | 604.0 |
| 128 | 8,133.4 | 18,086.4 | 494.1% | 564.6 | 1,275.1 |

### Execute 結果白話解讀

| 併發 | 白話解讀 |
|------|---------|
| 16t | 表現良好（延遲 62ms） |
| 32t | 維持高吞吐（延遲 126ms，最佳吞吐點） |
| 64t | 開始吃力（延遲 265ms） |
| 128t | 仍可運作（延遲 565ms，無逾時、無 hang） |

### 三家對比（vm-1node 相同硬體）

> **倍數 = 前者 tpmC ÷ 後者 tpmC，越高代表前者效能越好**（TiDB/CockroachDB > 1 代表 TiDB 較快；CockroachDB/YugabyteDB > 1 代表 CockroachDB 較快）。

| threads | TiDB tpmC | CockroachDB tpmC | YugabyteDB tpmC | TiDB/CockroachDB | CockroachDB/YugabyteDB |
|---------|-----------|-----------|-----------|-----------|-----------|
| 16 | 11,895 | 8,559 | 414.7 | 1.39× | 20.6× |
| 32 | 12,766 | 8,732 | 394.8 | 1.46× | 22.1× |
| 64 | 13,355 | 8,555 | 378.6 | 1.56× | 22.6× |
| 128 | 13,078 | 8,133 | 370.4 | 1.61× | 21.9× |
| **Peak** | **13,355** | **8,732** | **414.7** | — | — |
| Peak @ | 64t | 32t | 16t | — | — |

| threads | TiDB NO avg | CockroachDB NO avg | YugabyteDB NO avg |
|---------|-------------|-------------|-------------|
| 16 | 39 ms | 62 ms | 2,225 ms |
| 32 | 72 ms | 126 ms | 4,686 ms |
| 64 | 135 ms | 265 ms | 9,548 ms |
| 128 | 268 ms | 565 ms | 15,655 ms |

### 觀察

- **吞吐穩定 ~8,500 tpmC**：16~128t 之間 tpmC 浮動 < 7%（8,732 → 8,133），曲線平緩，無 YugabyteDB 那樣的崩潰式下滑。
- **峰值在 32t**（與 TiDB 64t、YugabyteDB 16t 相比，CockroachDB 對中度併發最友好）。
- **NO avg 線性翻倍**：62 → 126 → 265 → 565 ms，與 TiDB / YugabyteDB 相同模式，但絕對值落在中間。
- **128t 順利完成**：無 hang，total 45m01s；NO P99 1,275ms 遠低於 go-tpc 16s 上限。
- **無 NEW_ORDER_ERR（新訂單交易因衝突被資料庫中止的錯誤計數為 0）**：READ COMMITTED 模式下衝突會排隊等待而非 abort（取消整筆交易）；之前 SERIALIZABLE 在 16t 出現約 0.1% 的 abort 率，切到 RC 後消失。

### 根因：架構差異

> **管理層摘要**：CockroachDB 預設用「最嚴格的衝突偵測」，遇到衝突會直接中止整筆交易並要求應用程式重試（這個過程會吃掉吞吐）。本次將設定切到較寬鬆的 READ COMMITTED 模式後，衝突的交易改為「排隊等候」（與 TiDB 機制一致），因此延遲穩定、吞吐持續。這是 CockroachDB 居於 TiDB 與 YugabyteDB 中間的原因。

CockroachDB 採用 **distributed serializable + lock-based locking under SERIALIZABLE，但 RC 模式下使用 row-level locking（以單一資料列為單位的鎖定，後到的交易等鎖而非整筆中止）不 abort**：
- SERIALIZABLE 模式：偵測到讀寫衝突直接 abort（`WriteTooOldError`：CockroachDB 在偵測到讀寫衝突時拋給應用程式的錯誤），需 client retry（要求應用程式端重新發送整筆交易）
- READ COMMITTED 模式：採 row-level locking，後到的交易等鎖（類似 TiDB 悲觀鎖），不 abort

TPC-C `district.D_NEXT_O_ID` 熱點 row 在 RC 下排隊處理，每筆順序執行，因此吞吐曲線平穩、無 retry 風暴。

### vs TiDB / YugabyteDB 架構差異總結

| | TiDB | CockroachDB (RC) | YugabyteDB |
|--|------|-----------------|------|
| 預設 isolation | RR | SERIALIZABLE（本測試切 RC）| RC（本測試）|
| 鎖定機制 | 悲觀（TiDB v6+ 預設） | RC 下 row-level | 樂觀 MVCC |
| 衝突處理 | 排隊等鎖 | 排隊等鎖 | rollback 重試 |
| 單節點 peak tpmC | 13,355 | 8,732 | 414.7 |
| 128t hang 風險 | 無 | 無 | 無（vm-1node 直連） |

> 縮寫：**RR** = Repeatable Read（可重複讀取）；**RC** = Read Committed（讀已提交）；**SERIALIZABLE** = 可序列化（最嚴格）。

### 注意事項

- **首次 SERIALIZABLE 測試**（同日稍早，5m 部分數據）：tpmC ~8,200，但每秒約 0.1% 的新訂單交易因 `WriteTooOldError`（讀寫衝突錯誤）被資料庫**中止整筆交易**（abort）。改 RC 後此情況消失，吞吐略升至 8,732。

---

## vm-3node-direct — 2026-05-08

### 環境
- 節點：.32/.33/.34 三節點，每節點 `cockroach start --insecure --join=...`，**無中央元件**（CockroachDB 對稱架構，每個節點同時負責 SQL/儲存/元資料）
- 預設 RF=3（系統與使用者資料各三副本）
- READ COMMITTED + go-tpc `--isolation 2`（同 vm-1node）
- 連線入口：直連 .32:26257（**不過 HAProxy**）
- 結果目錄：`vm-3node-direct/20260508-2336/`

### Prepare
- 時間：10m57s（128W），比 vm-1node 的 12m46s 快 — 三節點分擔寫入

### Execute 結果

> （tpmC：越高越好；NO avg / NO P99：越低越好）

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 9,142.5 | 20,265.7 | 555.4% | 61.4 | 134.2 |
| 32 | 10,144.4 | 22,514.3 | 616.3% | 107.8 | 260.0 |
| 64 | 10,892.4 | 24,207.6 | 661.7% | 194.8 | 469.8 |
| 128 | 11,142.6 | 24,707.9 | 676.9% | 381.4 | 906.0 |

### vs vm-1node 對比

> **倍數 = 三節點 tpmC ÷ 單節點 tpmC，越高越好，代表加台伺服器後效能提升的幅度。**

| threads | vm-1node | vm-3node-direct | 倍數 |
|---------|----------|----------------|------|
| 16 | 8,559 | 9,142 | 1.07× |
| 32 | 8,732 | 10,144 | 1.16× |
| 64 | 8,555 | 10,892 | 1.27× |
| 128 | 8,133 | 11,142 | 1.37× |

### 觀察

- **隨併發 scale up**：與 vm-1node 不同（單節點 16~128t 浮動 < 7%），三節點直連在高併發下持續成長 — 高併發釋放更多 RPC 併發度。
- **峰值在 128t**（11,142），與 vm-1node 峰值 32t 不同 — 多節點吃掉更多 thread 才開始飽和。
- **延遲較單節點高**：原因是 SQL 全部走 .32 的 gateway，但 leaseholder 分散在三節點，每筆查詢需 cross-node RPC。

---

## vm-3node — 2026-05-09

### 環境
- 節點：與 vm-3node-direct 同一個叢集（資料未重建——沿用同一份資料是刻意的，兩次測試在同等資料量下才可以直接對比）
- 連線入口：HAProxy 172.24.40.32:15257 → roundrobin（輪流分配）三節點 :26257
- HAProxy 設定：與 YugabyteDB 相同（`timeout 600s` + `clitcpka/srvtcpka`），僅 backend port 改為 :26257
- 結果目錄：`vm-3node/20260509-0027/`

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 9,958.3 | 22,167.5 | 605.0% | 57.7 | 117.4 |
| 32 | 11,933.4 | 26,450.8 | 725.0% | 96.9 | 218.1 |
| 64 | 12,661.7 | 28,114.4 | 769.2% | 180.8 | 402.7 |
| 128 | **14,014.7** | 31,130.4 | 851.4% | 321.0 | 771.8 |

### vs vm-3node-direct 對比（HAProxy "提升"，反向於 YugabyteDB）

> **差距 = vm-3node (HAProxy) 相對 vm-3node-direct 的 tpmC 增減，正數代表 HAProxy 版本比直連快。**

| threads | vm-3node-direct | vm-3node (HAProxy) | 差距 |
|---------|----------------|--------------------|------|
| 16 | 9,142 | 9,958 | +8.9% |
| 32 | 10,144 | 11,933 | +17.6% |
| 64 | 10,892 | 12,661 | +16.2% |
| 128 | 11,142 | **14,014** | **+25.8%** |

### 觀察

- **HAProxy 反而更快**（與 YugabyteDB 相反）：YugabyteDB direct 比 HAProxy 快 3-5%，CockroachDB HAProxy 比 direct 快 9-26%。
- **原因（CockroachDB symmetric architecture）**：CockroachDB 每個節點都能完整處理 SQL（parse/plan/route），HAProxy roundrobin 將 SQL 處理分散到三節點，各自就近處理 1/3 的 leaseholder，反而比集中於 .32 處理高效。
- **128t peak 14,014**：超越 TiDB vm-1node 峰值 13,355，**CockroachDB 三節點 + HAProxy 是其 sweet spot**。
（但 TiDB 在 vm-3node + HAProxy 達 22,841，CockroachDB 同模式 14,014 仍低於 TiDB 對應部署；CockroachDB 的優勢在「單一節點即整合 SQL+儲存+元資料」的部署簡易度，而非絕對 peak。）

### CockroachDB vs TiDB / YugabyteDB 多節點 scaling 對比

| | vm-1node peak | vm-3node-direct peak | vm-3node (HAProxy) peak | 3-node scaling |
|--|---|---|---|---|
| TiDB | 13,355 | 14,779 | 22,841 | **1.71× peak** |
| **CockroachDB** | **8,732** | **11,142** | **14,014** | **1.6× peak** |
| YugabyteDB | 414.7 | 1,024.2 | 1,036.7 | **2.5× peak** |

- YugabyteDB scaling 倍數最高（單節點低基數 → 多節點放大效果明顯）
- **TiDB 絕對數字最高**（22,841，SQL/儲存分離設計讓加 SQL 節點橫向擴充最大化）
- CockroachDB 次高，且 vm-3node-direct → HAProxy 增益最高（+25.8%）

### 結論

CockroachDB 三節點橫向擴展不只「有效」，而是 **CockroachDB 自身的最優部署模式**（peak 14,014 為 CockroachDB 全部署中最高；但仍低於 TiDB 同模式 22,841）。CockroachDB symmetric architecture 讓 HAProxy roundrobin 不只是負載均衡，更是 **SQL 處理層的橫向分散**。生產環境使用 HAProxy 是首選。
- **insecure 模式**：本測試走無 TLS，TLS 對 OLTP 影響通常 < 5%；正式部署時應用 secure 模式。

---

## k8s-3node-unlimit — 2026-05-12

### 環境
- 拓撲：**k3s** v1.29.14 三節點（.32 master，.33/.34 worker）+ **cockroachdb Helm chart 15.0.5**（image v26.1.4）部署 StatefulSet `cockroachdb` replicas=3
- 連線入口：NodePort `.32:30007`（chart values 無 `service.public.ports.*.nodePort` 欄位，role 內 kubectl patch 從隨機改固定 :30007 = SQL / :30008 = admin UI）
- TLS：`tls.enabled=false`（`--insecure`，與 VM 部署一致，方便對比）
- READ COMMITTED：role 在部署收尾 exec `cockroach sql --insecure -e "SET CLUSTER SETTING sql.txn.read_committed_isolation.enabled = true"` + `ALTER ROLE all SET default_transaction_isolation = 'read committed'`
- 容器資源限制：**無**（unlimit variant；values.yaml.j2 不渲染 `{% if crdb_resource_limits %}` 區塊）
- 儲存：每 pod 30 GiB PVC（local-path StorageClass）
- 測試工具：go-tpc on .31（`-d postgres --conn-params sslmode=disable --isolation 2`）
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`k8s-3node-unlimit/20260512-1411/`

### 部署紀錄（與 VM CockroachDB 的差異）
- Helm chart 15.0.5 **不自動渲染 init Job**（manifest grep 無 `kind: Job`），所有 pods 卡 0/1 Running 永不 Ready；ansible role 需手動 `kubectl exec cockroachdb-0 -- ./cockroach init --insecure --host=cockroachdb-0.cockroachdb.cockroach-tc1`
- chart `service.public` 只接受 `type/labels/annotations`，**不支援 nodePort 欄位**；要固定 NodePort 必須 helm install 後 kubectl patch
- `SET CLUSTER SETTING` 不能與其它 statement 同 transaction（CockroachDB 拒絕 `multi-statement transaction`），role 拆兩次 exec

### Execute 結果

> ⚠️ efficiency > 100% 為無 think time 的壓測常態，非錯誤
>
> （tpmC：越高越好；NO avg / NO P99：越低越好）

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 8,998.0 | 20,005.9 | 546.6% | 64.6 | 130.0 |
| 32 | 10,599.9 | 23,582.1 | 643.9% | 108.3 | 251.7 |
| 64 | 12,416.6 | 27,495.0 | 754.3% | 187.3 | 453.0 |
| 128 | **13,982.2** | 31,138.9 | **849.4%** | 325.6 | 805.3 |

### vs vm-3node (HAProxy) 對比 — **容器化幾乎零 overhead**

| threads | vm-3node (HAProxy) | k8s-3node-unlimit | 差距 |
|---------|--------------------|-------------------|------|
| 16 | 9,958 | 8,998 | −9.6% |
| 32 | 11,933 | 10,600 | −11.2% |
| 64 | 12,661 | 12,417 | −1.9% |
| 128 | **14,014** | **13,982** | **−0.2%** |

### 觀察

- **128t peak 13,982 ≈ vm-3node HAProxy 14,014**：K8s overhead **−0.2%**，幾乎完全沒有容器化代價。對照同款測試：
  - **TiDB**：vm-3node 22,841 → K8s 18,919，overhead **~17%**
  - **CockroachDB**：vm-3node 14,014 → K8s 13,982，overhead **~0.2%**
- **原因（symmetric architecture）**：CockroachDB 每節點同時 SQL + KV + Storage，K8s NodePort 把 SQL 連線分散到 3 個 pod，等同 HAProxy roundrobin 的「SQL 處理層橫向分散」效果。TiDB 必須區分 PD/TiDB/TiKV pod、TiKV 為集中元件，K8s overhead 較顯著。
- **低 thread overhead 較高**（16t −9.6%，128t −0.2%）：低 thread 對 K8s 額外網路 hop 較敏感；128t 飽和時 DB 本身才是瓶頸，K8s 開銷被吸收。

### 結論

**CockroachDB 是本批 PoC 對 K8s 最友善的資料庫**（−0.2% vs TiDB ~17%）。若要走 K8s 路線且看重最小化容器化損耗，CockroachDB symmetric 設計是顯著優勢；但若看絕對峰值，TiDB K8s 18,919 仍高於 CockroachDB K8s 13,982（差距 35%）。

---

## k8s-3node-limit — 2026-05-12

### 環境
- 拓撲：同 `k8s-3node-unlimit`，k3s v1.29.14 三節點（.32 master，.33/.34 worker）+ cockroachdb Helm chart 15.0.5（image v26.1.4）
- 連線入口：NodePort `.32:30007`
- TLS：`tls.enabled=false`（`--insecure`）
- READ COMMITTED：cluster setting 已啟用；go-tpc 仍以 `--isolation 2` 執行
- 容器資源限制：每個 CockroachDB pod `requests: 1 CPU / 2GiB`，`limits: 2 CPU / 8GiB`
- 儲存：沿用 30 GiB PVC（local-path StorageClass）；TPC-C DB cleanup + prepare 重建資料
- 測試工具：go-tpc on .31
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`k8s-3node-limit/20260512-2128/`

### 接手 / 部署紀錄
- 目前 `.31` 是 client / runner；從 `.31` SSH 到 `.32` 執行 K8s/Helm 指令，避免本機 known_hosts 與 ansible tmp 權限問題。
- 原狀態仍是 unlimit：StatefulSet resources 顯示 `limits=` 空值。
- 第一次 Helm upgrade 走 `HTTPS_PROXY=http://172.24.40.31:3128` 失敗，因 `.31:3128` proxy 未開。
- 改用 `.32` 既有 chart cache：`/root/.cache/helm/repository/cockroachdb-15.0.5.tgz`，Helm revision 4 成功 rolling update。
- 驗證：`db requests={"cpu":"1","memory":"2Gi"} limits={"cpu":"2","memory":"8Gi"}`，三個 pod 皆 1/1 Running。

### Execute 結果

> ⚠️ efficiency > 100% 為無 think time 的壓測常態，非錯誤
>
> （tpmC：越高越好；NO avg / NO P99：越低越好）

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 4,931.8 | 11,006.0 | 299.6% | 119.9 | 369.1 |
| 32 | 5,576.9 | 12,473.2 | 338.8% | 211.7 | 637.5 |
| 64 | 6,181.7 | 13,770.1 | 375.5% | 379.4 | 1,140.9 |
| 128 | **6,749.9** | 15,044.7 | **410.1%** | 680.4 | 2,013.3 |

### vs k8s-3node-unlimit 對比 — **CPU cap 主導**

| threads | k8s-3node-unlimit | k8s-3node-limit | 差距 |
|---------|-------------------|-----------------|------|
| 16 | 8,998 | 4,932 | −45.2% |
| 32 | 10,600 | 5,577 | −47.4% |
| 64 | 12,417 | 6,182 | −50.2% |
| 128 | **13,982** | **6,750** | **−51.7%** |

### 觀察

- **2 CPU cap 使 peak 從 13,982 降到 6,750（−51.7%）**，降幅比 TiDB K8s-limit 的 −41% 更重。
- **吞吐仍隨併發上升**：16t → 128t 從 4,932 升到 6,750，代表 CPU cap 下仍可吃更高併發，但延遲同步明顯拉高。
- **NO P99 從 805ms 拉到 2,013ms**（128t，對比 unlimit），cap 後排隊延遲成為主因。
- 與 vm-1node peak 8,732 相比，k8s-limit peak 6,750 低約 22.7%；資源管制後三節點 RF=3 的分散優勢不足以抵消每 pod 2 CPU 上限。

### 結論

CockroachDB 對 K8s 容器化本身幾乎無損，但對 CPU limit 非常敏感。若生產環境要用 K8s 跑 CockroachDB，`limits.cpu=2` 會把 TPC-C peak 壓低約一半；建議 capacity planning 以 CPU limit 為主要 sizing 參數，而不是只看 pod 數。
