# TPC-C Benchmark Results — S-BASE

## 本報告摘要

我們用業界標準的 OLTP 壓力測試（TPC-C，模擬電商訂單處理）比較三款分散式資料庫（TiDB、CockroachDB、YugabyteDB）在不同部署架構下的吞吐量。

**單節點 vm-1node 對比**（相同硬體、READ COMMITTED 隔離；READ COMMITTED 是「交易隔離等級」的一種設定，決定多筆交易同時跑時彼此能看到對方未完成資料的程度；本次三款資料庫統一切到此等級，確保對比基準一致。詳見下方「特殊 flags」區塊）：
- **TiDB peak 13,355 tpmC**（64t），延遲 39-268ms
- **CockroachDB peak 8,732 tpmC**（32t），延遲 62-565ms（~ TiDB 65%）
- **YugabyteDB peak 414.7 tpmC**（16t），延遲 2,225-15,655ms（~ TiDB 3%）

**三節點 vm-3node 完整結果**（HAProxy roundrobin）：
- **TiDB peak 22,841 tpmC**（128t，clean 重跑為基準；三次 128t 測量範圍 21,875–23,746，±4.3%）— 三家最高；vm-3node-direct → HAProxy 提升 **+55%**（SQL 節點 .32/.33 分散處理）
- **CockroachDB peak 14,014 tpmC**（128t）— symmetric architecture，HAProxy 比直連 +26%
- **YugabyteDB peak 1,036.7 tpmC**（16t）— tserver 一體設計，HAProxy 與 direct 差異僅 +1%（受 **MVCC**（Multi-Version Concurrency Control 多版本併發控制——每筆資料保留多份版本，衝突時偵測重做）的競爭設計天花板限制；無論加多少節點，相同熱點資料 row 仍然只能單線結帳，這就是上限的來源）

**K8s 容器化（k8s-3node-unlimit）overhead**：
- **TiDB** vm-3node 22,841 → K8s 18,919 — overhead **~17%**
- **CockroachDB** vm-3node 14,014 → K8s 13,982 — overhead **~0.2%**（幾乎無損；symmetric architecture 對容器化最友善）
- **YugabyteDB** — K8s 部署待測

**K8s 資源限制（k8s-3node-limit）影響**：
- **TiDB** K8s-unlimit 18,919 → K8s-limit 11,081 — 下降 **41%**
- **CockroachDB** K8s-unlimit 13,982 → K8s-limit 6,750 — 下降 **52%**
- **YugabyteDB** — K8s 部署待測

下一步完成 YBDB K8s 變體。

---

## 測試環境總覽

- **測試工具**：go-tpc（業界標準 TPC-C 模擬器）

- **TPC-C**（Transaction Processing Performance Council Benchmark C）：模擬倉儲訂單處理的 OLTP（線上交易處理）壓力測試，業界用來衡量資料庫每分鐘能完成多少筆「新訂單」交易，數字越高代表系統越能承載業務尖峰。

- **規格**：4 vCPU（虛擬處理器核心）/ 16GB 記憶體 × 節點數

- **資料量**：128 個倉庫

- **併發連線數**：16 / 32 / 64 / 128（壓測工具 go-tpc 啟動的同時工作執行緒數，每個執行緒佔用一條資料庫連線，持續送訂單／付款交易；分四檔由低到高，用來觀察吞吐量隨併發成長的飽和曲線——管理層可理解為「同一瞬間有多少使用者同時下單」）

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
  - **NodePort**：K8s 對外暴露服務的固定埠口模式（埠號通常在 30000-32767 區間）；本測試 `:30004` 即指向 K8s 叢集內的 TiDB SQL 服務。

- **資源限制標記**：
  - `TiKV Nc` — 限制 TiKV 儲存元件可用的 CPU 核心數
  - `tserver Nc` — 限制 YugabyteDB 資料節點可用的 CPU 核心數

### TiDB (tidb-tc1) 🔄 進行中

> 各併發水位（16/32/64/128 同時連線）的 tpmC 數值，**越高越好**；peak = 各併發中的最高吞吐量。

| variant | 拓撲 | RF | 入口 | resource limit | 狀態 | 16t | 32t | 64t | 128t | peak |
|---------|------|----|------|----------------|------|-----|-----|-----|------|------|
| vm-1node | VM×1 | 1 | 直連 :4000 | — | ✅ | 11,895.0 | 12,766.7 | 13,355.4 | 13,078.8 | **13,355.4** |
| vm-1node (no-analyze) | VM×1 | 1 | 直連 :4000 | — | ✅ | 11,380.6 | 12,596.2 | 13,345.3 | 13,191.7 | **13,345.3** |
| vm-3node | VM×3 | 3 | HAProxy :4000 | — | ✅ | 13,573.7 | 19,205.1 | 21,992.7 | 22,841.0 | **22,841.0** |
| vm-3node-direct | VM×3 | 3 | 直連 :4000 | — | ✅ | 12,882.2 | 14,385.6 | 13,204.3 | 14,779.6 | **14,779.6** |
| k8s-3node-unlimit | K8s×3 | 3 | NodePort :30004 | 無 | ✅ | 13,160.9 | 16,304.1 | 18,918.8 | 18,871.3 | **18,918.8** |
| k8s-3node-limit | K8s×3 | 3 | NodePort :30004 | TiKV 2c/8GiB | ✅ | 10,470.5 | 11,080.7 | 10,895.5 | 10,519.7 | **11,080.7** |

> `vm-1node (no-analyze)`：停用資料庫自動統計分析（背景工作），讓測試結果排除排程干擾，呈現最純粹的效能數字。

> **目前進度**：TiDB 全 6 組完成（VM 4 + K8s 2）；YBDB VM 三組完成、K8s-unlimit 完成、K8s-limit 待測；CRDB 全 5 組完成（VM 3 + K8s 2）。

> **TiDB 全部署模式對比**：
> - **vm-3node (HAProxy)** peak **22,841**（最佳）— SQL 節點分散最有效
> - vm-3node-direct peak 14,779 — 單一 gateway，無分散優勢
> - vm-1node peak 13,355
> - k8s-3node-unlimit peak 18,919 — 容器化 ~17% overhead
> - **k8s-3node-limit** peak **11,081**（最差）— TiKV 2 CPU cap 限縮天花板 41%

> **TiDB vs CRDB vs YBDB 對比（vm-3node HAProxy）**：TiDB peak **22,841 tpmC**（重 prepare clean run；三次 128t 測量 21,875–23,746 範圍內）、CRDB peak **14,014 tpmC**、YBDB peak **1,036 tpmC**。TiDB SQL/儲存分離設計讓「加台機器跑 SQL」效益最大化（HAProxy 比直連 +55%），CRDB symmetric architecture 也有 +26% 增益，YBDB 因 tserver 一體設計增益僅 +1%。

### YugabyteDB (yuga-tc1) 🔄 進行中

> 各併發水位（16/32/64/128 同時連線）的 tpmC 數值，**越高越好**；peak = 各併發中的最高吞吐量。

| variant | 拓撲 | RF | 入口 | resource limit | 狀態 | 16t | 32t | 64t | 128t | peak |
|---------|------|----|------|----------------|------|-----|-----|-----|------|------|
| vm-1node | VM×1 | RF=1 | 直連 :5433 | — | ✅ | 414.7 | 394.8 | 378.6 | 370.4 | **414.7** |
| vm-3node | VM×3 | RF=3 | HAProxy :15433 | — | ✅ | 1036.7 | 971.4 | 965.7 | 915.8 | **1036.7** |
| vm-3node-direct | VM×3 | RF=3 | 直連 :5433 | — | ✅ | 1024.2 | 1016.4 | 1003.2 | 964.7 | **1024.2** |
| k8s-3node-unlimit | K8s×3 | RF=3 | NodePort :30005 | 無 | ✅ | 2,932.9 | 3,163.6 | 3,144.3 | 2,984.0 | **3,163.6** |
| k8s-3node-limit | K8s×3 | RF=3 | HAProxy :15433 | tserver Nc | ⏳ | — | — | — | — | — |

> **YBDB 摘要**：三節點架構（vm-3node / vm-3node-direct）比單節點（vm-1node）吞吐量高約 **2.5 倍**；K8s-unlimit peak **3,164 tpmC**，比 VM 3-node peak **1,037 tpmC** 高約 **3.1 倍**。本次 K8s 採 YugabyteDB **2025.2.2 LTS**，並明確啟用 `yb_enable_read_committed_isolation=true`，讓 `yb_effective_transaction_isolation_level = read committed`，避免 2025.2 預設映射成 repeatable read 造成 transaction restart。

### CockroachDB (cockroach-tc1) 🔄 進行中

> 各併發水位（16/32/64/128 同時連線）的 tpmC 數值，**越高越好**；peak = 各併發中的最高吞吐量。READ COMMITTED 隔離（與 YBDB 對齊）。

| variant | 拓撲 | RF | 入口 | resource limit | 狀態 | 16t | 32t | 64t | 128t | peak |
|---------|------|----|------|----------------|------|-----|-----|-----|------|------|
| vm-1node | VM×1 | 1 | 直連 :26257 | — | ✅ | 8,559.5 | 8,732.5 | 8,555.3 | 8,133.4 | **8,732.5** |
| vm-3node | VM×3 | 3 | HAProxy :15257 | — | ✅ | 9,958.3 | 11,933.4 | 12,661.7 | 14,014.7 | **14,014.7** |
| vm-3node-direct | VM×3 | 3 | 直連 :26257 | — | ✅ | 9,142.5 | 10,144.4 | 10,892.4 | 11,142.6 | **11,142.6** |
| k8s-3node-unlimit | K8s×3 | 3 | NodePort :30007 | 無 | ✅ | 8,998.0 | 10,599.9 | 12,416.6 | 13,982.2 | **13,982.2** |
| k8s-3node-limit | K8s×3 | 3 | NodePort :30007 | crdb 2c/8GiB | ✅ | 4,931.8 | 5,576.9 | 6,181.7 | 6,749.9 | **6,749.9** |

> **CockroachDB 摘要**：單節點 peak **8,732 tpmC**；三節點 + HAProxy peak **14,014 tpmC**（**超越 TiDB vm-1node 峰值 13,355**）；K8s-unlimit peak **13,982 tpmC**（與 vm-3node HAProxy 幾乎相同，**容器化 overhead −0.2%**，遠優於 TiDB K8s ~17% overhead）；K8s-limit peak **6,750 tpmC**（2 CPU cap 使 peak 較 unlimit 下降 **52%**）。CRDB symmetric architecture 讓 HAProxy roundrobin 將 SQL 處理層分散到三節點，**HAProxy 比直連快 9-26%**（與 YBDB 反向：YBDB direct 略快於 HAProxy）。

---

## 對標維度

| 維度 | TiDB variant | CockroachDB variant | YBDB variant | 說明 |
|------|-------------|---------------------|-------------|------|
| 單機 VM 基線 | vm-1node (no-analyze) | vm-1node | vm-1node | 最純粹的單節點效能（無資料複製、無負載均衡） |
| 多節點 VM | vm-3node | vm-3node | vm-3node | 三節點 RF=3 部署，含資料複製到三個節點的成本 |
| HAProxy overhead | vm-3node vs vm-3node-direct | vm-3node vs vm-3node-direct | vm-3node vs vm-3node-direct | 量測連線代理（負載均衡器）的中介成本（CRDB 反而 HAProxy 較快——symmetric architecture 把 SQL 處理層也分散） |
| K8s 無限制 | k8s-3node-unlimit | k8s-3node-unlimit | k8s-3node-unlimit | 容器化平台的額外效能損耗（容器網路 + 排程開銷） |
| K8s 資源限制 | k8s-3node-limit | k8s-3node-limit | k8s-3node-limit | 啟用容器資源管制（CPU/記憶體上限）後的影響 |

### 補充說明

- **多節點 VM**：採用 **Raft 共識協議**（分散式一致性機制），所有寫入需要多數節點確認，提供高可用性但有寫入延遲代價。

- **HAProxy overhead**：模擬正式環境前面有 load balancer 時對連線延遲與吞吐的影響。

- **三家架構特徵速查**（影響加節點時誰能擴充什麼）：
  - **TiDB（SQL／儲存分離）**：TiDB SQL 接收層與 TiKV 儲存層各自獨立，加 SQL 節點即可橫向擴充處理量（HAProxy 增益最大）。
  - **CockroachDB（symmetric architecture 對稱式）**：每個節點同時具備 SQL 接收與儲存能力，HAProxy 把連線分散到多節點，每台都能完整處理請求。
  - **YugabyteDB（tserver 一體）**：SQL 與儲存綁在同一進程，加節點時 SQL 與儲存一起增加，但實際吞吐受 MVCC 競爭限制。

---

## 三家架構示意圖

各家原廠官方架構圖（點圖連至原始文件）：

### TiDB

[![TiDB Architecture](https://docs-download.pingcap.com/media/images/docs/tidb-architecture-v6.png)](https://docs.pingcap.com/tidb/stable/tidb-architecture/)

來源：[TiDB Architecture — PingCAP Docs](https://docs.pingcap.com/tidb/stable/tidb-architecture/)

### CockroachDB

[![CockroachDB Architecture](https://github.com/cockroachdb/cockroach/raw/master/docs/media/architecture.png)](https://github.com/cockroachdb/cockroach/blob/master/docs/design.md)

來源：[cockroachdb/cockroach — docs/design.md](https://github.com/cockroachdb/cockroach/blob/master/docs/design.md)
（CRDB 官方 docs 站 Architecture Overview 頁為純文字、無單一整體架構圖；此圖取自 CRDB github 原始碼倉庫 `docs/media/architecture.png`，雖為早期設計文件版本，但仍是原廠維護中的官方資料，能完整呈現節點內 SQL/Transactional KV/Distribution/Replication/Storage 各層堆疊與對稱架構。）

### YugabyteDB

[![YugabyteDB Architecture](https://docs.yugabyte.com/images/architecture/layered-architecture.png)](https://docs.yugabyte.com/stable/architecture/)

來源：[Architecture — YugabyteDB Docs](https://docs.yugabyte.com/stable/architecture/)

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
