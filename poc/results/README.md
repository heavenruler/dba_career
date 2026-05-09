# TPC-C Benchmark Results — S-BASE

## 本報告摘要

我們用業界標準的 OLTP 壓力測試（TPC-C，模擬電商訂單處理）比較三款分散式資料庫（TiDB、CockroachDB、YugabyteDB）在不同部署架構下的吞吐量。

**單節點 vm-1node 對比**（相同硬體、READ COMMITTED 隔離）：
- **TiDB peak 13,355 tpmC**（64t），延遲 39-268ms
- **CockroachDB peak 8,732 tpmC**（32t），延遲 62-565ms（~ TiDB 65%）
- **YugabyteDB peak 414.7 tpmC**（16t），延遲 2,225-15,655ms（~ TiDB 3%）

**三節點 vm-3node 完整結果**（HAProxy roundrobin）：
- **TiDB peak 21,875 tpmC**（128t）— 三家最高；vm-3node-direct → HAProxy 提升 **+48%**（SQL 節點 .32/.33 分散處理）
- **CockroachDB peak 14,014 tpmC**（128t）— symmetric architecture，HAProxy 比直連 +26%
- **YugabyteDB peak 1,036.7 tpmC**（16t）— tserver 一體設計，HAProxy 與 direct 差異僅 +1%（受 MVCC 競爭天花板限制）

下一步將完成 K8s 容器化環境測試。

---

## 測試環境總覽

- **測試工具**：go-tpc（業界標準 TPC-C 模擬器）

- **TPC-C**（Transaction Processing Performance Council Benchmark C）：模擬倉儲訂單處理的 OLTP（線上交易處理）壓力測試，業界用來衡量資料庫每分鐘能完成多少筆「新訂單」交易，數字越高代表系統越能承載業務尖峰。

- **規格**：4 vCPU（虛擬處理器核心）/ 16GB 記憶體 × 節點數

- **資料量**：128 個倉庫

- **併發連線數**：16 / 32 / 64 / 128

- **測試方法**：取消使用者操作間隔（持續高壓滿載）、暖機 5 分鐘、正式測試 10 分鐘

---

## 測試矩陣

我們用 5~6 種部署組合來分別觀察不同架構成本：

- **單節點**：測純效能上限
- **三節點 VM**：加入資料複製成本（高可用代價）
- **直連 vs 過 HAProxy**：量測負載均衡器的中介開銷
- **K8s 容器化**：模擬未來生產環境部署
- **有無資源限制**：評估資源管制的影響

### 名詞說明

- **RF（Replication Factor，資料複本數）**：RF=1 表示資料只存一份（不容錯）；RF=3 表示同一筆資料寫到三個節點（任一節點故障不影響服務，但寫入成本較高）。

- **HAProxy**：開源連線代理，將單一入口的連線分散到後端多節點（負載均衡）；本測試用來模擬正式環境的入口閘道。

- **VM（Virtual Machine）**：傳統虛擬機部署，節點之間網路較單純。

- **K8s（Kubernetes）**：容器化編排平台，會多一層網路與資源排程，預期會有少量額外消耗。

- **連線端口**：
  - `:4000` — TiDB SQL 服務端口；同時也是 TiDB HAProxy 監聽端口（**proxy 部署在獨立主機**，與 TiDB 節點不衝突，流量由此轉發至後端 TiDB:4000）
  - `:5433` — YBDB SQL 服務端口
  - `:15433` — YBDB HAProxy 監聽端口（與 YBDB 共用同一台主機，避用 5433），流量由此轉發至後端 YBDB:5433
  - `:26257` — CockroachDB SQL 服務端口（PostgreSQL 協定相容）

- **資源限制標記**：
  - `TiKV Nc` — 限制 TiKV 儲存元件可用的 CPU 核心數
  - `tserver Nc` — 限制 YugabyteDB 資料節點可用的 CPU 核心數

### TiDB (tidb-tc1) 🔄 進行中

> 各併發水位（16/32/64/128 同時連線）的 tpmC 數值，**越高越好**；peak = 各併發中的最高吞吐量。

| variant | 拓撲 | RF | 入口 | resource limit | 狀態 | 16t | 32t | 64t | 128t | peak |
|---------|------|----|------|----------------|------|-----|-----|-----|------|------|
| vm-1node | VM×1 | 1 | 直連 :4000 | — | ✅ | 11,895.0 | 12,766.7 | 13,355.4 | 13,078.8 | **13,355.4** |
| vm-1node (no-analyze) | VM×1 | 1 | 直連 :4000 | — | ✅ | 11,380.6 | 12,596.2 | 13,345.3 | 13,191.7 | **13,345.3** |
| vm-3node | VM×3 | 3 | HAProxy :4000 | — | ✅ | 13,957.6 | 18,393.2 | 21,523.0 | 21,875.0 | **21,875.0** |
| vm-3node-direct | VM×3 | 3 | 直連 :4000 | — | ✅ | 12,882.2 | 14,385.6 | 13,204.3 | 14,779.6 | **14,779.6** |
| k8s-3node-unlimit | K8s×3 | 3 | HAProxy :4000 | 無 | ⏳ | — | — | — | — | — |
| k8s-3node-limit | K8s×3 | 3 | HAProxy :4000 | TiKV Nc | ⏳ | — | — | — | — | — |

> `vm-1node (no-analyze)`：停用資料庫自動統計分析（背景工作），讓測試結果排除排程干擾，呈現最純粹的效能數字。

> **目前進度**：TiDB / YBDB VM 三組（vm-1node / vm-3node / vm-3node-direct）全部完成；K8s variant 進行中。

> **TiDB vs CRDB vs YBDB 對比（vm-3node HAProxy）**：TiDB peak **21,875 tpmC**、CRDB peak **14,014 tpmC**、YBDB peak **1,036 tpmC**。TiDB SQL/儲存分離設計讓「加台機器跑 SQL」效益最大化（HAProxy 比直連 +48%），CRDB symmetric architecture 也有 +26% 增益，YBDB 因 tserver 一體設計增益僅 +1%。

### YugabyteDB (yuga-tc1) 🔄 進行中

> 各併發水位（16/32/64/128 同時連線）的 tpmC 數值，**越高越好**；peak = 各併發中的最高吞吐量。

| variant | 拓撲 | RF | 入口 | resource limit | 狀態 | 16t | 32t | 64t | 128t | peak |
|---------|------|----|------|----------------|------|-----|-----|-----|------|------|
| vm-1node | VM×1 | RF=1 | 直連 :5433 | — | ✅ | 414.7 | 394.8 | 378.6 | 370.4 | **414.7** |
| vm-3node | VM×3 | RF=3 | HAProxy :15433 | — | ✅ | 1036.7 | 971.4 | 965.7 | 915.8 | **1036.7** |
| vm-3node-direct | VM×3 | RF=3 | 直連 :5433 | — | ✅ | 1024.2 | 1016.4 | 1003.2 | 964.7 | **1024.2** |
| k8s-3node-unlimit | K8s×3 | RF=3 | HAProxy :15433 | 無 | ⏳ | — | — | — | — | — |
| k8s-3node-limit | K8s×3 | RF=3 | HAProxy :15433 | tserver Nc | ⏳ | — | — | — | — | — |

> **YBDB 摘要**：三節點架構（vm-3node / vm-3node-direct）比單節點（vm-1node）吞吐量高約 **2.5 倍**，證實水平擴展對 OLTP 寫入有效；HAProxy 入口層額外成本約 3-5%（vm-3node vs vm-3node-direct），在可接受範圍。

### CockroachDB (cockroach-tc1) 🔄 進行中

> 各併發水位（16/32/64/128 同時連線）的 tpmC 數值，**越高越好**；peak = 各併發中的最高吞吐量。READ COMMITTED 隔離（與 YBDB 對齊）。

| variant | 拓撲 | RF | 入口 | resource limit | 狀態 | 16t | 32t | 64t | 128t | peak |
|---------|------|----|------|----------------|------|-----|-----|-----|------|------|
| vm-1node | VM×1 | 1 | 直連 :26257 | — | ✅ | 8,559.5 | 8,732.5 | 8,555.3 | 8,133.4 | **8,732.5** |
| vm-3node | VM×3 | 3 | HAProxy :15257 | — | ✅ | 9,958.3 | 11,933.4 | 12,661.7 | 14,014.7 | **14,014.7** |
| vm-3node-direct | VM×3 | 3 | 直連 :26257 | — | ✅ | 9,142.5 | 10,144.4 | 10,892.4 | 11,142.6 | **11,142.6** |

> **CockroachDB 摘要**：單節點 peak **8,732 tpmC**；三節點 + HAProxy peak **14,014 tpmC**（**超越 TiDB vm-1node 峰值 13,355**）。CRDB symmetric architecture 讓 HAProxy roundrobin 將 SQL 處理層分散到三節點，**HAProxy 比直連快 9-26%**（與 YBDB 反向：YBDB direct 略快於 HAProxy）。

---

## 對標維度

| 維度 | TiDB variant | CockroachDB variant | YBDB variant | 說明 |
|------|-------------|---------------------|-------------|------|
| 單機 VM 基線 | vm-1node (no-analyze) | vm-1node | vm-1node | 最純粹的單節點效能（無資料複製、無負載均衡） |
| 多節點 VM | vm-3node | vm-3node | vm-3node | 三節點 RF=3 部署，含資料複製到三個節點的成本 |
| HAProxy overhead | vm-3node vs vm-3node-direct | vm-3node vs vm-3node-direct | vm-3node vs vm-3node-direct | 量測連線代理（負載均衡器）的中介成本（CRDB 反而 HAProxy 較快——symmetric architecture 把 SQL 處理層也分散） |
| K8s 無限制 | k8s-3node-unlimit | (規劃中) | k8s-3node-unlimit | 容器化平台的額外效能損耗（容器網路 + 排程開銷） |
| K8s 資源限制 | k8s-3node-limit | (規劃中) | k8s-3node-limit | 啟用容器資源管制（CPU/記憶體上限）後的影響 |

### 補充說明

- **多節點 VM**：採用 **Raft 共識協議**（分散式一致性機制），所有寫入需要多數節點確認，提供高可用性但有寫入延遲代價。

- **HAProxy overhead**：模擬正式環境前面有 load balancer 時對連線延遲與吞吐的影響。

---

## 環境規格

| 項目 | TiDB | CockroachDB | YBDB |
|------|------|-------------|------|
| 節點組成 | TiDB + TiKV×3 + PD | cockroach single-node（v26.1.4，單一 binary 整合 SQL + 儲存 + 元資料） | 3-node (tserver + master) / 1-node |
| CPU | 4 vCPU (Xeon Gold 6346) | 4 vCPU (Xeon Gold 6346) | 4 vCPU (Xeon Gold 6346) |
| RAM | 16GB | 16GB | 16GB |
| max_connections | 無限 | 預設（CRDB 動態管理，未調整） | 300 / tserver |

### 節點元件說明

**TiDB**

- **TiDB**：SQL 接收層
- **TiKV**：資料儲存層 ×3 副本
- **PD（Placement Driver）**：叢集元資料管理與排程器

**CockroachDB**

- **cockroach**：單一 binary 同時負責 SQL 接收、資料儲存、叢集元資料管理（架構比 TiDB / YBDB 簡單，無獨立元件）

**YBDB**

- **tserver**：資料儲存與 SQL 執行
- **master**：叢集元資料與排程

### 連線數補充

- **TiDB max_connections=無限**：測試環境設定，生產部署通常會依資源配置設定上限。
- **CockroachDB max_connections=預設**：CRDB 動態管理連線資源，未明確設定上限。
- **YBDB max_connections=300/tserver**：每個資料節點上限 300 條連線。

### 特殊 flags

**TiDB**

- `tidb_enable_auto_analyze = OFF` — 停用自動統計分析，避免測試期間背景工作干擾結果（僅 no-analyze variant 啟用；v8.5+ 以此 flag 取代舊的 `tidb_auto_analyze_ratio=0`，後者已不接受 0 值）

**CockroachDB**

- `sql.txn.read_committed_isolation.enabled = true` — 啟用 READ COMMITTED 隔離（CRDB 預設為 SERIALIZABLE，本次切 RC 是為了與 YBDB 對齊比較基準）
- `default_transaction_isolation = 'read committed'` — 將 RC 設為預設交易隔離等級
- `--insecure` — 啟用無 TLS 模式（測試環境簡化，正式部署應啟用加密）

**YBDB**

- `packed_row=false` — 關閉壓縮儲存，用標準格式確保相容性
- `wait_queues=true` — 啟用鎖等待排隊，避免高併發下衝突無限重試
- `read_committed=true` — 套用標準的 read committed 隔離等級，與 PostgreSQL 預設一致

---

## 參考

- TiDB 本輪測試紀錄: `tidb-tc1/S-BASE/pipeline-log.md`
- CockroachDB 本輪測試紀錄: `cockroach-tc1/S-BASE/pipeline-log.md`
- YBDB 本輪測試紀錄: `yuga-tc1/S-BASE/pipeline-log.md`
- TiDB 歷史分析: `results_old/tidb-tc1/S-BASE/compare.md`
- YBDB 歷史 pipeline log: `results_old/yuga-tc1/S-BASE/pipeline-log.md`
