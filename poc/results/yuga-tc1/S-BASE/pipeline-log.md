# YugabyteDB TPC-C Pipeline Log — yuga-tc1 / S-BASE

> **本測試結論**：
> - YugabyteDB 2025.2.2 LTS + 有效 Read Committed (`yb_enable_read_committed_isolation=true` + tserver flag 雙閘) 後 TPC-C 才有可比結果；舊版 / preview RR 模式會持續觸發 `Restart read required` 而吞吐失真
> - vm-1node peak ~10,844 tpmC @ t16；K8s-3node-unlimit peak ~3,164 tpmC @ t32（已啟用有效 RC）；K8s-3node-limit 已在同條件下完成
> - **本檔多數結果為單次 10min wrapper run**（非 v4.7 標準的 detached suite × 5-round × 20min warmup），跨家對標時須留意；新版 v4.7 wrapper 重跑列為下一步待辦

---

## 環境版本與 Isolation 問題紀錄

### 1. YugabyteDB 2025.2 LTS 無法在 AlmaLinux 10.1 上運作

**原始 vm-\* 測試資料均在 YugabyteDB 2.20 版本下測得，非 2025.2 LTS。**

原因：YugabyteDB 2025.2 LTS 的 binary 依賴 glibc 2.34+（el9 / Ubuntu 22.04 以上），而 AlmaLinux 10.1 雖版本號更新，但 template 安裝的系統套件版本不相容（python 環境殘缺、`dataclasses` module 缺失於預設 python3.6），導致 `yugabyted` 無法正常啟動。實際錯誤：

- `yugabyted start` shebang `#!/usr/bin/env python3` 解析到 python 3.6，缺少 `dataclasses` module（Python 3.7+ 才有）

因此 vm-* 的舊測試結果基於 [YugabyteDB 2.20](https://docs.yugabyte.com/stable/releases/ybdb-releases/v2.20/) + snapshot isolation（預設），**不具備 2025.2 LTS + Read Committed 的可比性**，已移至 `pipeline-log_old.md` 存檔。

---

### 2. 改用 AlmaLinux 8.10 後的調整項目

重建 VM template 改為 **AlmaLinux 8.10**，並針對以下問題逐一修正：

| 問題 | 調整方式 |
|------|---------|
| ansible-core 2.18 控制節點對 AlmaLinux 8 受控節點使用 Python 3.6，模組內 `from __future__ import annotations` 語法需 3.7+ | inventory 每台主機加 `ansible_python_interpreter=/usr/bin/python3.9` |
| `ansible.builtin.dnf` 模組在 python3.9 下無法找到 dnf Python bindings（僅 platform-python 3.6 有） | 所有 dnf 安裝改為 `ansible.builtin.command: dnf install -y ...` |
| `ansible.posix.selinux` 模組需要 libselinux-python for python3.9（未預裝） | 改用 `ansible.builtin.replace` 修改 `/etc/selinux/config` + `command: setenforce 0` |
| `yugabyted` shebang 解析到 python3.6（缺 `dataclasses`） | 在受控節點執行 `alternatives --set python3 /usr/bin/python3.8`；role 建立 `/usr/bin/python` → `python3.8` symlink |
| `yugabyted.conf` 殘留導致新叢集沿用舊 cluster UUID，YCQL system tables 初始化不完整（`Table system.transactions not found`） | 完整清除 `/home/yugabyte/var/`、`/opt/yugabyte/data/`、`/opt/yugabyte/logs/` 後重新 bootstrap |

---

### 3. Isolation 模式說明

YugabyteDB 支援三種交易隔離層級，設定分兩層：

- [ysql_default_transaction_isolation](https://docs.yugabyte.com/stable/reference/configuration/yb-tserver/#ysql-default-transaction-isolation)
- [yb_enable_read_committed_isolation](https://docs.yugabyte.com/stable/reference/configuration/yb-tserver/#yb-enable-read-committed-isolation)

#### 啟用層（tserver gflag，必須同時設定，否則 SQL 層設定無效）
```
yb_enable_read_committed_isolation=true ; Default: false
```

> When set to false, Read Committed (and Read Uncommitted) isolation level of YSQL fall back to the stricter Snapshot isolation. See also the --ysql_default_transaction_isolation flag.

#### 設定層（session / transaction level）
```sql
SET transaction_isolation = 'read committed';  -- 或 'repeatable read' / 'serializable / read uncommitted' # Default: 'read committed'
```

> If yb_enable_read_committed_isolation is false, the Read Committed isolation level of the YugabyteDB transactional layer falls back to the stricter Snapshot isolation (in which case Read Committed and Read Uncommitted of YSQL also in turn use Snapshot isolation).

> ⚠️ **重要**：若只在 SQL 層設定 `read committed`，`SHOW transaction_isolation` 顯示正確，但 `SHOW yb_effective_transaction_isolation_level` 仍可能回傳 `repeatable read`（底層實際執行的隔離層級），導致仍出現 `could not serialize access` / `Restart read required` 錯誤。**必須同時啟用 tserver gflag 才有效。**

| 模式 | 說明 | go-tpc flag |
|------|------|-------------|
| `serializable` | 最嚴格，完全防止所有並發異象；高競爭下重試最多 | `--isolation 4` |
| `repeatable read`（YugabyteDB 預設） | YugabyteDB 預設值；底層使用 snapshot isolation，不符合 PostgreSQL `repeatable read` 語意 | `--isolation 3` |
| `read committed` | 與 PostgreSQL 相容的標準 RC；每個 statement 取新 snapshot，大幅減少 write-write conflict 重試 | `--isolation 2` |
| `read uncommitted` | 官方支援的有效值（[ysql_default_transaction_isolation](https://docs.yugabyte.com/stable/reference/configuration/yb-tserver/#ysql-default-transaction-isolation)），但 YugabyteDB 實作上等同 `read committed`，不會真正讀取未提交資料 | `--isolation 1` |

本測試使用 **Read Committed**（`--isolation 2`）+ tserver flag `yb_enable_read_committed_isolation=true`。

官方文件：
- [Transaction Isolation Levels (stable 2025.2)](https://docs.yugabyte.com/stable/architecture/transactions/isolation-levels/)
- [Read Committed Isolation (stable 2025.2)](https://docs.yugabyte.com/stable/architecture/transactions/read-committed/)
- [yb_enable_read_committed_isolation flag (stable 2025.2)](https://docs.yugabyte.com/stable/reference/configuration/yb-tserver/#yb-enable-read-committed-isolation)

---

## 各 variant 拓撲總覽

```
vm-1node                                  client (go-tpc on .31)
                                                  │
                                                  ▼ :5433 (direct)
                              ┌───────────────────────────────────┐
                              │ .32:  master + tserver  (RF=1)    │
                              └───────────────────────────────────┘
  deploy: yugabyted start --advertise_address=172.24.40.32
          tserver flags: ysql_enable_packed_row=false
                         yb_enable_read_committed_isolation=true
                         enable_wait_queues=true
                         ysql_num_shards_per_tserver=3


vm-3node-direct                           client (go-tpc on .31)
                                                  │
                                                  ▼ :5433 (direct, no HAProxy)
                              ┌────────────────────────────────────┐
                              │ .32:  master + tserver ◄───────────┤ (bootstrap, zone=asia-east1-a)
                              │ .33:  master + tserver             │ (join,      zone=asia-east1-b)
                              │ .34:  master + tserver             │ (join,      zone=asia-east1-c)
                              └────────────────────────────────────┘
  RF=3, fault_tolerance=zone
  deploy: yugabyted start/join; yuga-tc1.ini
  ⚠️ 歷史 prepare 曾走 HAProxy :15433；舊 HAProxy 30s timeout 會切斷長時間 check SQL


vm-3node                                  client (go-tpc on .31)
                                                  │
                                                  ▼ :15433
                              ┌───────────────────────────────────┐
                              │ .32:  HAProxy → roundrobin        │
                              │       master + tserver  ▼  ▼  ▼   │
                              │ .32/.33/.34: tserver ◄────────────┤
                              └───────────────────────────────────┘
  同 vm-3node-direct 叢集（不重 prepare）
  HAProxy timeout client/server 600s（避免高壓交易期間半開連線 hang）
  deploy: yuga-tc1.ini [haproxy] on .32


k8s-3node-unlimit                         client (go-tpc on .31)
                                                  │
                                                  ▼ NodePort :30005
                              ┌───────────────────────────────────┐
                              │ k3s cluster (3 nodes)             │
                              │ ┌─ .32 master ──┐ ┌─ .33 worker ─┐ │
                              │ │ yb-master-0   │ │ yb-master-1  │ │
                              │ │ yb-tserver-0  │ │ yb-tserver-1 │ │
                              │ └───────────────┘ └──────────────┘ │
                              │ ┌─ .34 worker ──┐                  │
                              │ │ yb-master-2   │                  │
                              │ │ yb-tserver-2  │                  │
                              │ └───────────────┘                  │
                              └───────────────────────────────────┘
  chart: yugabytedb/yugabyte 2025.2.2; RF=3; DB 主容器無 resource limits
  yb_enable_read_committed_isolation=true; go-tpc --isolation 2; prepare --no-check
  deploy: yugabyte-k8s.yml + yuga-tc1-k8s.ini + vars/yugabyte-k8s-3node-unlimit.yml


k8s-3node-limit                           同 k8s-3node-unlimit 拓撲
                                          差別：yb_resource_limits=true
                                          tserver 2c/8GiB、master 1c/2GiB
                                          deploy vars: yugabyte-k8s-3node-limit.yml
                                          result: 20260513-0954
```

---

## 共通說明：Warmup（暖機）的作用

正式測試開始前，先讓資料庫在真實負載下跑 5 分鐘。這段時間資料庫會把常用的資料從硬碟載入記憶體、建立內部索引快取、穩定連線池。如果跳過暖機，正式測試前幾分鐘的數字會因為「冷啟動」而異常偏低，無法反映系統的真實效能。

**TiDB 與 YugabyteDB 在 warmup 階段影響最大的元件不同**：
- **TiDB 影響較大的元件是 TiKV**：底層儲存 RocksDB 有 block cache（記憶體資料塊快取），冷啟動時所有讀取都要去硬碟撈，warmup 期間 cache 才被熱資料填滿。**另一關鍵**：TPC-C 高壓寫入會讓 TiKV 自動進行 Region 分裂（把熱點資料拆散到不同節點），主要發生在 warmup 期間；跳過會導致正式測試前段大量分裂風暴，數字嚴重失真。
- **YugabyteDB 影響較大的元件是 DocDB tablet cache**：底層儲存 DocDB 同樣基於 RocksDB，tablet（資料分片）的 cache 需要 warmup 填充。本測試已預先設定 `ysql_num_shards_per_tserver=3`（固定分片數），動態分裂比 TiDB 少，warmup 主要作用是 cache 預熱。相對 TiDB，YugabyteDB 受 warmup 影響的幅度略小，但 MVCC（樂觀多版本併發控制）版本鏈（交易衝突偵測的內部記錄結構）的初始建立也集中在這個階段。

> **白話**：TiDB 的暖機主要讓「資料分裂」在正式測試前完成，YugabyteDB 的暖機主要讓「記憶體快取」填滿。兩者都需要，但 TiDB 跳過暖機的代價更大。

---

## vm-1node — 2026-05-14

> 🟡 **legacy single-run**：本段為 PoC v4.7 前的單次 10min wrapper 結果，**非** v4.7 標準的 5-round × 20min warmup × DB-host 雙邊監控。跨家對標時須使用此 caveat。

### 環境
- 版本：**YugabyteDB 2025.2.2.2-b0**（PostgreSQL 15.12-YB-2025.2.2.2-b0）
- OS：AlmaLinux 8.10
- 節點：.32 (172.24.40.32) 單節點 RF=1
- tserver flags：`yb_enable_read_committed_isolation=true`
- Isolation 驗證：`yb_effective_transaction_isolation_level = read committed`
- 連線入口：直連 172.24.40.32:5433
- 測試工具：go-tpc on .31（`-d postgres --conn-params sslmode=disable --isolation 2`）
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`vm-1node/20260514-1337/`

### Prepare
- 時間：16m05s（128W）
- 無 consistency check（`prepare --no-check`）

### Execute 結果

> ⚠️ efficiency > 100% 為無 think time 的壓測常態，非錯誤

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | **10,844.2** | 24,014.7 | 658.8% | 55.6 | 113.2 |
| 32 | 10,341.4 | 22,951.8 | 628.2% | 117.2 | 234.9 |
| 64 | 9,982.5 | 22,178.8 | 606.4% | 243.4 | 520.1 |
| 128 | 8,905.7 | 19,711.1 | 541.0% | 551.6 | 1,342.2 |

### vs 舊版 vm-1node（2.20 + snapshot）對比

| threads | 舊 tpmC (2.20) | 新 tpmC (2025.2) | 倍數 | 舊 NO avg | 新 NO avg |
|---------|---------------|-----------------|------|-----------|-----------|
| 16 | 414.7 | 10,844.2 | **26.1×** | 2,225ms | 55.6ms |
| 32 | 394.8 | 10,341.4 | **26.2×** | 4,686ms | 117.2ms |
| 64 | 378.6 | 9,982.5 | **26.4×** | 9,548ms | 243.4ms |
| 128 | 370.4 | 8,905.7 | **24.0×** | 15,655ms | 551.6ms |

### 觀察

- **吞吐提升約 25× 以上**：主要來自版本升級（2.20 → 2025.2）+ Read Committed 生效，RC 讓 write-write conflict 大幅減少，不再需要大量 MVCC rollback/retry。
- **P99 從 16,106ms 降至 1,342ms（128t）**：舊版 128t 幾乎全部逾時（go-tpc 上限 16s），新版最差 1% 用戶等待約 1.3 秒，完全不同量級。
- **NO avg 線性惡化仍存在**：55.6 → 117.2 → 243.4 → 551.6ms，每次 thread 翻倍延遲約翻倍，MVCC 架構特性不變，但在可接受範圍內。
- **峰值在 16t**：tpmC 10,844 → 8,906 隨併發略降，單節點 tablet 競爭在 128t 時開始顯現，但遠未到 2.20 版的崩潰水位。
- **無 serialization/restart 錯誤**：log 掃描無 `could not serialize`、`Restart read required`，RC 隔離層有效運作。

---

## vm-3node-direct — 2026-05-07

> 重測中，數據待補

---

## vm-3node — 2026-05-07

> 重測中，數據待補

---

## k8s-3node-unlimit — 2026-05-13

> 🟡 **legacy single-run**：本段為 PoC v4.7 前的單次 10min wrapper 結果，**非** v4.7 標準的 5-round × 20min warmup × DB-host 雙邊監控。

### 環境
- 拓撲：**k3s** v1.29.14 三節點（.32 master，.33/.34 worker）+ YugabyteDB Helm chart **2025.2.2**（image/binary `2025.2.2.2 build 11`）
- 版本驗證：pod 內 `yb-master/yb-tserver --version` 均為 `version 2025.2.2.2 build 11`
- 連線入口：NodePort `.32:30005`（YSQL），`.32:30006`（YCQL）
- RF：3（3 master + 3 tserver）
- 容器資源限制：DB 主容器無 limits（`yb-master` requests 500m/1Gi，`yb-tserver` requests 1 CPU/2Gi，`limits=` 空值）；`yb-cleanup` sidecar 保留 chart 預設 250m/250Mi
- 儲存：master 10 GiB PVC ×3，tserver 50 GiB PVC ×3（local-path StorageClass）
- 測試工具：go-tpc on .31（`-d postgres --conn-params sslmode=disable --isolation 2`）
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`k8s-3node-unlimit/20260513-0114/`

### 部署 / 接手紀錄
- 先移除 CockroachDB K8s 測試環境：刪除 `cockroach-tc1` namespace，釋放 NodePort `30007/30008` 與 PVC。
- 初次 YugabyteDB K8s 安裝誤用 chart 2024.2.3，SQL version 顯示 `2024.2.3.3-b0`，不符合 2025.2 LTS 要求，已刪除重建。
- 改用 chart **2025.2.2**，Helm app version `2025.2.2.2-b11`；SQL `version()` 顯示 `PostgreSQL 15.12-YB-2025.2.2.2-b0`，pod binary `--version` 驗證為 build 11。
- Helm chart 2025.2.2 的 `serviceEndpoints` 不支援直接指定 fixed `nodePort`；實作方式改為手動建立 `yb-tserver-service` NodePort service，固定 YSQL `30005`、YCQL `30006`。
- Helm chart 預設會渲染 DB container limits（master 2c/2Gi，tserver 2c/4Gi），本次以 `kubectl patch sts ... remove /resources/limits` 移除 DB 主容器 limits，保留 requests。
- go-tpc `prepare` 預設會執行 `begin to check warehouse ...` consistency check，YugabyteDB 2025.2 上跨表聚合查詢可卡 30+ 分鐘；wrapper 已改為 `prepare --no-check`，另以表筆數做資料完整性檢查。
- 表筆數驗證：warehouse 128、district 1,280、customer/history/orders 3,840,000、item 100,000、stock 12,800,000、new_order 1,152,000；`order_line` 約 38.4M（實測 38,396,798，符合每 order 5-15 lines 隨機分布，不應硬性等於 38,400,000）。
- 2025.2 若只設定 SQL isolation/read committed，`SHOW transaction_isolation` 可顯示 RC，但 `SHOW yb_effective_transaction_isolation_level` 仍可能是 `repeatable read`，會導致 `could not serialize access` / `Restart read required`。已啟用 tserver flag `yb_enable_read_committed_isolation=true` 並滾動重啟，驗證：
  - `transaction_isolation = read committed`
  - `yb_effective_transaction_isolation_level = read committed`
- 啟用有效 RC 前的失敗 run 已保留於 `k8s-3node-unlimit/20260513-0028/`、`k8s-3node-unlimit/20260513-0037/` 作 troubleshooting，不列入正式結果。

### Prepare
- 流程：cleanup → `prepare --no-check --isolation 2`
- 時間：10m42s（128W）
- 無 `begin to check warehouse` consistency check

### Execute 結果

> ⚠️ efficiency > 100% 為無 think time 的壓測常態，非錯誤
>
> （tpmC：越高越好；NO avg / NO P99：越低越好）

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 2,932.9 | 6,479.9 | 178.2% | 281.4 | 637.5 |
| 32 | **3,163.6** | 7,008.2 | **192.2%** | 525.2 | 1,476.4 |
| 64 | 3,144.3 | 6,974.7 | 191.0% | 1,059.7 | 3,892.3 |
| 128 | 2,984.0 | 6,653.0 | 181.3% | 2,194.6 | 10,737.4 |

> NO avg/p99 已重新對齊 `k8s-3node-unlimit/20260513-0114/tpcc-c{16,32,64,128}.log` artifact 的 `[Summary] NEW_ORDER` 行。注意本批為**單次 10min run** 的 wrapper log，非 v4.7 標準的 `runs/threads-X/round-Y/go-tpc-stdout.txt` 5-round 格式，故不與 TiDB/CRDB 5-round mean 直比。

### vs VM 3-node 對比

| threads | vm-3node | k8s-3node-unlimit | 倍數 |
|---------|----------|-------------------|------|
| 16 | 1,036.7 | 2,932.9 | 2.83× |
| 32 | 971.4 | 3,163.6 | 3.26× |
| 64 | 965.7 | 3,144.3 | 3.26× |
| 128 | 915.8 | 2,984.0 | 3.26× |

### 觀察

- **K8s-unlimit peak 3,164 tpmC**，約為 VM 3-node peak 1,037 的 **3.1×**。這不是單純「K8s 比 VM 快」，主要變因包含版本從舊 VM 測試的 YugabyteDB 版本升到 **2025.2.2 LTS**，以及真正啟用 DocDB Read Committed。
- **吞吐曲線穩定在 3k tpmC 左右**：16t 到 128t 介於 2,933~3,164，峰值在 32t；高併發沒有再發生 transaction restart error。
- **延遲仍隨併發上升**：NO avg 281ms → 2,195ms，NO P99 638ms → 10,737ms；128t 高壓下仍接近 go-tpc 16s 上限，但比舊 VM 結果的 16,106ms P99 改善。
- **有效 RC 是必要條件**：只加 go-tpc `--isolation 2` 不夠，必須確認 `yb_effective_transaction_isolation_level = read committed`，否則仍會有 `Restart read required` / `could not serialize access`。

### 結論

YugabyteDB 2025.2.2 LTS + K8s-unlimit + 有效 Read Committed 後，TPC-C 吞吐明顯高於既有 VM 三節點結果，且正式結果無 serialization/restart 錯誤。後續所有 YugabyteDB K8s 對標都必須保留同樣的 `yb_enable_read_committed_isolation=true`、`--isolation 2`、`prepare --no-check` 條件，否則結果不可比；本輪 k8s-3node-limit 已依此條件完成。

---

## k8s-3node-limit — 2026-05-13

> 🟡 **legacy single-run**：本段為 PoC v4.7 前的單次 10min wrapper 結果，**非** v4.7 標準的 5-round × 20min warmup × DB-host 雙邊監控。

### 環境
- 拓撲：沿用 k3s v1.29.14 三節點（.32 master，.33/.34 worker）+ YugabyteDB Helm chart **2025.2.2**（image/binary `2025.2.2.2 build 11`）
- 連線入口：NodePort `.32:30005`（YSQL），`.32:30006`（YCQL）
- RF：3（3 master + 3 tserver）
- 容器資源限制：`yb-master` requests 500m/1Gi、limits 1c/2Gi；`yb-tserver` requests 1c/2Gi、limits **2c/8Gi**
- 儲存：master 10 GiB PVC ×3，tserver 50 GiB PVC ×3（local-path StorageClass）
- tserver gflag：`yb_enable_read_committed_isolation=true`
- 隔離層驗證：
  - `transaction_isolation = read committed`
  - `yb_effective_transaction_isolation_level = read committed`
- 測試工具：go-tpc on .31（`-d postgres --conn-params sslmode=disable --isolation 2`）
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`k8s-3node-limit/20260513-0954/`

### Prepare
- 流程：cleanup → `prepare --no-check --isolation 2`
- 時間：15m59s（128W）
- 無 `begin to check warehouse` consistency check

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 1,716.4 | 3,809.5 | 104.3% | 464.4 | 1,275.1 |
| 32 | **1,766.1** | 3,899.9 | **107.3%** | 890.6 | 2,952.8 |
| 64 | 1,627.3 | 3,641.0 | 98.9% | 1,947.1 | 7,516.2 |
| 128 | 1,568.3 | 3,518.7 | 95.3% | 3,811.4 | 15,569.3 |

### vs k8s-3node-unlimit 對比

| threads | k8s-3node-unlimit | k8s-3node-limit | 差距 |
|---------|-------------------|-----------------|------|
| 16 | 2,932.9 | 1,716.4 | -41.5% |
| 32 | 3,163.6 | 1,766.1 | -44.2% |
| 64 | 3,144.3 | 1,627.3 | -48.2% |
| 128 | 2,984.0 | 1,568.3 | -47.4% |

### 觀察

- **K8s-limit peak 1,766 tpmC**，相對 k8s-unlimit peak 3,164 下降 **44.2%**。tserver 2c/8Gi cap 明確壓低吞吐天花板。
- **最佳併發仍在 32t**：limit 與 unlimit 都是 32 threads peak，代表資源限制主要降低總量，不改變飽和點形狀。
- **延遲放大明顯**：32t NO avg 從 unlimit 525ms 升到 limit 891ms；128t NO P99 從 10,737ms 升到 15,569ms，接近 go-tpc 16s 上限。
- **無 serialization/restart 錯誤**：本次 limit run 全程保留有效 Read Committed，log 掃描未見 `could not serialize`、`Restart read required`、`current transaction is aborted`。

### 結論

YugabyteDB K8s 在 tserver **2c/8Gi** 限制下，吞吐較 unlimit 下降約 **44%**，但測試可穩定完成且無 transaction restart 錯誤。這組結果可作為與 TiDB / CockroachDB `k8s-3node-limit` 對標的正式紀錄。

---

## v4.7 標準化待補清單

本檔現有結果為 PoC v4.7 前的 single-run wrapper 格式；以下項目須在 v4.7 detached suite 重跑時補齊，補齊後才能納入跨家正式對比矩陣：

| 項目 | 目前狀態 | v4.7 目標 |
|------|---------|-----------|
| Run 結構 | 單次 10min run | **5 round × 5 min × 4 thread groups + 20min warmup @ 64 threads** |
| Round artifact 格式 | `tpcc-c{16,32,64,128}.log`（wrapper 輸出） | `runs/threads-X/round-Y/go-tpc-stdout.txt`（per-round 結構化） |
| DB-host 監控 | 無 | mpstat / iostat / vmstat / sar 1s 取樣，client + db-host 雙邊（`*.txt` + `*-db.txt`） |
| Gate 雙閘 | 無 | `isolation-db.txt` + `isolation-driver-verify.txt`，gate 通過才進 prepare |
| Suite marker | 無 | `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.suite.done` |
| TPCC_TS | 無 | `yyyyMMddTHHmmss+0800` 形式，整 suite 共用同一 ts |
| 平均口徑 | 單次 run 即定值 | tpmC / p50 / p95 / p99 全為 5-round mean，range/mean 看穩定性 |
| Latency aggregate | NO avg + NO P99 | NO p50 / p95 / p99（5-round mean）|
| 三 isolation 矩陣 | 僅 RC | RC + RR + Strict（YBDB 原生支援 SERIALIZABLE，須驗證 `yb_enable_read_committed_isolation` 與 strict 設定相容） |

> 重跑後此段刪除、所有 `🟡 legacy single-run` tag 移除、各段補齊 v4.7 結構，README 矩陣對應由 🟡 升為 ✅。
