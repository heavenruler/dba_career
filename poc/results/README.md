# TPC-C Benchmark Results — S-BASE

## 本報告摘要

我們用業界標準的 OLTP 壓力測試（TPC-C，模擬電商訂單處理）比較兩款分散式資料庫（TiDB、YugabyteDB）在不同部署架構下的吞吐量。目前 YugabyteDB 三組 VM 部署測試完成，數字顯示三節點架構比單節點吞吐量高約 2.5 倍。下一步將完成 K8s 容器化環境測試，以及啟動 TiDB 全部六組對照組測試。

---

**測試工具**：go-tpc（業界標準 TPC-C 模擬器）
**TPC-C**：Transaction Processing Performance Council Benchmark C，模擬倉儲訂單處理的 OLTP（線上交易處理）壓力測試，業界用來衡量資料庫每分鐘能完成多少筆「新訂單」交易，數字越高代表系統越能承載業務尖峰。
**規格**：4 vCPU（虛擬處理器核心）/ 16GB 記憶體 × 節點數 | 128 個倉庫資料 | 同時連線數 16/32/64/128
**方法**：取消使用者操作間隔（持續高壓滿載）| 暖機 5 分鐘 | 正式測試 10 分鐘

---

## 測試矩陣

我們用 5~6 種部署組合來分別觀察不同架構成本：**單節點**測純效能上限、**三節點 VM**加入資料複製成本（高可用代價）、**直連 vs 過 HAProxy** 量測負載均衡器的中介開銷、**K8s 容器化**模擬未來生產環境部署、**有無資源限制**評估資源管制的影響。

**RF（Replication Factor，資料複本數）**：RF=1 表示資料只存一份（不容錯），RF=3 表示同一筆資料寫到三個節點（任一節點故障不影響服務，但寫入成本較高）。
**HAProxy**：開源連線代理，將單一入口的連線分散到後端多節點（負載均衡）；本測試用來模擬正式環境的入口閘道。
**VM (Virtual Machine)**：傳統虛擬機部署，節點之間網路較單純。
**K8s (Kubernetes)**：容器化編排平台，會多一層網路與資源排程，預期會有少量額外消耗。

### TiDB (tidb-tc1) 🔄 進行中

> 各並發水位（16/32/64/128 同時連線）的 tpmC 數值，**越高越好**；peak = 各並發中的最高吞吐量。

| variant | 拓撲 | RF | 入口 | resource limit | 狀態 | 16t | 32t | 64t | 128t | peak |
|---------|------|----|------|----------------|------|-----|-----|-----|------|------|
| vm-1node | VM×1 | 1 | 直連 :4000 | — | ⏳ | — | — | — | — | — |
| vm-1node (no-analyze) | VM×1 | 1 | 直連 :4000 | — | ⏳ | — | — | — | — | — |
| vm-3node | VM×3 | 3 | HAProxy :4000 | — | ⏳ | — | — | — | — | — |
| vm-3node-direct | VM×3 | 3 | 直連 :4000 | — | ⏳ | — | — | — | — | — |
| k8s-3node-unlimit | K8s×3 | 3 | HAProxy :4000 | 無 | ⏳ | — | — | — | — | — |
| k8s-3node-limit | K8s×3 | 3 | HAProxy :4000 | TiKV Nc | ⏳ | — | — | — | — | — |

> **目前進度**：YBDB VM 測試完成，TiDB 測試進行中。

### YugabyteDB (yuga-tc1) 🔄 進行中

> 各並發水位（16/32/64/128 同時連線）的 tpmC 數值，**越高越好**；peak = 各並發中的最高吞吐量。

| variant | 拓撲 | RF | 入口 | resource limit | 狀態 | 16t | 32t | 64t | 128t | peak |
|---------|------|----|------|----------------|------|-----|-----|-----|------|------|
| vm-1node | VM×1 | RF=1 | 直連 :5433 | — | ✅ | 414.7 | 394.8 | 378.6 | 370.4 | **414.7** |
| vm-3node | VM×3 | RF=3 | HAProxy :15433 | — | ✅ | 1036.7 | 971.4 | 965.7 | 915.8 | **1036.7** |
| vm-3node-direct | VM×3 | RF=3 | 直連 :5433 | — | ✅ | 1024.2 | 1016.4 | 1003.2 | 964.7 | **1024.2** |
| k8s-3node-unlimit | K8s×3 | RF=3 | HAProxy :15433 | 無 | ⏳ | — | — | — | — | — |
| k8s-3node-limit | K8s×3 | RF=3 | HAProxy :15433 | tserver Nc | ⏳ | — | — | — | — | — |

> **YBDB 摘要**：三節點架構（vm-3node / vm-3node-direct）比單節點（vm-1node）吞吐量高約 **2.5 倍**，證實水平擴展對 OLTP 寫入有效；HAProxy 入口層額外成本約 3-5%（vm-3node vs vm-3node-direct），在可接受範圍。

---

## 對標維度

| 維度 | TiDB variant | YBDB variant | 說明 |
|------|-------------|-------------|------|
| 單機 VM 基線 | vm-1node (no-analyze) | vm-1node | 最純粹的單節點效能（無資料複製、無負載均衡） |
| 多節點 VM | vm-3node | vm-3node | 三節點 RF=3 部署，包含**資料複製到三個節點的成本（Raft 共識協議：所有寫入需多數節點確認，提供高可用但有寫入延遲代價）** |
| HAProxy overhead | vm-3node vs vm-3node-direct | vm-3node vs vm-3node-direct | 量測**連線代理（負載均衡器）的中介成本**：模擬正式環境前面有 load balancer 時對連線延遲與吞吐的影響 |
| K8s 無限制 | k8s-3node-unlimit | k8s-3node-unlimit | 容器化平台的**額外效能損耗**（容器網路 + 排程開銷）|
| K8s 資源限制 | k8s-3node-limit | k8s-3node-limit | 啟用容器資源管制（CPU/記憶體上限）後的影響 |

---

## 環境規格

| 項目 | TiDB | YBDB |
|------|------|------|
| 節點組成 | TiDB + TiKV×3 + PD（**TiDB**=SQL 接收層；**TiKV**=資料儲存層 ×3 副本；**PD（Placement Driver）**=叢集元資料管理與排程器）| 3-node (**tserver**=資料儲存與 SQL 執行；**master**=叢集元資料與排程) / 1-node |
| CPU | 4 vCPU (Xeon Gold 6346) | 4 vCPU (Xeon Gold 6346) |
| RAM | 16GB | 16GB |
| max_connections | 無限 | 300 / tserver（每個資料節點上限 300 條連線）|
| 特殊 flags | tidb_auto_analyze_ratio=0 **（停用自動統計分析，避免測試期間背景工作干擾結果，僅 no-analyze variant 啟用）** | packed_row=false **（關閉壓縮儲存，用標準格式確保相容性）**、wait_queues=true **（啟用鎖等待排隊，避免高並發下衝突無限重試）**、read_committed=true **（套用標準的 read committed 隔離等級，與 PostgreSQL 預設一致）** |

---

## 參考

- TiDB 詳細分析: `results_old/tidb-tc1/S-BASE/compare.md`
- YBDB 歷史 pipeline log: `results_old/yuga-tc1/S-BASE/pipeline-log.md`
- YBDB 本輪測試紀錄: `yuga-tc1/S-BASE/pipeline-log.md`
