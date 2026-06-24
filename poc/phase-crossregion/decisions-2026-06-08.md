# phase-crossregion Decisions — 2026-06-08

> Q&A session 用於 planning agent 提出的 10 open questions。user 拍板紀錄。

## Q1: GCP VM (SPOT) 現狀應對

**Decision**: **全部重建 5 VM**（terraform 凍結解除）

### Topology 細節（user 提醒）
phase-crossregion 需要 **5 VM** in GCP region（user 重點指正）：
- **client × 1**（go-tpc client / GCP-side）
- **haproxy × 1**（GCP-side load balancer）
- **node × 3**（TiDB / DB cluster nodes）

之前 planning agent 把 `4 VM` (g-test-poc-1/2/3/4) 視為「3 node + 1 client」，**漏掉 haproxy**。

### Action
- 解除 `iac-gcp/terraform.tfvars` + `terraform.tfstate` 凍結
- 重新 `terraform apply` 或 `make new-gcp-vms`
- 確認 inventory 含 5 host：`g-test-poc-1/2/3` (node) + `g-test-poc-4` (haproxy) + `g-test-poc-5` (client)
- **若現有 iac-gcp module 只定義 4 VM → 需擴充 module 加 5th VM (haproxy)**

### 待補項目
- 確認 iac-gcp Terraform 是否已含 5 個 VM 定義（如缺 haproxy VM，需新增）
- IAP tunnel port range 對應 5 VM（目前 12211/12212/12213/12214 → 補 12215）

---

## Q2: WAN baseline (iperf3/ping/MTU) 採樣時機

**Decision**: **無需獨立 baseline stage**

### 規則
1. **mrtg 已常駐監控**（GCP↔IDC WAN bandwidth/packet metric） — 提供長期趨勢
2. **iperf3 / MTU 採樣**：整合進壓力測試期間隨 workload 同步採樣（**不**作為前置獨立階段）
3. **不需常駐** iperf3 server / client — 隨測試開關
4. **GCP VM lifecycle**：phase-crossregion 測試完即 **destroy**（不留長期 VM）

### Impact on planning
- 取消原 planning agent 的 G1 stage「WAN baseline 1.5d wall clock」
- 改為 per-cell 跑 benchmark 時 inline 採樣 iperf3 / MTU 寫進 `runs/threads-N/round-N/wan-probe.txt`
- 取消 B4「RTT p50<50/p99<200/BW>100Mbps/loss<1%」hard gate — 改為 mrtg 即時觀察 + benchmark 期間若 latency 偏離 mrtg 趨勢則記 warn
- pre-P0 framework 工序減少 ~1.5d

---

## Q3: Pre-P0 框架 — 3 DB family（user 指正 NOT TiDB-only）

**Decision**: **重寫**，且範圍涵蓋 **TiDB + CRDB + YBDB** 三家（取代 planning agent 原 TiDB-only 假設）

### 影響
原 agent 估 6-7 天為 TiDB-only。3 DB 擴展後：

| Stage | TiDB-only 估時 | 3 DB 估時 |
|---|---|---|
| G3 ansible 6-node playbook | 2.5d | **~7.5d**（tidb-vm6.yml + cockroach-vm6.yml + yugabyte-vm6.yml）|
| G4 placement spec/SQL | 1d | **~3d**（TiDB rules / CRDB locality+partitioning / YBDB preferred-leaders）|
| G5 dry-run-confirm placement gate | 0.5d | **~1.5d**（3 DB 驗證方式不同：TiDB SHOW PLACEMENT / CRDB SHOW LOCALITY / YBDB yb-admin get_universe_config）|
| G6 results 框架 | 0.5d | **~1d** |
| G7 Makefile | 0.5d | **~1d**（phase-crossregion-{deploy,run}-{tidb,crdb,ybdb}）|
| **合計** | 6-7d | **~14d** |

### 待補項目（per DB）
1. **TiDB**: `tidb-vm6.yml` locality label `config.labels.region/zone` + `SHOW PLACEMENT FOR` SQL
2. **CRDB**: `cockroach-vm6.yml` `--locality region=...,zone=...` + `ALTER TABLE ... CONFIGURE ZONE USING constraints` + `crdb_internal.zones`/`SHOW RANGES` 驗證
3. **YBDB**: `yugabyte-vm6.yml` `--placement_cloud/region/zone` gflag + `yb-admin modify_placement_info` + `yb-admin get_universe_config` 驗證

### scope upgrade impact
- Original "保守 v1" tier (10-11d) → **~18-20d**（含 3 DB pre-P0）
- "中度 (推薦)" (15d) → **~25-28d**
- "激進" (22-25d) → **~35-40d**

phase-crossregion 變成 month-scale 計畫，需重議 PoC 整體交付時程。

---

## Q4: Workload profiles 範圍

**Decision**: **A-S + A-A-RO + A-A**（3 profile × 3 DB = 9 cell-tracks）

### Profile 說明（user 詢問 backup/migration 是什麼）

| Profile | 內容 | 跑法 |
|---|---|---|
| **A-S** (Active-Standby) | IDC = primary writer，GCP = passive standby | 寫只在 IDC；GCP follower 同步；可量 failover RTO/RPO |
| **A-A-RO** (Active-Active read-only) | IDC = primary writer，GCP = read-only follower | 寫只在 IDC；GCP follower 接 read query（負載分流）|
| **A-A** (Active-Active read-write) | 兩端都寫，靠 placement rule 分 warehouse range | IDC W=1-64，GCP W=65-128；測 cross-region commit latency |
| ~~backup~~ | TiDB BR / `cockroach backup` / `yb-admin backup` 跑在 W=128 TPCC 背景 | 量 backup 時對 workload latency/throughput 影響 + backup elapsed |
| ~~migration~~ | 跑期間動態 placement 切換（P-A → P-B 或 add/drop node）| 量 re-balance 時間 + workload disruption |

backup / migration = **operational scenario**（運維場景 / 維護期動作），不在本次 PoC 範圍 → **跳過**。

### Impact
- 9 cell-tracks 不含 backup/migration
- 取消原 P4 (backup) + P5 (migration) stages
- planning agent 推薦 tier 重算：「中度」9 cell × ~15h sweep + thread sweep = ~135h ≈ **~17 天 runtime**

---

## Q5: Chaos 場景

**Decision**: **C1 + C4 + C7**

| Scenario | 內容 | 動因 |
|---|---|---|
| **C1** | GCP-side node down | failover RTO/RPO 量測 |
| **C4** | GCP↔IDC network partition | split-brain / quorum 行為 |
| **C7** | disk-full | storage exhaustion 在 multi-region 下的傳播 / 恢復行為 |
| ~~C3~~ | IDC-side node down | 與 C1 機制類似（單側 node failover），不重複 |

### Impact
- 3 chaos scenario × 3 DB = 9 chaos test runs
- 每 scenario lab-mode 量測 (failure-persist 5 round): ~half-day each → 9 × 0.5 ≈ **4.5 工作天**

---

## Q6: A-S / A-A-RO / A-A workload 拆分策略

**Decision**: 三 profile 各自 go-tpc 參數規範如下（不切 warehouse range）

### A-S (Active-Standby)
| Client | go-tpc 參數 |
|---|---|
| IDC (.31) | `--warehouses 128 --threads N`（standard TPCC mix）|
| GCP (g-test-poc-5) | **不跑 go-tpc**（passive standby）|

DB-side：GCP follower 量 follower lag / WAL apply 速率（DB-level metric）

### A-A-RO (Active-Active read-only)
| Client | go-tpc 參數 |
|---|---|
| IDC (.31) | `--warehouses 128 --threads N`（standard mix）|
| GCP (g-test-poc-5) | `--warehouses 128 --threads N --mix 0:0:50:0:50`（純 read：ORDER_STATUS + STOCK_LEVEL）|

### A-A (Active-Active read-write)
| Client | go-tpc 參數 |
|---|---|
| IDC (.31) | `--warehouses 128 --threads N`（standard mix）|
| GCP (g-test-poc-5) | `--warehouses 128 --threads N`（standard mix；**全 W=128，與 IDC 重疊**） |

**重點**：A-A **不分 warehouse range** — 雙端皆對全 128 warehouse 寫入 → 測**真實 cross-region commit 衝突**情境（max contention scenario）

### thread_list
3 個 profile 都跑 thread∈{16, 32, 64, 128}；A-A 雙側同步同 thread 數

### 待驗證
- `--mix DELIVERY,NEW_ORDER,ORDER_STATUS,PAYMENT,STOCK_LEVEL=0:0:50:0:50` 參數 go-tpc 是否確實支援（需 `go-tpc tpcc run --help` 驗證；若 mix 順序/語法不同則調整）
- 雙 client orchestration wrapper：A-A-RO + A-A 需同時 launch IDC + GCP client，需 chrony drift < 100ms（後續 Q）

### 影響
- prepare.sh 不需改（single 128W mode）
- run.sh 加 `--mix` env 處理 A-A-RO 場景
- 新增 wrapper `run-vm6-{a-s,a-a-ro,a-a}.sh` × 3 DB

---

## Q7: failover RTO/RPO 量測 vs chaos

**Decision**: **拆開測**

### 定義差異
| 實驗類別 | 內容 | scope |
|---|---|---|
| **failover** | 計畫性 / 受控的 primary 切換（admin-triggered；如 TiDB `tiup cluster restart` / CRDB `cockroach node drain` / YBDB `yb-admin leader_stepdown`）| **正常營運**手段 |
| **chaos** | 非預期事件注入（節點 OS kill / network partition / disk-full）| **異常情境**測試 |

兩者：
- **觸發方式**不同（admin vs failure injection）
- **量測指標**不同（RTO/RPO 都量但語意不同 — 計畫性 vs 非預期）
- **預期 RTO**不同（計畫性 typically < chaos）

### 新增實驗 F1 (failover-only)
- F1 = 3 DB × {計畫性 primary 切換 IDC→GCP, GCP→IDC} = 6 RTO/RPO 量測
- 不跑 thread sweep；專門 sub-second precision 量 RTO + RPO
- ~half-day per DB × 3 = **~1.5 工作天**

### chaos 維持 (Q5 決議)
- C1 GCP node down: 非預期 failure 注入
- C4 network partition: split-brain 行為
- C7 disk-full: storage exhaustion

C1 + C4 + C7 × 3 DB = 9 chaos runs（不含 F1 6 failover runs）

### 影響
- 新增 deliverable: `phase-crossregion/failover/F1.md` spec
- 新增 wrapper: `run-vm6-failover.sh`

---

## Q8: 外部儲存 / backup/migration 後續

**Decision**: 
- backup/migration **記錄要做但權重低**（不進 phase-crossregion v1，列為後續 scope）
- 相關權限資源（GCS bucket / SA JSON / S3 / NFS shared FS）由 assistant 先列 prereq，user 不用拍板細節

### phase-crossregion v1 artifact 儲存路徑
| Source | Sink |
|---|---|
| IDC client (.31) | local `/tmp/poc-tpcc/artifacts/X-CROSS/` |
| GCP client (g-test-poc-5) | local `/tmp/poc-tpcc/artifacts/X-CROSS/` |
| Post-run consolidate | rsync 兩端 → Mac local `results/x-cross/` |

無需 GCS / S3 / NFS。

### Future scope (backup/migration 待補)
| Item | 需要 prereq |
|---|---|
| TiDB BR backup | GCS bucket + SA JSON 或 S3 bucket + AKSK |
| CRDB backup | 同上（cockroach 支援 GCS/S3）|
| YBDB backup | yb-admin export_snapshot → S3/GCS（同需 creds）|
| migration (placement re-balance) | 不需外部儲存 — 純 cluster-internal |

### Action items (assistant)
- 在 `phase-crossregion/backup-migration-future.md`（未來補）列：
  - GCS bucket 需求 (region asia-east1, retention 30 day, lifecycle 規則)
  - SA roles 需求 (storage.objectAdmin)
  - 預估 bucket size (TiDB BR backup 128W ≈ ~5 GiB)
- v1 不阻塞

---

## Q9: Placement P-A / P-B 起作順序

**Decision**: **先 P-A 再 P-B**（保守路線）

### 順序理由
- P-A IDC majority → leader 集中 IDC, follower 在 GCP → cross-region WAN 影響小（限 raft log replication latency）
- 先 P-A：驗證 framework + 取 conservative baseline
- 再 P-B：cross-region active-active leader → WAN 影響大，以 P-A delta 為參考

### Per cell sequence
For each DB (TiDB → CRDB → YBDB):
1. Deploy with placement = P-A
2. Run profile A-S → fetch
3. Run profile A-A-RO → fetch
4. Run profile A-A → fetch
5. Cell-cleanup + Re-deploy with placement = P-B
6. Run profile A-S → fetch
7. Run profile A-A-RO → fetch
8. Run profile A-A → fetch
9. Cell-cleanup before next DB family swap

### Cell matrix recount
| Axis | Value |
|---|---|
| DB family | TiDB / CRDB / YBDB (3) |
| Placement | P-A / P-B (2) |
| Workload profile | A-S / A-A-RO / A-A (3) |
| Thread | 16 / 32 / 64 / 128 (4) |
| Round | 5 |
| **合計 sweep runs** | 3 × 2 × 3 × 4 × 5 = **360 individual rounds** |

Plus F1 (failover) + C1/C4/C7 (chaos) = +15 special runs

### Runtime estimate
- Per round (5 min) + per warmup (20 min once per cell) = average ~25 min per round amortized
- 360 rounds × 25 min ≈ **150 hours sweep runtime alone** (~19 工作天)
- + failover/chaos runs ~6 工作天
- + 3 DB × 2 placement = 6 deploy/cleanup cycles ~3 工作天
- + framework Pre-P0 ~14 工作天
- **Total: ~42 工作天**（month-scale, conservative tier）

---

## Q10: Chrony drift IDC × GCP

**Decision**: **不需設同源 NTP**；測試實時驗證 drift < 100ms

### 規則
- IDC chronyd 走內部 NTP source（既有設定）
- GCP VM 走 Google 公有 NTP (metadata.google.internal)
- **不主動同步 NTP source**
- **每 cell prepare 階段**檢測 IDC ↔ GCP drift：
  - `chronyc tracking` on .31 IDC client + g-test-poc-5 GCP client
  - 比對 `Last offset` 或 `Reference time`
  - drift > 100ms → cell fail-closed
  - drift < 100ms → 進入 sweep

### 實作
- gate.sh 加 chrony-cross-region 子 gate
- artifact: `gate/chrony-cross-region.txt`
- gate.sh 對 X-CROSS scope 自動 enable

### Risk mitigation
- Google Cloud VM 預設 NTP 多數情況 drift < 5ms
- IDC chronyd 一般 sync 內部 stratum-2/3 source
- 兩者跨區 drift typically < 50ms（NTP 不需同源即可保 100ms 精度）
- 邊界情況：IDC NTP server 失效或 GCP metadata service 失效 → drift 飆升 → gate fail-closed 保護
