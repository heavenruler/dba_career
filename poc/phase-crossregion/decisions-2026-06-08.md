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

---

## Q11: 三家 DB cell 間 VM destroy / recreate 強制要求

**Decision date**: 2026-06-29
**Owner**: PoC owner (wn.lin@104.com.tw)

**Decision**: 三家 DB（TiDB / CRDB / YBDB）X-CROSS cell 之間**強制完整 VM destroy + apply**（terraform 雙側）；不接受 service-level cleanup（systemctl stop + DROP DATABASE + rm -rf）取代。

### 規則
- cell 順序固定 TiDB → PASS → CRDB → PASS → YBDB（per Q9 同 placement 內 DB 順序）
- 一家 cell `.suite.done` 寫入後，下家 cell 啟動前**必跑** `make phase1-destroy phase1-apply phase1-wait-via-31`
- 完整 VM rebuild 不可由 ansible cleanup playbook / DROP DATABASE / `rm -rf /var/lib/<db>` 取代

### Rationale（含 trade-off，不寫成科學必然）
- **降低殘留污染**：上家 DB 的 systemd unit、SELinux context、firewall rule、symlink、`/var/lib/<db>`、cgroup、TCP socket time-wait、disk LBA hotness、dnf cache 等**可能**滲透到下家 cell 量到的數字
- **同時**：完整 VM rebuild 會**增加 between-suite environment variance**（GCP API 排班 / vSphere datastore 熱點 / 兩側 cloud-init 時間漂移 / dnf mirror latency 變動）。這個變異不能假設為零。
- 因此本規則的**屬性是 "controlled bias trade"**：用較高 environment variance 換較低 cross-DB residue bias，**非科學必然**。
- 接受此 trade 是因為 X-CROSS phase 已 `baseline_eligible: false`、`requires_n: 1`（per `manifest.yaml`），cell 內統計穩定性次要於 cell 間隔離性。

### Action
- `phase-crossregion/Makefile`：no change（`phase1-destroy phase1-apply` 已存在）；wrapper（待實作）必須在 `gate` 第一步驗 `.31` 端對 cluster 端的 SSH 是否還記得舊 host key，殘留即視為前家未清乾淨 → fail-closed
- demo / audit / report 必引此 Q11 為 SSOT；不再引 `feedback_xcross_serial_per_db` memory（per reviewer §2.7）
- `summary.json` schema 應在 `controller_provenance` 或新欄位記錄 `prev_suite_done` + `vm_rebuild_ts`（每 cell run 前 VM image creation timestamp），讓 audit 可追

### 不適用範圍
- 同家 DB 內 round 之間（5-round suite）不需 VM rebuild
- 同家 DB 內 thread sweep（16/32/64/128）不需 VM rebuild
- DEV-1x1 framework selfcheck 若僅用於程式 sanity（非性能比較），可降為 service-level cleanup（明標 caveat）

### 跨 phase 對照禁制（per codex F6）

X-CROSS（vm-6node）與 S-BASE（vm-3node）**節點數 / quorum / 硬體 / topology 都不同**，**不是 paired control**。即使三家 X-CROSS cell 之間都跑 VM rebuild 保隔離，X-CROSS vs S-BASE 仍**禁用以下任一公式**作對外結論：
- `retain% = X-CROSS / S-BASE × 100`
- `WAN penalty = S-BASE - X-CROSS`
- `Δ vs IDC-only = ...`

理由：差距同時包含 (a) 跨區 cost (b) 節點數差（3→6）(c) quorum 模型差。算術無法分離。若 PoC 需量化「跨區 cost」，必須另跑 IDC-only 6-node paired control（同硬體 + 同 quorum + 同 W）；當前 audit blocker #3 已標 TBD。

S-BASE vm-3node 只能作「contextual reference」（per audit blocker #3 revised）。

---

## Q12: Promotion checklist gate 觸發時機

**Decision date**: 2026-06-29
**Owner**: PoC owner

**Decision**: `x-cross-report-demo-audit.md` §6 列的 9 項 promotion checklist 中，**#8 (static check) + #9 (header flip OFFICIAL)** 為**per-stage gates**，**不是 final-only gates**。

### 規則
- 每完成一個測試階段（每個 cell 寫入 `.suite.done` 後）必須立即跑 #8 static check 5 項；任一條 FAIL → 該 cell artifact 標 `incomplete=true`，下家 cell **不可**啟動
- #9 header 翻 OFFICIAL 在**最後一個 cell** 完成 + #1-#7 全 PASS + #8 重跑 PASS 後執行；單一 commit 翻 header
- 等價於：#8 從 9 項中拆出，作為**每 cell promotion gate**；#9 仍為 final report gate

### Rationale
- 原 audit 把 #8/#9 與作業項目混列同一表，誤導為 final-only。實際上 static check 是廉價驗證（grep + link check），每 cell 跑成本 ~30 sec
- 早期偵測比晚期偵測便宜：若 cell 1 的 demo 漂移已含 fake/synthetic 殘留，等到 cell 3 才發現代表 cell 1+2 都要重新審查

### Action
- `x-cross-report-demo-audit.md` §6 重新分類：#1-#7 = active task；#8 = per-cell gate；#9 = final gate
- demo §14 (11-item promotion gate) 加註 #8 觸發時機
- wrapper（待實作）在 `summary` stage 後自動跑 static check；FAIL 則 `.suite.done` 標 `incomplete_reason: static-check-fail`

---

## Q13: 三家 DB 就近讀寫等價設定

**Decision date**: 2026-06-30
**Owner**: PoC owner
**Source**: `1_MeetingMinutes/0630.md` §5 / §8（TiDB 為主）+ CRDB / YBDB 官方文件對等性推導 + `phase-crossregion/workload-profiles/A-A-RO.md`

**Decision**: 三家 DB 的「就近讀寫」需透過下表設定才會生效；TL;DR §D 表中「CRDB / YBDB 等價設定」從 INFERRED 升為 **PLANNED**（待 framework patch 階段 prepare stage 落地）。

### 設定對照表

| 機制 | TiDB | CockroachDB | YugabyteDB |
|---|---|---|---|
| **Region / Zone label** | TiKV server.labels `region=idc/gcp, zone=...`（已落地 `ansible/playbooks/tidb-vm6.yml:203-208`）| 啟動 flag `--locality=region=idc,zone=...` | tserver flag `--placement_cloud=104 --placement_region=idc/gcp --placement_zone=...` |
| **Topology labels（PD/cluster 側）** | `replication.location-labels=["region","zone"]`（已落地 tidb-vm6.yml:234）| 同 locality；無另設 | 同 placement_*；無另設 |
| **就近讀（client session）** | `SET GLOBAL tidb_replica_read='closest-replicas';` | `SET CLUSTER SETTING kv.closed_timestamp.follower_reads_enabled=true;` + 查詢 `SELECT ... AS OF SYSTEM TIME follower_read_timestamp()` | `SET yb_read_from_followers=true;` + `SET yb_follower_read_staleness_ms=30000;` |
| **Control plane（metadata）就近** | `SET GLOBAL pd_enable_follower_handle_region=ON;`（v8.5+ GA）| 無對應；CRDB metadata 分散在所有 node | 無對應；YBDB master metadata 由 yb-master 處理（已 leader-only）|
| **TSO / global time 就近** | `SET GLOBAL tidb_enable_tso_follower_proxy=ON;`（**先測再決定**，per 0630.md §6.3）| HLC 無集中 TSO；不適用 | HLC 無集中 TSO；不適用 |
| **Placement Policy（leader 偏好）** | `CREATE PLACEMENT POLICY ... PRIMARY_REGION='idc' REGIONS='idc,gcp' FOLLOWERS=2;`（per 0630.md §5.1） | `ALTER DATABASE tpcc CONFIGURE ZONE USING lease_preferences='[[+region=idc]]', constraints='[+region=idc, +region=gcp]', num_replicas=3;` | tablespace `placement_blocks` + `yb-admin modify_placement_info '104.idc.vlan241:2,104.gcp.asia-east1-a:1' 3 ...`（已落地 `tests/yuga/`）|
| **強制本地或 fallback** | `closest-replicas` 是優先策略，不是 fail-closed（per 0630.md §5.3）；本地不可用 → fallback Leader | follower reads 需 staleness ≥ closed timestamp；不足則 fallback leaseholder | `yb_follower_read_staleness_ms` 控 staleness 容忍；ms 太小 → fallback leader |

### 同源 caveat（三家共通）

per 0630.md §5.4 / §10：「就近讀寫」**data plane 優先本地** 是可達；「IDC Request 絕不離開 IDC」**單一強一致 cluster 做不到**。三家在以下情境仍**會跨區**：
- 寫入路徑：寫入唯一 Region Leader / Range Leaseholder / Tablet Leader；leader 在跨區就跨區
- Control plane：metadata fallback / TSO / 跨區 raft heartbeat
- 強一致 follower read：須跨區 ReadIndex / closed timestamp 確認
- 本地 replica 故障：fallback 到跨區 leader / leaseholder

### Action（與 framework patch 同批做）

- **prepare 階段**新增 SQL 步驟：三家各自 SET 上表「就近讀」設定；保留 SHOW snapshot 進 artifact
- **dump-actual 階段**新增 SHOW GLOBAL VARIABLES snapshot（per 0630.md §9.4，TiDB；CRDB 對應 `SHOW CLUSTER SETTING ...`；YBDB 對應 `SHOW yb_read_from_followers`）
- **collect 階段**新增 leader 分布 query：TiDB `TIKV_REGION_PEERS` / CRDB `crdb_internal.ranges` / YBDB `yb-admin list_tablets` per node
- TL;DR §D 表「CRDB / YBDB 等價設定 INFERRED」更新為 PLANNED（源 = Q13）

### 不在 Q13 範圍（留下個 decision）

- 三家「strong consistent follower read」是否啟用（一致性 vs latency trade-off）
- CRDB `SET CLUSTER SETTING sql.defaults.experimental_follower_read_timestamp` 預設 staleness
- YBDB consistency mode：`yb_consistency_level` 對 follower read 的影響
- 跨 DB「fallback rate」量測規格（per 0630.md §5.3 提的 closest-replicas 不是 fail-closed）

---

## Q14: Follower Read 一致性模式、Staleness 預設與 Fallback Rate 量測規格

**Decision date**: 2026-06-30
**Owner**: PoC owner
**Source**: Q13「不在 Q13 範圍」四項

**Decision**: PoC 只測 **stale follower read**（非 strong consistent follower read）；staleness 設定以 prepare.sh §6.5 已落地值為準，不另覆蓋；fallback rate 以 probe latency 差值間接量測。

### §1 一致性模式選擇

| 選項 | 說明 | PoC 決定 |
|---|---|---|
| **stale follower read** | 接受 staleness window；讀本地 replica，不需跨區確認 | ✅ 選此 |
| **strong consistent follower read** | 讀本地 replica 但仍需跨區 ReadIndex / closed timestamp check | ❌ 不測（strong 仍需跨區確認，latency 優化有限；與 PoC 觀察 locality 目標無額外資訊）|

### §2 Staleness 預設值拍板

| DB | 設定 | 值 | 備注 |
|---|---|---|---|
| TiDB | `tidb_replica_read='closest-replicas'` | best-effort（無固定 staleness window） | 已落地 prepare.sh §6.5；本地 replica 不可用時 fallback leader |
| CRDB | `kv.closed_timestamp.target_duration` | 預設 3s（不覆蓋） | follower read 需查詢加 `AS OF SYSTEM TIME follower_read_timestamp()`；go-tpc 不支援 → go-tpc 所有讀仍走 leaseholder；probe SELECT 1 同；CRDB follower read 效益於 PoC 僅 probe 層可見 |
| YBDB | `yb_follower_read_staleness_ms` | 30000 ms（已落地 prepare.sh §6.5） | 若 IDC probe p50 ≈ GCP probe p50（高 fallback 徵兆），調降至 10000ms 後 re-measure |

### §3 YBDB `yb_consistency_level` 處置

- 維持 default `STRONG`：只影響寫入 ACK 語意；follower read 機制依賴 `yb_read_from_followers=true`，二者獨立
- **不覆蓋 `yb_consistency_level`**；覆蓋為 `CONSISTENT_PREFIX` 會犧牲 write linearizability，與 PoC 效益評估目標不符

### §4 Fallback Rate 量測規格

closest-replicas / stale follower read 不是 fail-closed（per Q13）；DB 內部 fallback counter 無統一 API → 用 **probe latency 差值**間接推算：

| 量測方式 | 具體做法 | 判讀邏輯 |
|---|---|---|
| **probe latency delta** | `probe-iso-latency.sh` 同時在 IDC node（`172.24.40.3{2,3,4}`）和 GCP node（`10.160.152.{11,12,13}`）跑 SELECT 1 loop；各輸出 p50 | IDC_p50 ≪ GCP_p50（差距 ≈ WAN RTT）→ locality 生效；IDC_p50 ≈ GCP_p50 → 高 fallback 徵兆 |
| **artifact** | `probe-iso-latency-idc.json` / `probe-iso-latency-gcp.json` → `region_routing_evidence` 欄位（已在 `summary-from-stdout.py collect_region_routing_evidence()`）| — |
| **判定 threshold（診斷用，非 hard gate）** | IDC_p50 / GCP_p50 < 0.7 → locality 生效（PASS-DIAG）；≥ 0.7 → 可疑 fallback（WARN-DIAG） | per 0630.md §5.3 推算；不阻擋 promotion |
| **精確 fallback rate（Wave 3 後）** | TiDB `SHOW GLOBAL STATUS LIKE 'tidb_kv_request_*'`；CRDB `crdb_internal.node_statement_statistics local_reads`；YBDB tserver metric API | 超出 PoC 範圍 |

### 與 prepare.sh §6.5 的關係

Q14 不新增任何 SET 指令——§6.5 已落地三家 stale follower read 設定。Q14 拍板的是：
1. 只測 stale，不測 strong（選擇依據）
2. CRDB staleness = 預設 3s（不覆蓋）；accept go-tpc limitation
3. YBDB `yb_consistency_level` 不動
4. fallback rate 用 probe latency 差值間接量（threshold 為診斷 hint，非 gate）

---

## Q15: W=128 驗收 CV 口徑（2026-07-02 拍板）

**Decision**: **R1–R5 mean 維持**（現行 code canonical）

### 規則
1. `summary-from-stdout.py` / PHASES §5 的 `tpmC_mean = R1–R5 mean` **不改**
2. 不另算 R2–R5 CV；determinism v2 協議的「排除 R1」條款**不採用**於 W=128 正式 cell
3. 依據：W=128 有 20min 正式暖機，R1 暖機殘留理論上已小；且與 S-BASE 既有口徑一致，跨 scope 對照免轉換

## Q11 作用域澄清（2026-07-02 拍板）

**Decision**: placement 變更（P-A → P-B）之間 **VM full rebuild（per-cell）**

### 規則
1. TiDB A-S 視窗 Touch 2：`teardown-tidb` 後、P-B deploy 前，**必跑 `make phase1`**（+約 1h）
2. 理由：殘留狀態清零，P-A / P-B 兩 cell 起點同質，排除 page cache / 磁碟狀態 confounder
3. 同 DB 換 placement 與換 DB family 一視同仁——都是新 cell，都重建
