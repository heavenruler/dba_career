# TiDB TPC-C Pipeline Log — tidb-tc1 / S-BASE

> 本檔僅保留目前 PoC v4.7 最新 VM baseline 與 K8s 對照資料；舊 VM / HAProxy 歷史段落已備份至 `pipeline-log-old.md`，避免與新流程結果混淆。

---

## TL;DR — vm-1node 兩 isolation 矩陣完成（2026-05-18/19）

**核心結論**：TiDB v8.5.2 在 4 vCPU + single XFS disk 硬體下，**pessimistic mode 全跑零 error、RR 反而比 RC 快 6%**；strict 在 TiDB 等價於 RR（不支援原生 SERIALIZABLE），跳過不重跑。

### tpmC 排行（5 round mean）

| 排名 | iso | tpmC | 併發 | DB-host 瓶頸 | err count / round | error rate | N |
|---|---|---:|:---:|---|---:|---:|:---:|
| 🥇 | **rr (pessimistic)** | **13,874** | t128 | CPU-bound（%user 80.8% / %idle 4.5%）| **0** | 0.0% | 1 |
| 🥈 | rc (pessimistic) | 13,064 | t128 | CPU-bound（%user 79.6% / %idle 4.5%） | **0** | 0.0% | 1 |
| — | strict | — | — | 等價於 rr，略過 | — | — | — |

### 三大發現

1. **RR > RC 反直覺**：TiDB pessimistic 下 RR 比 RC 快 +6.2% tpmC（t128: 13,874 vs 13,064）、p99 低（503 vs 597ms）。原因為 RC 採 per-statement snapshot ts、每句 SQL 多一次 PD 取 ts + region cache 重整；RR per-txn snapshot 一次定奪、後續 SQL 全部復用，**RPC 與 metadata 開銷淨減**。
2. **零 error 全程**：兩 iso × 4 thread × 5 round = 40 個 run 中 `NEW_ORDER_ERR = 0`、`execute run failed = 0`。pessimistic 模式拿鎖時 advance for-update-ts，hot row（district）並發只是排隊等鎖，不會 retry。對比 CockroachDB RR 同硬體 412 errors / 20 rounds。
3. **CPU-bound 而非 IO-bound**：%iowait 全程 < 5%、sda %util ≤ 51%——磁碟非瓶頸。t16 起 CPU 已達 92.5%，t128 mean 約 95.5%、瞬間接近 100%。**加 thread 只能擠光剩餘 CPU 餘裕，不能突破天花板**。對比 CockroachDB rc IO-bound（%iowait 18%）、CockroachDB rr retry-bound（DB %idle 46%）。

### 業務啟示

- TiDB 同硬體下 **RR 是當前最佳組合**（更高吞吐 + 更低 latency + 零 error + 強於 RC 的 isolation 保證）
- TiDB 不支援原生 SERIALIZABLE，strict 在工具鏈裡只能等價於 RR；跨家 strict 對比時須注意這點不能直比 CockroachDB / YugabyteDB 的 SSI
- 同硬體下 **TiDB 全面領先 CockroachDB**：rc +48% vs CockroachDB rc、rr +266% vs CockroachDB rr、rr +33% vs CockroachDB strict（CockroachDB 最強配置）
- 下一步 vm-3node 預期 TiKV 分散 → tpmC 上升，但**比值非線性**（既往觀察：vm-3node 22,841 vs vm-1node 13,064 = 1.75x，非 3x）

### 完整資料目錄

| iso | TPCC_TS | 5-round mean t128 | err / 20 rounds | 詳細段落 |
|-----|---------|-------------------|-----------------|----------|
| rc | 20260518T202009+0800 | 13,064 | 0 | [§ vm-1node-rc](#vm-1node-rc--2026-05-18poc-v47-baseline含-db-host-os-監控) |
| rr | 20260519T001949+0800 | 13,874 | 0 | [§ vm-1node-rr](#vm-1node-rr--2026-05-19poc-v47含-db-host-os-監控) |
| strict | — (alias to rr) | — | — | [§ vm-1node-strict 略過原因](#vm-1node-strict--略過tidb-不支援-serializable) |

vm-3node 5-cell（1s1r / 1s3r / 3s1r / 3s3r / haproxy-3s3r × RC）已於 2026-05-29 ~ 2026-06-01 完成（5-round mean、N=1；含 Fix #9-#12 / D10 系列修補）；詳見下方 `vm-3node 系列` 與 [2026-05-31 schedule-limit 0→4 分析](../../dispatch-records/2026-05-31-tidb-schedule-limit-0-vs-4.md) + [2026-06-01 HAProxy vs direct 分析](../../dispatch-records/2026-06-01-tidb-haproxy-vs-direct-3s3r-l4r4.md)。

下一步：三家 `haproxy-3s3r` 補 N=3 → 升級為對外可引用 baseline；K8s 對照組待重跑；跨區規劃見 [`1_MeetingMinutes/0602.md §10`](../../../1_MeetingMinutes/0602.md)。

---

## 取數來源（Data trace）

所有 tpmC / latency / error rate / DB-host 飽和指標皆可從 artifact 目錄逐步重現，避免「pipeline-log 數字 vs 實際 stdout」漂移。

| 數據類型 | 來源檔案 | 取數工具 / 計算口徑 |
|---------|----------|---------------------|
| `tpmC mean` / `NO p50/p95/p99 mean` / `tpmTotal mean` / `efficiency mean` | `runs/threads-<N>/round-<R>/go-tpc-stdout.txt`（5 round per thread group）| [`tests/common/summary-from-stdout.py`](../../../tests/common/summary-from-stdout.py) 解析 `[Summary] NEW_ORDER` 與 `tpmC: ...` 行，輸出 `summary.json`；本檔取 `thread_results.<N>.{tpmC_mean, NEW_ORDER.p50_mean_ms, ...}` 為 5-round mean |
| `range/mean` 穩定度 | 同上 | `(max(tpmC_per_round) - min(tpmC_per_round)) / tpmC_mean × 100%` |
| `error rate (all_txn)` | 同上 `[Summary] *_ERR` 行（5 transaction types） | `Σ *_ERR count / Σ (* + *_ERR) count × 100%`（per F-001 audit 口徑）；落地至 `summary.json.thread_results.<N>.all_txn.error_rate_pct` |
| `NEW_ORDER_ERR / round` 統計 | 同上 | `summary.json.thread_results.<N>.NEW_ORDER.error_count / 5 round` |
| DB-host 飽和指標（%user / %sys / %iowait / %idle / disk %util）| `runs/threads-<N>/round-<R>/{mpstat-db.txt, iostat-1s-db.txt}` | round-3 mid-run 1s 取樣，跨 round 計算 `mean(line[%idle], %iowait)`；指令範例：`awk '$2=="all" {usr+=$3; ...} END{...}'` |
| isolation gate 雙閘證據 | `gate/isolation-db.txt` + `gate/isolation-driver-verify.txt` + `.gate-isolation.done`（JSON marker）| `mysql -e "SET SESSION ...; BEGIN; SELECT @@transaction_isolation, @@tidb_txn_mode; COMMIT"` |
| TiDB cluster config dump | `db-config/effective-config.txt` + `db-config/cluster-settings.txt` | collect 階段 `db-config-dump.sh` 跑 `SHOW GLOBAL VARIABLES` + `tiup cluster show-config tpcc-tidb` |
| Round 結構完整性驗證 | `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.suite.done` | 6 個 marker 全在 = phase chain 完整 |

重新計算 vm-1node-rr t128 5-round mean 範例：

```bash
jq '.thread_results."128".tpmC_mean,
    .thread_results."128".NEW_ORDER.p99_mean_ms,
    .thread_results."128".all_txn.error_rate_pct' \
  results/tidb-tc1/S-BASE/vm-1node-rr/tidb-vm-1node-rr-20260519T001949+0800/summary.json
```

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

### Execute 結果（5 round tpmC 平均；latency 為 5 round mean）

> tpmC / tpmTotal / efficiency 為 5 round mean；**NO p50 / p95 / p99 亦為 5 round latency mean**（已驗算對齊：每組 t16/32/64/128 的 p99 mean 與表格值差 ≤ 0.5ms，符合四捨五入誤差）。
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

本輪資料作為後續 `vm-1node-rr`、`vm-1node-strict`、以及 CockroachDB/YugabyteDB 對標的 baseline。預期 vm-3node 將 TiKV 分散到 3 台後可提升 tpmC，但 **scale-out ratio 不應預設為線性**（既有 vm-3node peak ~22,841 對 vm-1node ~13,064，比值 ~1.75x 而非 3x）；需用同樣的 DB-host 監控驗證 CPU / IO / raft / network 是否成為新瓶頸。

---

## vm-1node-rr — 2026-05-19（PoC v4.7，含 DB-host OS 監控）

> **本段目的**：與同期 `vm-1node-rc` 對標，驗證 isolation 從 `READ-COMMITTED` 切換到 `REPEATABLE-READ` 對 TiDB pessimistic 模式 OLTP 吞吐 / 延遲的影響。

### 環境
- 與 `vm-1node-rc` 相同硬體 / TiDB v8.5.2 / 同 ansible playbook，唯一差異：**iso=rr**
- go-tpc conn-params：`transaction_isolation='REPEATABLE-READ'&tidb_txn_mode='pessimistic'`
- TPCC_TS：`20260519T001949+0800`
- 結果目錄：`vm-1node-rr/tidb-vm-1node-rr-20260519T001949+0800/`

### Suite 階段時序

| Phase | 起 | 訖 | 耗時 |
|-------|-----|------|------|
| gate | 00:24 | 00:24 | <1min |
| prepare | 00:24 | 01:18 | 54min |
| gate-isolation | — | 01:20 | <1min |
| run (4 thread × 5 round + 20min warmup) | 01:18 | 04:00 | 2h42min |
| collect | 04:00 | 04:00 | <1s |
| **total (suite)** | **00:24** | **04:00** | **3h36min** |

### Gate 結果
- `transaction_isolation = REPEATABLE-READ, tidb_txn_mode = pessimistic`（prepare 前 + 後雙閘驗證一致）
- 其他 OS gate（THP / swappiness / ulimit / NTP）同 vm-1node-rc

### Prepare
- 時間：54m05s（128W）
- check-all 128 warehouse 全條件通過
- schema 與 rc 完全相同

### Execute 結果（5 round tpmC 平均；latency 為 5 round mean）

> tpmC / tpmTotal / efficiency 為 5 round mean；**NO p50 / p95 / p99 亦為 5 round latency mean**。

| threads | tpmC mean | range/mean | tpmTotal mean | efficiency mean | NO p50 (ms) | NO p95 (ms) | NO p99 (ms) |
|---------|-----------|-----------|---------------|-----------------|------------|------------|------------|
| 16  | **11,196** | 16.8% ⚠️ | 24,914 | 680.2% | 42  | 61  | 80  |
| 32  | 12,831 | **3.4%** | 28,467 | 779.5% | 71  | 105 | 134 |
| 64  | 13,743 | 6.0%     | 30,560 | 834.9% | 122 | 193 | 246 |
| 128 | **13,874** | **2.8%** | 30,902 | 842.9% | 235 | 392 | 503 |

### Round-by-round tpmC

| Threads | r1 | r2 | r3 | r4 | r5 |
|---------|-----|-----|-----|-----|-----|
| 16  | 11041 | 12064 | 11040 | 11652 | **10183** |
| 32  | 12736 | 12694 | 13130 | 12722 | 12874 |
| 64  | 13506 | 14059 | 13910 | 13231 | 14010 |
| 128 | 14041 | 13652 | 13755 | 14012 | 13910 |

- **t16 r5 突降至 10183**：較 r2 高峰 12064 下降 -15.6%，導致 range/mean 16.8%。其他 thread 組變異 ≤6.0%。可能成因：RR snapshot 在低併發長時段易受 background compaction / region housekeeping 干擾；高併發下 worker 佔滿 CPU，背景活動被排擠到次要 schedule。

### DB-host (.32) CPU 飽和分析

| threads | %usr mean | %sys mean | %iowait mean | %idle mean | %idle min | disk %util |
|---------|-----------|-----------|--------------|------------|-----------|------------|
| 16  | 73.9% | 10.4% | 4.63% | 7.48% | **2.26%** | 50.4% |
| 32  | 76.1% | 9.9%  | 3.54% | 6.98% | 1.49% | 48.4% |
| 64  | 77.6% | 9.3%  | 3.40% | 6.28% | 1.00% | 46.6% |
| 128 | **80.8%** | 8.8% | 2.73% | **4.47%** | **0.25%** | 44.8% |

- t16 即 92.5% CPU 使用率（比 RC 90.5% 高 +2pp）；t128 mean 約 95.5%、瞬間接近 100%。
- iowait 全程 < 5%、disk %util ≤ 51%——磁碟非瓶頸，與 RC 結論一致。

### vs vm-1node-rc 對比 ★

> 同硬體 / 同 binary / 同 warmup / 同 5 round 平均，唯一變數 iso。

| threads | RC tpmC | RR tpmC | Δ tpmC | RC p99 (ms) | RR p99 (ms) | Δ p99 |
|---------|---------|---------|--------|-------------|-------------|-------|
| 16  | 10,074 | **11,196** | **+11.1%** | 94  | 80  | **-14.9%** |
| 32  | 11,728 | **12,831** | **+9.4%**  | 163 | 134 | -17.8% |
| 64  | 12,744 | **13,743** | **+7.8%**  | 305 | 246 | -19.3% |
| 128 | 13,064 | **13,874** | **+6.2%**  | 597 | 503 | -15.7% |

| threads | RC DB %idle | RR DB %idle | RC disk %util | RR disk %util |
|---------|-------------|-------------|---------------|---------------|
| 16  | 9.45% | 7.48% | 50.8% | 50.4% |
| 32  | 7.02% | 6.98% | 48.7% | 48.4% |
| 64  | 6.56% | 6.28% | 48.8% | 46.6% |
| 128 | 4.52% | 4.47% | 46.1% | 44.8% |

**RR 全面優於 RC：tpmC +6~11%、p99 -15~19%、CPU 使用率小幅升高（同 CPU 做更多有效工作）。**

### 為何 RR 反而比 RC 快？

直覺常認為 RR 比 RC 嚴格 → 應該更慢。本次數據反過來，可由 TiDB 的 pessimistic + RR 實作機制解釋：

1. **RC 每個 SQL 取新 snapshot** → 每筆 read 都需向 TiKV 取 timestamp、驗證 read consistency；snapshot 切換 + read lock 申請的小型 RPC 累積成 overhead。
2. **RR 整 txn 用同一 snapshot** → 只在 txn 開始時取一次 read ts，後續 SQL 直接讀同一視圖；少了 N-1 次 snapshot 切換。
3. **TPC-C NEW_ORDER / PAYMENT 是 multi-statement txn**：含多筆 SELECT + UPDATE，RR 的「省切換」收益會被放大；單 statement 工作負載差異會收斂。
4. **pessimistic mode 提供 write lock**：兩種 iso 下 write conflict 都用悲觀鎖等待，RR 沒有額外 write 衝突偵測 overhead。

> 此結論**僅對 TiDB pessimistic + go-tpc 無 think time 工作負載**成立。CockroachDB / YugabyteDB 採 optimistic MVCC，RR 與 RC 的關係可能反向（snapshot 維護成本與 retry 行為不同）。

### Saturation 分析

```
threads:  16 ───── 32 ───── 64 ───── 128
tpmC:    11196   12831   13743   13874
                 +15%    +7%     +1%       ← 邊際收益遞減（128 已飽和）

p99(ms):   80     134     246     503
                +68%    +83%    +104%      ← latency 近翻倍

DB %idle:  7.5%   7.0%   6.3%    4.5%     ← CPU 飽和進程，比 RC 同 thread 略高
```

**結論**：vm-1node RR 的甜點同樣在 **t64（13,743 tpmC，p99 246ms）**。t128 換 2x latency 只多 +1% tpmC，遠不划算。

### 觀察

- **t128 已過飽和**：tpmC 邊際 +1%、p99 翻倍、%idle 最低 0.25%，已接近撞牆——比 RC 更早飽和（RC t128 邊際還有 +2.5%）。
- **t16 變異大**（16.8%）：r5 突降造成；長 warm-up 仍無法完全消除 RR snapshot 在低併發下的 background 干擾。
- **t32/t128 變異 ≤3.4%**：高度可重現。
- **DB CPU 比 RC 略高 + tpmC 也較高**：證實 RR 在 TiDB pessimistic + 多 statement txn 下確實更 CPU-efficient，不是 throughput 換 latency。

### 結論

vm-1node RR 在 TiDB v8.5.2 pessimistic 模式下，tpmC 全面領先 RC 6-11%、p99 latency 領先 15-19%、CPU 使用率略高（同 CPU 做更多有效工作）。peak 13,874 tpmC @ t128，sweet spot 仍為 t64（13,743 tpmC、p99 246ms）。

**業務啟示**：若應用語意可接受 RR（NEW_ORDER 取 snapshot 即決定全程視圖），優先選 RR 而非 RC；同硬體下無痛獲得 +6-11% 吞吐與 -15-19% latency。若需嚴格 RC 語意（每 SQL 取新 snapshot），需接受相應的吞吐 / 延遲代價。

---

## vm-1node-strict — 略過（TiDB 不支援 SERIALIZABLE）

> 依 PoC-DESIGN §5.4 注意 2：**TiDB rr 與 strict 完全等價**。本輪 vm-1node-rr 已涵蓋同設定下的測試表現，strict 重跑無資訊增量，故略過；待 CockroachDB / YugabyteDB 等原生 SERIALIZABLE 的 DB 再做 strict 矩陣比較。

### 依據
- 官方文件：[Transaction Isolation Levels — TiDB Documentation](https://docs.pingcap.com/tidb/stable/transaction-isolation-levels/)
  - TiDB 支援的 transaction isolation：`READ-COMMITTED` 與 `REPEATABLE-READ`。
  - `SERIALIZABLE` 需先設 [`tidb_skip_isolation_level_check`](https://docs.pingcap.com/tidb/stable/system-variables/#tidb_skip_isolation_level_check)（避開設定錯誤），但底層**仍以 REPEATABLE-READ 行為執行**，不會真正做 SSI / SI。
- 本 PoC 程式碼決策：`tests/common/lib/common.sh` 將 `tidb:strict` alias 到 `tidb:rr`：
  ```bash
  tidb:rr|tidb:strict)
    echo "transaction_isolation=%27REPEATABLE-READ%27&tidb_txn_mode=%27pessimistic%27" ;;
  ```

### 跨家 strict 對標時的正確視角

| DB | strict 實際隔離 | 原生支援 SERIALIZABLE |
|----|----------------|---------------------|
| TiDB | REPEATABLE-READ (alias)   | ❌（設定後退回 RR）|
| CockroachDB | SERIALIZABLE (SSI 預設) | ✓ |
| YugabyteDB | SERIALIZABLE             | ✓（需 `yb_enable_read_committed_isolation` 配套）|

→ strict 矩陣比較時，**TiDB strict 不可與 CockroachDB / YugabyteDB strict 直比**；以 `vm-1node-rr` 的數據作為 TiDB 在 strictest native isolation 下的代表即可。

---

## vm-3node 系列（4 sub-topology × RC，PoC-DESIGN §6.3.2）

> 本段為 TiDB v8.5.2 在 vm-3node 拓樸 / `READ COMMITTED` 隔離級下的 4 個 sub-topology baseline 規劃。資料填寫前以 `dry-run` anchor 確認 cluster topology / RF / iso preset 與設計一致，再由人工放行 `EXECUTE=1` 進入 prepare/run/collect。

### 共同元件分配（3 顆 VM）

```
            client (.31)
              │  go-tpc → :4000 (TiDB)
              ▼
   ┌──────────┴──────────┐
   │     172.24.40.32    │  ← client 入口 / TiDB stateless entry
   │  PD(2379) + TiKV    │
   │  + TiDB(4000)       │
   └─────────┬───────────┘
             │ Raft (PD quorum, TiKV multi-Raft)
   ┌─────────┴────────────────────────┐
   │                                  │
┌──┴──────────────┐         ┌─────────┴────────┐
│  172.24.40.33   │         │   172.24.40.34   │
│  PD + TiKV      │         │   PD + TiKV      │
└─────────────────┘         └──────────────────┘
```

PD×3 滿足 Raft quorum；TiKV×3 滿足 RF=3 placement（§4.4）；TiDB×1 為 stateless SQL 層，client 統一 .32:4000 進入。

### vm-3node-1s1r-rc

> 1 shard × 1 replica：3-node cluster 但所有 region 鎖 RF=1、單 region。對照 vm-1node-rc 量化「cluster framework + remote coord」純成本。

#### 拓樸示意

```
┌─ PD quorum (3) ────────────────────────────────────┐
│ .32 PD ⇄ .33 PD ⇄ .34 PD  (replication.max-replicas=1)
└────────────────────────────────────────────────────┘
                   ▲ schedule / lease
TiKV stores
.32 [region1-leader]   .33 (idle)   .34 (idle)
                     └─ RF=1 只在 1 store
```

#### 關鍵 DB 設定

| 維度 | 設定 | 來源 |
|---|---|---|
| `pd: replication.max-replicas` | `1` | `tidb-vm3.yml` (`tidb_replicas`) |
| `tikv: coprocessor.region-split-size` | `128GB` | 防 size split（§7.5.1）|
| Region split policy | 無 SPLIT；natural 1 region/table | `prepare.sh` 略過 SPLIT |
| `tidb_txn_mode` | `pessimistic` | RC 必要前提 |
| `tidb_enable_auto_analyze` | `OFF` | benchmark control |
| conn-params (RC) | `transaction_isolation='READ-COMMITTED'&tidb_txn_mode='pessimistic'` | §7.1 |

#### Dry-run 預期

- `cluster-topology.txt` ≥ 3 node Up（PD + TiKV）
- `replication-factor.txt` = `1`
- `iso-preset.txt` = `READ-COMMITTED`
- `cluster-health.txt` = `SELECT 1` 回 1
- 全項通過 → `.dry-run.done` `all_pass: true`

#### Execute 結果（2026-05-29，TS=20260529T132940+0800）

5-round mean tpmC：

| threads | tpmC mean | range/mean | NO p99 mean (ms) |
|--------:|----------:|-----------:|-----------------:|
| 16  | 11,682 | 18.9% ⚠️ | 83 |
| 32  | 14,993 | 25.5% ⚠️ | 138 |
| 64  | 18,516 | 21.2% ⚠️ | 242 |
| 128 | **19,654** | 7.0% | 456（代表點）|

代表點 = **t=128 / 19,654 tpmC / NO_p99 = 456 ms**（5-round mean，0 error）。對照 vm-1node-rc（**13,064 tpmC @ t=128**）→ **+50.4% throughput**，量化 TiDB 3-node + RF=1 cluster framework 對單節點 baseline 的 scale-out 紅利（RF=1 無 quorum 寫入，3 TiKV stores 仍能分散 region leader 工作）。t=16/32/64 range/mean 18.9-25.5% 偏高，符合 1s1r RF=1 下 region leader 路由波動的預期；t=128 收斂至 7% 為 worker queue 填滿後的穩態。Source: [`tidb-vm-3node-1s1r-rc-20260529T132940+0800/summary.json`](./vm-3node-1s1r-rc/tidb-vm-3node-1s1r-rc-20260529T132940+0800/summary.json)。

### vm-3node-1s3r-rc

> 1 shard × 3 replica：Raft 3-replica leader+2 follower 寫入成本。對照 1s1r 量化「Raft replication 成本」。

#### 拓樸示意

```
┌─ PD quorum (3) ────────────────────────────────────┐
│ .32 PD ⇄ .33 PD ⇄ .34 PD  (replication.max-replicas=3)
└────────────────────────────────────────────────────┘
                   ▲
TiKV stores
.32 [region1-leader]
.33 [region1-follower] ←─┐ Raft majority commit
.34 [region1-follower] ←─┘
```

#### 關鍵 DB 設定

| 維度 | 設定 |
|---|---|
| `pd: replication.max-replicas` | `3` |
| Region split policy | 無 SPLIT；natural 1 region/table |
| 其餘 | 同 1s1r |

#### Dry-run 預期

- `replication-factor.txt` = `3`
- 其餘同 1s1r。

#### Execute 結果（兩 variant：PD schedule-limit 0→4）

> 本 sub-topology 因 vm-3node playbook 沿用 vm-1node 的 PD config（`replica-schedule-limit=0` + `leader-schedule-limit=0`），baseline 跑出來實際 RF=1（假 RF=3）；2026-05-30 Fix #11 + D10 修正後重跑。兩組均 N=1。

##### vm-3node-1s3r-rc-pd-sched-l0r0/（baseline，broken — `replica=0, leader=0`）

| TS | 來源 |
|---|---|
| `20260529T170933+0800` | `vm-3node-1s3r-rc-pd-sched-l0r0/tidb-vm-3node-1s3r-rc-20260529T170933+0800/` |

tpmC 5-round mean：t=16 = 10,856 ／ t=32 = 12,532 ／ t=64 = 13,823 ／ t=128 = **14,130**。
NEW_ORDER p99 mean：t=128 = 567 ms。
實際 region peer count = 1（dry-run 階段 actual peer gate 未啟用，未捕捉）。

##### vm-3node-1s3r-rc-pd-sched-l4r4/（fixed — `replica=4, leader=4`，Fix #11 + D10）

| TS | 來源 |
|---|---|
| `20260530T162428+0800` | `vm-3node-1s3r-rc-pd-sched-l4r4/tidb-vm-3node-1s3r-rc-20260530T162428+0800/` |

tpmC 5-round mean：t=16 = 11,199 ／ t=32 = 14,765 ／ t=64 = 15,309 ／ t=128 = **16,336**。
NEW_ORDER p99 mean：t=128 = 527 ms。
實際 region peer count = 3（dry-run `actual-rf-peer-min/-max=3`，9 region 全 RF=3）。
跨 cell 對照 → `dispatch-records/2026-05-31-tidb-schedule-limit-0-vs-4.md`。

### vm-3node-3s1r-rc

> 3 shard × 1 replica：3 region 分散到 3 node，每 region RF=1。對照 1s1r 量化「sharding 對 OLTP 效應」。

#### 拓樸示意

```
┌─ PD quorum (3) ────────────────────────────────────┐
│ .32 PD ⇄ .33 PD ⇄ .34 PD  (replication.max-replicas=1)
└────────────────────────────────────────────────────┘
TiKV stores                                      9 張 TPC-C 表，每張 SPLIT 成 3 region
.32 [t.region-A leader]  .33 [t.region-B leader]  .34 [t.region-C leader]
     └ RF=1                 └ RF=1                 └ RF=1
```

#### 關鍵 DB 設定

| 維度 | 設定 |
|---|---|
| `pd: replication.max-replicas` | `1` |
| Region split policy | prepare 階段對 9 張表執行 `SPLIT TABLE ... INDEX PRIMARY ... REGIONS 3` |
| Hard gate | `information_schema.tikv_region_status` 9 表 `IS_INDEX=0` 計數 = 3 |
| 其餘 | 同 1s1r |

#### Dry-run 預期

- `replication-factor.txt` = `1`（dry-run 階段 tpcc DB 尚未建，無 shard SPLIT 紀錄；hard gate 由 prepare 階段執行）
- 其餘同 1s1r。

#### Execute 結果（2026-05-30，TS=20260530T023238+0800）

5-round mean tpmC：

| threads | tpmC mean | range/mean | NO p99 mean (ms) |
|--------:|----------:|-----------:|-----------------:|
| 16 | 11,052 | 20.5% ⚠️ | 92 |
| 32 | 14,890 | 15.1% | 143 |
| 64 | **16,580** | 15.6% | 270（sweet spot）|
| 128 | 15,842 | 23.8% ⚠️ | 597 |

代表點 = **t=64 / 16,580 tpmC / NO_p99 = 270 ms**（mean tpmC 最大且不撞極端 latency 之平衡點；t=128 latency 翻倍且 range/mean 飆 23.8%）。對照 vm-3node-1s1r（同 RF=1）→ **−15.6% throughput**（t=128 對比），量化 TiDB 在 RF=1 下純 sharding 成本（low 於 YugabyteDB 同位 −12.7%）。t=64 range/mean 15.6% 偏高，可能與 region leader 分布有關。

### vm-3node-3s3r-rc

> 3 shard × 3 replica：完整 sharded + replicated cluster。對照 1s3r 量化「sharding 在 RF=3 下的攤平效益」；與 3s1r 比 → replication overhead in sharded cluster。

#### 拓樸示意

```
┌─ PD quorum (3) ────────────────────────────────────┐
│ .32 PD ⇄ .33 PD ⇄ .34 PD  (replication.max-replicas=3)
└────────────────────────────────────────────────────┘
TiKV stores（每節點持有所有 region 的某 replica）
.32 [A-leader / B-follower / C-follower]
.33 [A-follower / B-leader / C-follower]
.34 [A-follower / B-follower / C-leader]
```

#### 關鍵 DB 設定

| 維度 | 設定 |
|---|---|
| `pd: replication.max-replicas` | `3` |
| Region split policy | prepare 階段對 9 張表 `SPLIT ... REGIONS 3` |
| 其餘 | 同 3s1r |

#### Dry-run 預期

- `replication-factor.txt` = `3`
- 其餘同 1s1r。

#### Execute 結果（兩 variant：PD schedule-limit 0→4）

> 同 1s3r 議題：baseline 因 `replica-schedule-limit=0` 退化為實際 RF=1；2026-05-30/31 Fix #11 + D10 修正後重跑。兩組均 N=1。

##### vm-3node-3s3r-rc-pd-sched-l0r0/（baseline，broken — `replica=0, leader=0`）

| TS | 來源 |
|---|---|
| `20260530T061352+0800` | `vm-3node-3s3r-rc-pd-sched-l0r0/tidb-vm-3node-3s3r-rc-20260530T061352+0800/` |

tpmC 5-round mean：t=16 = 14,041 ／ t=32 = 18,130 ／ t=64 = 19,997 ／ t=128 = **20,455**。
NEW_ORDER p99 mean：t=128 = 423 ms。
最終 leader 分佈：**27 / 0 / 0**（單 store 集中）；實際 region peer count = 1（假 RF=3）。

> ⚠️ **本 cell 的 tpmC 不可作為 TiDB 3 節點 RF=3 真實表現參考**。所有 raft work 與 region leader 都集中於單一 store，本質上是「3 stores 中只有 1 個在工作」的退化拓樸；高 tpmC 反映「無 raft replication overhead + 單 store local I/O」的人工捷徑，不是真 RF=3 throughput。

##### vm-3node-3s3r-rc-pd-sched-l4r4/（fixed — `replica=4, leader=4`，Fix #11 + D10）

| TS | 來源 |
|---|---|
| `20260531T085812+0800` | `vm-3node-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-3s3r-rc-20260531T085812+0800/` |

tpmC 5-round mean：t=16 = 11,034 ／ t=32 = 13,111 ／ t=64 = 14,733 ／ t=128 = **15,082**。
NEW_ORDER p99 mean：t=128 = 590 ms。
最終 leader 分佈：**4 / 15 / 10**（雖未達 ±20% 容差，但已從 27/0/0 顯著收斂）；實際 region peer count = 3。

跨 cell 對照（含 disk I/O 證據 RF=3 真生效）→ `dispatch-records/2026-05-31-tidb-schedule-limit-0-vs-4.md`。

### vm-3node-haproxy-3s3r-rc

> 3 shard × 3 replica + 3 tidb_servers + HAProxy frontend：在 3s3r l4r4 基礎上把 client 入口從單 .32 改成 HAProxy 在 .20:4000 round-robin 分流到 .32/.33/.34:4000。量化「分散 SQL 入口」紅利。

#### 拓樸示意

```
                     client (.31)
                       │  go-tpc → 172.24.47.20:4000
                       ▼
            ┌──────────────────────┐
            │  HAProxy on .20:4000  │
            │  balance roundrobin   │
            │  mode tcp             │
            └─────┬────┬────┬───────┘
                  │    │    │
        .32:4000  │    │    │  .34:4000
         tidb     │    │    │   tidb
         server   │    │    │   server
                  │ .33:4000│
                  │   tidb  │
                  │  server │
   下面是儲存層（與 3s3r 同）：
   3× PD + 3× TiKV，RF=3（PD `l4r4` 套餐）
```

#### 關鍵 DB 設定（與 3s3r l4r4 完全相同；唯一變因是 SQL frontend）

| 維度 | 設定 |
|---|---|
| `pd: replication.max-replicas` | `3` |
| `pd.schedule.replica-schedule-limit` | `4`（Fix #11） |
| `pd.schedule.leader-schedule-limit` | `4`（D10） |
| tidb_servers 數 | **3**（playbook conditional render 在 sub_topology=haproxy-3s3r 時） |
| HAProxy timeout | client/server 各 1800s |
| HAProxy balance | `roundrobin` `mode tcp` |
| client `--db-host` | `172.24.47.20:4000`（HAProxy frontend） |

#### Dry-run 預期

- `actual-rf-peer-min/-max` 同 3s3r l4r4 = 3
- `replication-factor.txt` = 3
- HAProxy backend health：3 個 server check OK（cfg 中 `check inter 2s`）

#### Execute 結果

| TS | 來源 |
|---|---|
| `20260601T003316+0800` | `vm-3node-haproxy-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-haproxy-3s3r-rc-20260601T003316+0800/` |

tpmC 5-round mean：t=16 = 11,816 ／ t=32 = 17,986 ／ t=64 = 23,034 ／ t=128 = **26,947**。
NEW_ORDER p99 mean：t=128 = **309 ms**。
最終 leader 分佈：**7 / 14 / 8**（vs direct l4r4 的 4/15/10，最差偏差從 +55% 縮到 +45%）；實際 region peer count = 3。
Stability：t=128 range/mean = 7.4%（vs direct l4r4 的 11.6%）。

跨 cell 對照（vs direct l4r4，含 .32 disk/CPU shift 證據）→ `dispatch-records/2026-06-01-tidb-haproxy-vs-direct-3s3r-l4r4.md`。

| metric | direct l4r4 t=128 | haproxy l4r4 t=128 | Δ |
|---|---|---|---|
| tpmC mean | 15,082 | 26,947 | **+78.7%** |
| NEW_ORDER p99 mean | 590 ms | 309 ms | **−47.6%** |
| Stability (range/mean) | 11.6% | 7.4% | 更穩 |
| .32 CPU %us | 80.3% | 72.4% | −7.9 pts（負載往 .33/.34 + storage I/O 分散） |
| .32 disk wkB/s | 22,052 | 32,641 | +48%（throughput 拉升、storage 變主瓶頸） |

---

## K8s (k8s-3node-unlimit / k8s-3node-limit) — 已移轉至 pipeline-log-old.md

> 2026-05-10 的 K8s 結果採單次 10min wrapper 格式，不符合本檔 v4.7 baseline 標準（5-round × 20min warmup × DB-host 雙邊監控），於 2026-05-20 移至 [`pipeline-log-old.md`](./pipeline-log-old.md) 存檔。待 K8s 環境以 v4.7 detached suite 重跑後，將回填正式段落。

