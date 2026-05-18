# TiDB TPC-C Pipeline Log — tidb-tc1 / S-BASE

> 本檔僅保留目前 PoC v4.7 最新 VM baseline 與 K8s 對照資料；舊 VM / HAProxy 歷史段落已備份至 `pipeline-log-old.md`，避免與新流程結果混淆。

---

## vm-1node-rc — 2026-05-18（PoC v4.7 baseline，5 round × 5 min × 4 threads）

> **本段目的**：在 PoC v4.7 新框架（detached suite wrapper + 多輪平均 + isolation 雙閘）下重建 vm-1node RC 基準，取代 2026-05-07 單次 10 min 結果作為後續 rr/strict 與其他 DB 對標的可重現基線。

### 環境
- 節點：.32 (172.24.40.32) 單節點，PD + TiDB + TiKV 同主機部署，RF=1
- TiDB 版本：v8.5.2
- 部署工具：TiUP via ansible playbook `tidb-vm1.yml`（含 systemd drop-in `no-proxy.conf` 避免 gRPC 經 HTTP proxy）
- AUTO ANALYZE：**停用**（`SET GLOBAL tidb_enable_auto_analyze = OFF`）+ `tidb_txn_mode='pessimistic'`
- 連線入口：直連 172.24.40.32:4000
- 測試工具：go-tpc on .31（MySQL driver，`--conn-params transaction_isolation='READ-COMMITTED'&tidb_txn_mode='pessimistic'`）
- Warehouses：128
- Warmup：**20 min @ 64 threads**（取代舊版 5 min，理由：見 2026-05-17 warmup duration 觀察）
- Run：**每組 5 round × 5 min**（取代舊版單次 10 min，可得 round-to-round variance）
- Threads：16 / 32 / 64 / 128（共 4 組，每組 5 round，總 run 時長 2h41min）
- TPCC_TS：`20260518T154918+0800`
- 結果目錄：`vm-1node-rc/tidb-vm-1node-rc-20260518T154918+0800/`

### Suite 階段時序

| Phase | 起 | 訖 | 耗時 |
|-------|-----|------|------|
| gate (OS / chrony / disk / iso pre) | 15:59 | 15:59 | <1min |
| prepare (128W + check-all + analyze + explain) | 15:59 | 16:53 | 54min |
| gate-isolation (post-prepare active gate) | — | 16:54 | <1min |
| run (4 thread × 5 round + 20min warmup) | 16:54 | 19:35 | 2h41min |
| collect (DB log tail + config dump + env snapshot) | 19:35 | 19:35 | <1s |
| **total (suite)** | **15:49** | **19:35** | **3h46min** |

### Gate 結果
- `transaction_isolation = READ-COMMITTED, tidb_txn_mode = pessimistic`（prepare 前 + 後雙閘驗證一致）
- THP=`never`、`vm.swappiness=1`、`ulimit -n=65536`
- NTP drift：System time `0.000084s slow of NTP time`（遠低於 1ms 閾值）
- disk：sda3 已 growpart 至 100GB

### Prepare
- 時間：54m05s（128W）
- check-all 128 warehouse 全條件通過，無 error
- TiDB schema：`CLUSTERED PK`，CHARSET=utf8mb4，COLLATE=utf8mb4_bin

### Execute 結果（5 round 平均）

> （tpmC：越高越好；NO p99：越低越好；efficiency 遠超 100% 屬正常，原因見 vm-1node Execute 結果說明）
>
> `range/mean` = `(5 round 最大 tpmC - 最小 tpmC) / 5 round 平均 tpmC`，用來看同一併發水位的 round-to-round 波動；數值越低代表重現性越好。
>
> `efficiency mean` 為 5 round 的 go-tpc efficiency 平均值。TPC-C 標準模型中的 think time 是使用者看畫面、思考下一步的等待時間；keying time 是使用者輸入訂單、付款等資料的時間。本 PoC 取消這兩種人類操作停頓，worker 送完一筆交易後幾乎立刻送下一筆，讓資料庫持續滿載，因此 efficiency 遠超 100% 屬正常，不需另列異常原因。

| threads | tpmC mean | range/mean | tpmTotal mean | efficiency mean | NO p50 (ms) | NO p95 (ms) | NO p99 (ms) |
|---------|-----------|-----------|---------------|-----------------|------------|------------|------------|
| 16  | **9,677**  | 7.4%   | 21,546 | 587.9%   | 52    | 76    | 96   |
| 32  | 10,987 | **18.8%** ⚠️ | 24,396 | 667.4%   | 94    | 138   | 176  |
| 64  | 12,838 | 9.6%   | 28,481 | 779.9%   | 156   | 235   | 305  |
| 128 | **13,209** | 5.9%   | 29,305 | 802.4%   | 289   | 473   | 612  |

### Round-by-round tpmC（檢驗穩定性）

| Threads | r1 | r2 | r3 | r4 | r5 |
|---------|-----|-----|-----|-----|-----|
| 16  | 9377  | 10036 | 9468  | 9411  | 10094 |
| 32  | 10638 | 9702  | 11136 | 11769 | 11688 |
| 64  | 12349 | 13576 | 12464 | 12800 | 13001 |
| 128 | 13331 | 13240 | 13241 | 13508 | 12723 |

- **32 threads 變異最大**（range/mean 18.8%）：round-2 (9702) vs round-4 (11769) 差 21%；其他組均 ≤10%。
- 推測 32t 處於 cache hit / commit batching 的 transition zone，建議 rr/strict 重跑時將 WARMUP_SEC 從 1200 提至 1800 觀察是否收斂。

### vs vm-1node (2026-05-07, 10 min 單次) 對比

| threads | 2026-05-07 (10min×1) | 2026-05-18 (5min×5 avg) | 差異 | 解讀 |
|---------|---------------------|------------------------|------|------|
| 16  | 11,895 | 9,677  | **-18.6%** | 短 run 噪聲較大；舊版單次可能落在偏高側 |
| 32  | 12,767 | 10,987 | -13.9% | 同上，但 32t 變異尤其大（見上表）|
| 64  | 13,355 | 12,838 | -3.9%  | 接近，落在統計誤差內 |
| 128 | 13,079 | 13,209 | +1.0%  | 一致 |

**啟示**：高併發（64t/128t）穩定可重現；低併發（16t/32t）短 run 噪聲顯著，**多輪平均比單次更準確**，建議所有後續對標採 5 round × 5 min 為標準。

### Saturation 分析

```
threads:  16 ───── 32 ───── 64 ───── 128
tpmC:    9677    10987   12838    13209
                 +14%    +17%     +3%       ← 邊際收益崩潰
p99(ms):   96      176     305     612
                +84%    +73%    +101%       ← latency 翻倍
```

**結論**：vm-1node RC 的甜點在 **64 threads**。128 threads 只多 +3% throughput 換來 2x latency，已過飽和點。

### 觀察

- **tpmC 隨併發溫和成長至 64t**：9,677 → 10,987 → 12,838，scaling 還在線性區間。
- **64 → 128 邊際收益僅 +3%**：明確的飽和訊號；單節點 16GB RAM + 4 vCPU 的天花板在這個工作負載大約是 13k tpmC。
- **latency 在 64t 之後翻倍**：p99 305ms → 612ms，但都遠低於 1s，無 hang 風險。
- **效率比舊版略低**：efficiency 顯示 588-802%（舊版 723-811%），與 tpmC 一致；新方法多輪平均較保守。
- **memory 健康**：DB host 11Gi used / 15Gi total（73%），無 swap，block-cache 5GB + mem-quota 3GB 配置合適。

### 缺陷與限制 ⚠️

1. **無 DB-host 端 OS 監控**（嚴重）
   `mpstat / iostat / vmstat / sar` 全部跑在 **TPCC client `.31`**，CPU 88-93% idle 只能證明客戶端不是瓶頸，**無法**回答以下關鍵問題：
   - `.32` TiKV 是 CPU-bound 還是 IO-bound？
   - 128t 飽和真實成因是 commit batching、Raft replication、還是磁碟 fsync？
   - 32t round 間變異 18.8% 是否對應 `.32` 上 background compaction / GC 噪聲？

   **修法**：`run.sh` 已修：所有監控指令同時 ssh 採樣到 `.32`，輸出 `*-db.txt` 對照檔（見 commit）。

2. **`efficiency > 100%` 不可與 TPC-C 官網數字直接比**：go-tpc 不打 keying/think time，是本 PoC 內部對標的相對指標。

### 結論

vm-1node RC 在 PoC v4.7 框架下穩定可重現，**64 threads 為甜點，128 threads 已飽和**。本輪資料作為後續 `vm-1node-rr`、`vm-1node-strict`、以及 CRDB/YBDB 對標的 baseline。`run.sh` 已補上 DB-host 端監控；下輪測試可直接觀察 TiKV CPU / disk %util 並回答上述瓶頸歸因問題。

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
