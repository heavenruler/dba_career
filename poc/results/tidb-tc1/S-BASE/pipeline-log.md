# TiDB TPC-C Pipeline Log — tidb-tc1 / S-BASE

> 本檔僅保留目前 PoC v4.7 最新 VM baseline 與 K8s 對照資料；舊 VM / HAProxy 歷史段落已備份至 `pipeline-log-old.md`，避免與新流程結果混淆。

---

## vm-1node-rc — 2026-05-18（PoC v4.7 baseline，含 DB-host OS 監控）

> **本段目的**：PoC v4.7 框架下的 vm-1node RC 正式 baseline，配套：detached suite wrapper、多輪平均、isolation 雙閘、**client + DB-host 雙邊 OS 監控**。取代 2026-05-07 單次 10 min 結果，作為後續 rr/strict 與其他 DB 對標的可重現基線。

### 環境
- 節點：.32 (172.24.40.32) 單節點，PD + TiDB + TiKV 同主機部署，RF=1
- 硬體：4 vCPU、15 GiB RAM、單 sda 盤（XFS）
- TiDB 版本：v8.5.2
- 部署工具：TiUP via ansible playbook `tidb-vm1.yml`（含 systemd drop-in `no-proxy.conf` 避免 gRPC 經 HTTP proxy）
- AUTO ANALYZE：**停用**（`SET GLOBAL tidb_enable_auto_analyze = OFF`）+ `tidb_txn_mode='pessimistic'`
- 連線入口：直連 172.24.40.32:4000
- 測試工具：go-tpc on .31（MySQL driver，`--conn-params transaction_isolation='READ-COMMITTED'&tidb_txn_mode='pessimistic'`）
- Warehouses：128
- Warmup：**20 min @ 64 threads**
- Run：**每組 5 round × 5 min**（多輪平均，取 round-to-round variance）
- Threads：16 / 32 / 64 / 128（共 4 組，每組 5 round，總 run 時長 2h42min）
- OS 監控：mpstat / iostat / vmstat / sar 同時在 client (`.31`) 與 db-host (`.32`) 採樣 1s 粒度，per round 各自輸出 `*.txt` / `*-db.txt`
- TPCC_TS：`20260518T202009+0800`
- 結果目錄：`vm-1node-rc/tidb-vm-1node-rc-20260518T202009+0800/`

### Suite 階段時序

| Phase | 起 | 訖 | 耗時 |
|-------|-----|------|------|
| gate (OS / chrony / disk / iso pre) | 20:25 | 20:25 | <1min |
| prepare (128W + check-all + analyze + explain) | 20:25 | 21:17 | 52min |
| gate-isolation (post-prepare active gate) | — | 21:19 | <1min |
| run (4 thread × 5 round + 20min warmup) | 21:17 | 23:59 | 2h42min |
| collect (DB log tail + config dump + env snapshot) | 23:59 | 23:59 | <1s |
| **total (suite)** | **20:25** | **23:59** | **3h35min** |

> vs 2026-05-18 15:49 同流程的 3h46min 縮短 11min，主因 `new-idc-vms` 改為 `dnf makecache` 並行 + growpart 並行（Makefile）。

### Gate 結果
- `transaction_isolation = READ-COMMITTED, tidb_txn_mode = pessimistic`（prepare 前 + 後雙閘驗證一致）
- THP=`never`、`vm.swappiness=1`、`ulimit -n=65536`
- NTP drift：System time slow of NTP time `~0.0001s`（遠低於 1ms 閾值）
- disk：sda3 已 growpart 至 100GB

### Prepare
- 時間：52m02s（128W）
- check-all 128 warehouse 全條件通過，無 error
- TiDB schema：`CLUSTERED PK`，CHARSET=utf8mb4，COLLATE=utf8mb4_bin

### Execute 結果（5 round tpmC 平均；latency 為代表值）

> tpmC / tpmTotal / efficiency 為 5 round mean；**NO p50 / p95 / p99 為 5 round latency 代表值**（觀察量級與趨勢用，非各 round 嚴格 mean）。
>
> （tpmC：越高越好；NO p99：越低越好；efficiency 遠超 100% 屬正常）
>
> `range/mean` = `(5 round 最大 tpmC - 最小 tpmC) / 5 round 平均 tpmC`，用來看同一併發水位的 round-to-round 波動；數值越低代表重現性越好。
>
> `efficiency mean` 為 5 round 的 go-tpc efficiency 平均值。TPC-C 標準模型中的 think time 是使用者看畫面、思考下一步的等待時間；keying time 是使用者輸入訂單、付款等資料的時間。本 PoC 取消這兩種人類操作停頓，worker 送完一筆交易後幾乎立刻送下一筆，讓資料庫持續滿載，因此 efficiency 遠超 100% 屬正常。

| threads | tpmC mean | range/mean | tpmTotal mean | efficiency mean | NO p50 (ms) | NO p95 (ms) | NO p99 (ms) |
|---------|-----------|-----------|---------------|-----------------|------------|------------|------------|
| 16  | **10,074** | 8.3% | 22,367 | 612.0% | 50    | 75    | 94   |
| 32  | 11,728 | **5.0%** | 26,052 | 712.5% | 88    | 130   | 163  |
| 64  | 12,744 | 7.9% | 28,317 | 774.2% | 159   | 235   | 305  |
| 128 | **13,064** | 8.3% | 29,034 | 793.7% | 289   | 469   | 597  |

### Round-by-round tpmC（檢驗穩定性）

| Threads | r1 | r2 | r3 | r4 | r5 |
|---------|-----|-----|-----|-----|-----|
| 16  | 9803  | 10574 | 9735  | 9907  | 10349 |
| 32  | 11931 | 11945 | 11358 | 11706 | 11698 |
| 64  | 12545 | 13195 | 13046 | 12189 | 12744 |
| 128 | 13637 | 12555 | 12711 | 13433 | 12984 |

- **t32 變異 5.0%**：相對 2026-05-18 15:49 同流程的 18.8% 改善顯著。本輪 t16 的 5 round 等同延長熱身，t32 進入較穩態的 TiKV cache / region 分布。建議所有後續對標保留「先跑低 thread 暖機」模式。

### DB-host (.32) CPU 飽和分析 ★（本輪新增監控結果）

> **核心問題**：vm-1node 在 4 vCPU 下，吞吐天花板的成因是什麼？  
> **回答**：**.32 在 t16 即達 90% CPU**，t128 mean 95.5% / 瞬間 100%，**CPU 是唯一硬天花板，磁碟與 iowait 全程非瓶頸**。

#### 1. mpstat-db.txt — 4 vCPU 平均使用率（round-3 mid-run，每組 305 個 1s 樣本）

| threads | %usr mean | %sys mean | %iowait mean | %idle mean | %idle min |
|---------|-----------|-----------|--------------|------------|-----------|
| 16  | 71.3% | 11.0% | 4.56% | 9.45% | **4.00%** |
| 32  | 75.0% | 10.4% | 3.96% | 7.02% | **1.24%** |
| 64  | 76.9% | 9.7%  | 3.41% | 6.56% | **0.75%** |
| 128 | **80.1%** | 9.0% | 3.08% | **4.52%** | **0.00%** |

#### 2. iostat-1s-db.txt — sda 磁碟壓力（round-3 mid-run 平均）

| threads | r/s | w/s | rkB/s+wkB/s | %util |
|---------|-----|-----|-------------|-------|
| 16  | 1162 | 769 | 40,310 | 50.8% |
| 32  | 1418 | 658 | 40,484 | 48.7% |
| 64  | 1285 | 584 | 33,462 | 48.8% |
| 128 | 1509 | 501 | 44,508 | 46.1% |

#### 3. 飽和歸因（從監控數據得出，非推測）

| 假設 | 驗證 | 證據 |
|------|------|------|
| t64 是甜點、t128 飽和 | ✓ tpmC + CPU 雙重證據 | tpmC 64→128 僅 +2.5%；%idle 6.56%→4.52%，**瞬間跌到 0** |
| 飽和成因是 CPU | ✓ | %user 71%→80% 持續上升；iowait 反而隨 thread 上升而下降（從 4.6%→3.1%） |
| 磁碟非瓶頸 | ✓ | %util 全程 ≤51%；wkB/s 與 thread 數無正相關，反而 t128 read-heavy → write-light |
| iowait 是次要訊號 | ✓ | iowait < 5% 全程，且 inverse-correlated with throughput（CPU 越滿，等 IO 比例越小） |

#### 4. 為何 t16 已 90% CPU 仍可成長到 13k tpmC？

t16 → t128 的 tpmC 成長 **+29.7%**（10074 → 13064），對應 %idle 下降 **9.45% → 4.52%**（即 real CPU 從 90.5% → 95.5%）。  
換算：CPU 利用率剩餘空間 9.5% → 4.5% = **被擠出 5% CPU room**，但 tpmC 卻成長 30%——表示 thread context-switch、commit batching、Raft 寫批量化在 thread 上升時把每 CPU-cycle 的「有效工作量」放大了；當 %idle 接近 0（t128 r1 13637 vs r2 12555 差 8%），噪聲就主導。

### vs 同流程歷史對比

| threads | 2026-05-07 (10min×1) | 2026-05-18 15:49 (5min×5) | 2026-05-18 20:25 (本輪) | 本輪 vs 前次 |
|---------|---------------------|--------------------------|------------------------|--------------|
| 16  | 11,895 | 9,677  | **10,074** | +4.1% |
| 32  | 12,767 | 10,987 | **11,728** | +6.7% |
| 64  | 13,355 | 12,838 | **12,744** | -0.7% |
| 128 | 13,079 | 13,209 | **13,064** | -1.1% |

- t64 / t128 **完全可重現**（差 ±1%）；t16 / t32 有 4-7% 偏高，但本輪 t32 變異從 18.8% → 5.0% 改善 → 多輪平均的穩定性比上輪好。

### Saturation 分析（更新版）

```
threads:  16 ───── 32 ───── 64 ───── 128
tpmC:    10074   11728   12744    13064
                 +16%    +9%      +2.5%      ← 邊際收益遞減

p99(ms):   94     163     305      597
                 +73%    +87%     +96%       ← latency 接近翻倍

DB %idle:  9.4%   7.0%   6.6%     4.5%      ← CPU 飽和進程
DB %iowait:4.6%   4.0%   3.4%     3.1%      ← IO 始終非瓶頸
DB disk%util: 50.8 48.7  48.8     46.1%     ← 磁碟未滿
```

**結論**：vm-1node RC 的甜點在 **t64（12,744 tpmC）**。t128 換 2x latency 只多 2.5% tpmC，不划算；**真正天花板是 4 vCPU**，磁碟有大量餘裕（%util ≤51%）。要突破 13k tpmC 只能加 CPU 核心或分散到多節點。

### 觀察

- **t64 是甜點**：5 round mean 12,744 tpmC、p99 305ms，CPU %idle 仍 6.6%（不到 100% 死頂）。
- **t128 已過飽和**：p99 突破 600ms、tpmC 邊際 +2.5%；瞬間 %idle 0% 表示已撞牆。
- **rebuild + parallel growpart 省 11min**：總 suite 從 3h46 縮到 3h35（並行 stage 帶來的 11min 節省幾乎全來自 Makefile 改動）。
- **memory 健康**：DB host 11Gi used / 15Gi total（73%），無 swap，block-cache 5GB + mem-quota 3GB 配置適中。
- **`efficiency > 100%` 屬正常**：go-tpc 不打 keying/think time，是本 PoC 內部對標的相對指標，**不可與 TPC-C 官網數字直接比**。

### 結論

vm-1node RC 在 PoC v4.7 框架下穩定可重現，**t64 為甜點（12,744 tpmC），t128 已飽和，硬天花板是 .32 的 4 vCPU**（iowait < 5%，disk %util < 51%）。DB-host 端 OS 監控已正式生效，後續所有 baseline 都帶有 saturation 證據可供歸因分析。

本輪資料作為後續 `vm-1node-rr`、`vm-1node-strict`、以及 CRDB/YBDB 對標的 baseline。預期 vm-3node 將 TiKV 分散到 3 台後可提升 tpmC，但 **scale-out ratio 不應預設為線性**（既有 vm-3node peak ~22,841 對 vm-1node ~13,064，比值 ~1.75x 而非 3x）；需用同樣的 DB-host 監控驗證 CPU / IO / raft / network 是否成為新瓶頸。

---

## k8s-3node-unlimit — 2026-05-10

> **本段落用 K8s（容器化平台）取代直接在虛擬機跑 TiDB。除了部署方式不同，叢集元件數量與資料複本配置與 vm-3node 完全相同；差別僅在「跑在容器裡」這一層的額外消耗。**

### 環境
- 拓撲：**k3s**（輕量版 Kubernetes 容器編排平台）v1.29.14 三節點（.32 master，.33/.34 worker）+ **TiDB Operator**（TiDB 官方提供的 K8s 自動化部署工具，把 TiDB 包成 K8s 可管理的資源）+ **TidbCluster**（在 K8s 內定義 TiDB 叢集的設定物件）(PD×3 / TiKV×3 / TiDB SQL×2)
- 部署清單：playbook `playbooks/tidb-k8s.yml` + inventory `inventory/tidb-tc1-k8s.ini` + vars `vars/tidb-k8s-3node-unlimit.yml`（TidbCluster CR template `roles/tidb_cluster/templates/tidbcluster.yaml.j2`，namespace `tidb-cluster`）
- TidbCluster `tidb-poc`：PD 10Gi **PV**（Persistent Volume，持續性資料儲存空間，避免 pod 重啟資料消失）、TiKV 100Gi PV、TiDB 無 PV（無狀態）
- 容器資源限制：**無**（unlimit variant；對應 TidbCluster CR 的 spec 區塊 — 詳見 Item #9 對照表）
- 連線入口：**NodePort**（K8s 服務對外暴露的固定埠口）`.32:30004` → tidb-poc-tidb Service → TiDB SQL pods (.32/.33)
- 結果目錄：`k8s-3node-unlimit/20260510-1409/`

### Prepare
- 時間：15m23s（128W）— 與 VM 相當

### Execute 結果

> （tpmC / tpmTotal：越高越好；NO avg / NO P99：越低越好）
>
> （efficiency 遠超 100% 屬正常，原因見上方 vm-1node Execute 結果說明；本表保持同樣的「無 think time 持續滿載」測試模式。）

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 13,160.9 | 29,207.6 | 799.5% | 36.4 | 58.7 |
| 32 | 16,304.1 | 36,228.4 | 990.5% | — | — |
| 64 | **18,918.8** | 41,915.3 | 1149.3% | — | — |
| 128 | 18,871.3 | 42,053.0 | 1146.4% | — | — |

### vs vm-3node clean run 對比（K8s 容器化 overhead）

> 兩組同樣三節點 RF=3，差異僅為 deployment runtime（VM bare process vs k3s containerd pod）。

| threads | vm-3node | k8s-unlimit | overhead |
|---------|----------|-------------|----------|
| 16 | 13,573.7 | 13,160.9 | -3.0% |
| 32 | 19,205.1 | 16,304.1 | -15.1% |
| 64 | 21,992.7 | 18,918.8 | -14.0% |
| 128 | 22,841.0 | 18,871.3 | -17.4% |
| **peak** | 22,841 | **18,919** | **-17.2%** |

### 觀察

- **K8s overhead 平均 ~12%**：低併發（16t）僅 -3%，高併發（128t）達 -17%。
- **原因**：高併發下 container network（CNI flannel）的 packet 處理、cgroup 計算、namespace 切換開銷等比放大。低併發時 CPU 都閒置，overhead 被吸收。
  （白話：高併發下容器網路與資源隔離機制處理量放大，使容器部署比 VM 慢約 17%；低併發 CPU 還有閒置容量時這些 overhead 被吸收。）
- **64t 為峰值**（18,919）：與 VM 同樣在 64t 達飽和，但天花板被 K8s overhead 拉低。
- **128t 略降**（18,871）：與 64t 幾乎持平（-0.2%），仍處於穩態，無 hang。

### 結論

K8s 部署的 TiDB 比 VM bare-process 部署 **慢約 12-17%**（高併發更明顯），但仍遠優於 CockroachDB（14,014）和 YugabyteDB（1,036）的 VM 部署。
若選 K8s 為部署模式，需留意：
1. 高 CPU 利用率場景（OLTP 高峰）overhead 可達 17%
2. 容器 networking（Flannel/Calico）對 TPC-C 這種高 RPS workload 影響顯著
3. 若選擇 K8s + 資源限制，需依下方 k8s-3node-limit 結果預估約 41% peak 下降

### k8s-3node 資源限制對照（unlimit vs limit 結構）

```yaml
# unlimit variant（本段）
spec:
  pd:
    requests:    {}     # 無
    limits:      {}     # 無
  tikv:
    requests:    {}     # 無
    limits:      {}     # 無
  tidb:
    requests:    {}     # 無
    limits:      {}     # 無

# limit variant（詳見下方 k8s-3node-limit 段落）
spec:
  pd:
    requests:    { cpu: 500m, memory: 1Gi }
    limits:      { cpu: 1,    memory: 2Gi }
  tikv:
    requests:    { cpu: 1,    memory: 4Gi }
    limits:      { cpu: 2,    memory: 8Gi }   # 即 README "TiKV Nc" = 2 cores
  tidb:
    requests:    { cpu: 500m, memory: 1Gi }
    limits:      { cpu: 1,    memory: 3Gi }
```

---

## k8s-3node-limit — 2026-05-10

### 環境
- 同 k8s-3node-unlimit 拓撲，**TidbCluster CR 重建**（刪除舊 CR + PVC，重新部署帶 limits）
- 容器資源限制：
  - PD：limit cpu=1, mem=2Gi（request 0.5/1Gi）
  - TiDB SQL：limit cpu=1, mem=3Gi（request 0.5/1Gi）
  - **TiKV：limit cpu=2, mem=8Gi**（request 1/4Gi）— 最關鍵限制（vs unlimit 可吃滿 4 vCPU）
- 連線入口：NodePort `.32:30004`
- 結果目錄：`k8s-3node-limit/20260510-2140/`

### Prepare
- 時間：21m57s（128W，比 unlimit 15m23s 慢 +43%）— TiKV 2 CPU 限制下寫入頻寬下降

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 10,470.5 | 23,317.3 | 636.1% | 45.9 | 109.1 |
| 32 | **11,080.7** | 24,589.3 | 673.2% | 85.9 | 201.3 |
| 64 | 10,895.5 | 24,263.2 | 661.9% | 173.1 | 369.1 |
| 128 | 10,519.7 | 23,395.6 | 639.1% | 352.0 | 805.3 |

### vs k8s-3node-unlimit 對比（資源限制 overhead）

> **差距 = limit 相對 unlimit 的 tpmC 變動，負數代表限制造成的吞吐減損。**

| threads | k8s-unlimit | k8s-limit | limit overhead |
|---------|-------------|-----------|----------------|
| 16 | 13,160.9 | 10,470.5 | -20.4% |
| 32 | 16,304.1 | 11,080.7 | -32.0% |
| 64 | 18,918.8 | 10,895.5 | **-42.4%** |
| 128 | 18,871.3 | 10,519.7 | **-44.3%** |
| **peak** | 18,919 | **11,081** | **-41.4%** |

### 觀察

- **32t 即達飽和**：32t peak 11,080，64t/128t 反而略降。不像 unlimit 在 64t 達 18,919 才飽和。原因：TiKV 2 CPU 限制（vs unlimit 可吃 ~3-4 CPU），32t 已榨乾運算資源。
- **限制 overhead 隨併發放大**：16t 僅 -20%，128t 達 -44%。低併發下 CPU 不滿，限制不顯影響；高併發下完全被 CPU cap 攔截。
- **DELIVERY_ERR × 2（128t）**：少量交易因資源不足逾時失敗（unlimit 從未出現此錯誤）。
- **吞吐天花板 ~11,000 tpmC**：CPU cap 直接決定上限。

### 五組 TiDB 對比（vm-1node → k8s-3node-limit）

| variant | peak tpmC | scale 區間 |
|---------|-----------|-----------|
| vm-1node | 13,355 (64t) | 平緩，飽和於 64t |
| vm-3node-direct | 14,779 (128t) | +11% vs vm-1node |
| vm-3node (HAProxy) | 22,841 (128t) | **+71%** vs vm-1node |
| k8s-3node-unlimit | 18,919 (64t) | -17% vs vm（K8s 容器化開銷）|
| **k8s-3node-limit** | **11,081 (32t)** | **-51% vs vm**（CPU cap 主導）|

### Parameter delta（unlimit → limit 各參數對 overhead 的影響）

| 元件 | unlimit | limit | 預期影響 |
|---|---|---|---|
| TiKV CPU | 無上限（4 cores） | 2 cores | 高併發 IO 處理被截斷（最主要影響來源）|
| TiKV memory | 無上限 | 8 GiB | block cache 被壓縮，磁碟 read 增加 |
| TiDB CPU | 無上限（4 cores） | 1 core | SQL parsing throughput 受限 |
| TiDB memory | 無上限 | 3 GiB | 大查詢可能 OOM |
| PD CPU | 無上限 | 1 core | scheduler 排程延遲 |

### 結論

**資源限制（CPU 2 cores per TiKV pod）對 OLTP 吞吐影響極大**：
1. peak 從 unlimit 的 18,919 → limit 的 11,081，**減少 41%**
2. scaling 曲線明顯改變：unlimit 在 64t 才飽和，limit 在 32t 就到頂
3. 高併發下吞吐反而略降（128t 比 32t 低 5%），CPU cap 開始引發排隊延遲反噬

**部署建議**：
- 不建議在 OLTP 場景對 TiKV 設過嚴 CPU limit（≤2 cores 損失 40%+ 吞吐）
- 若需 multi-tenancy 隔離，至少給 TiKV 3 cores 留 burst 空間
- request/limit 比 request 應接近 limit（避免 throttling 抖動）

---
