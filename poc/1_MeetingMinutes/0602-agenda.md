# 2026-06-02 PoC 定期會議討論事項

> 對應文件：`poc/1_MeetingMinutes/0602.md`（含 Track A–E 完整規劃）

> **Status as of 2026-06-05**：§3 + §4 跨專線決策已透過 [`0602-decisions-track-E.md`](./0602-decisions-track-E.md) 拍板（commit `fca302b`）；§5 阻塞點清空；§1 大部分仍 pending（A 區 6 項待拍）；新增 §6 = 0605 議題（commit `9dc0231`）。
>
> 圖例：✓ 已決 / ⏳ pending / ✗ 阻塞

---

## §1. 第一階段 測試結論彙整（TiDB / YBDB）

1. **TiDB 結果呈現方式（l4r4 leader balance 已知 caveat）** ⏳ 待 §12 A2/A3
   - 選項 A：l4r4 直接跑、README 主表加 caveat 註腳 — 成本最低；對外解讀可能模糊
   - 選項 B：l0r0 重跑 5 cell — 消滅 caveat；成本 +15h
   - 選項 C：l4r4 主跑 + l0r0 補 1 cell 對照 — 折衷量化影響；成本 +3h

2. **YBDB 結論固化** ⏳ 待 §12 A 區（連動 N=3）
   - 現況：vm-3node 5 cell 全綠 N=1 已完
   - 待決：N=1 是否足以入主表

3. **N=3 補測範圍** ⏳ 待 §12 A6
   - 選項 A：三家 3s3r 各補 N=3（最有代表性對照組；~9h）
   - 選項 B：只補 haproxy-3s3r 一個 cell（~3h）
   - 選項 C：全 cell N=3（~45h，過大）
   - **選項 D（建議補入）**：3s3r + haproxy-3s3r 兩 cell × 三家（~18h，與 Pre-P0 並行不擋路）

4. **Batch script 入庫** ⏳ 待 §12 A4
   - 現況：`/tmp/batch-crdb-5cell-suite.sh` + `/tmp/batch-tidb-5cell-suite.sh` 為 transient
   - 待決：是否搬至 `poc/tests/batch/` commit（保留可重現）

---

## §1-A. 第一階段 測試數據彙整參考（TiDB / YBDB，N=1，5-round mean）

> 條件：iso=rc / W=128 / threads=[16,32,64,128] × 5 rounds；TiDB 3s3r 取 l4r4 production-mode。CRDB 進行中（cell 1s1r PASS / 4 cells 跑中）暫不入此表。

### 1-A.1 tpmC（5-round mean，best @ t）

| 拓樸 | TiDB tpmC | @ t | YBDB tpmC | @ t | TiDB vs YBDB |
|---|---:|:---:|---:|:---:|---:|
| vm-1node-rc | 13,064 | 128 | 11,436 | 32 | +14.2% |
| vm-3node-1s1r-rc | **19,654** | 128 | 13,725 | 128 | **+43.2%** |
| vm-3node-3s3r-rc-direct | 15,082 | 128 | 8,729 | 128 | **+72.8%** |
| vm-3node-3s3r-rc-haproxy | **26,947** | 128 | 15,632 | 128 | **+72.4%** |

### 1-A.2 NEW_ORDER p99 latency（5-round mean，best 點 @t=128，ms）

| 拓樸 | TiDB p99 | YBDB p99 | YBDB / TiDB |
|---|---:|---:|---:|
| vm-1node-rc | 597 | 1,000 | 1.67× |
| vm-3node-1s1r-rc | 456 | 758 | 1.66× |
| vm-3node-3s3r-rc-direct | 590 | 1,114 | 1.89× |
| vm-3node-3s3r-rc-haproxy | 309 | 705 | 2.28× |

### 1-A.3 變數獨立成本拆解（best mean tpmC，1s1r 作 baseline）

| 變數 | TiDB Δ tpmC | YBDB Δ tpmC | 觀察 |
|---|---:|---:|---|
| 1node → vm-3node-1s1r（cluster overhead + 多 store） | **+50.4%**（13,064→19,654） | **+20.1%**（11,436→13,725） | TiDB scale-out 收益遠大於 YBDB；YBDB tserver 雙進程在 4 vCPU 共用 CPU 是瓶頸 |
| 1s1r → 3s3r-direct（RF=3 + shard 疊加） | **−23.3%**（19,654→15,082） | **−36.4%**（13,725→8,729） | YBDB tablet 協調成本 +13 pp 高於 TiDB（81 replicas / 4 vCPU 過載） |
| 3s3r-direct → 3s3r-haproxy（multi-tidb / multi-tserver 分散 SQL 層） | **+78.7%**（15,082→26,947） | **+79.1%**（8,729→15,632） | **同向 ~78%** — 共同根因：3 個 DB-server 分擔 client/parser/coord 排隊 |

### 1-A.4 差異分析

| # | 觀察 | 數據 | 根因 | 對結論影響 |
|:---:|---|---|---|---|
| **1** | TiDB scale-out 收益遠大於 YBDB | vm-1node → vm-3node-1s1r：<br/>TiDB **+50.4%**（13,064→19,654）<br/>YBDB **+20.1%**（11,436→13,725） | YBDB YSQL+DocDB 雙進程 + RocksDB compaction 競爭 4 vCPU 預算 | YBDB 在小 vCPU 機型 scale-out ROI 低；建議 vCPU ≥ 8 |
| **2** | HAProxy 同向收益 ~+78% | direct → haproxy（t=128）：<br/>TiDB **+78.7%**（15,082→26,947）<br/>YBDB **+79.1%**（8,729→15,632） | 共同瓶頸 = 單一 entry node 的 client / parser / coord 排隊；3 個 DB-server 分擔後立刻拉開 | production 必上 HAProxy；single-entry 拓樸已飽和 |
| **3** | p99 全程 YBDB 為 TiDB 1.6–2.3× | t=128：<br/>1node 1,000 vs 597（1.67×）<br/>haproxy 705 vs 309（**2.28×**） | YBDB tablet leader 不平衡 + RocksDB tail latency；TiDB pessimistic + region cache 較穩 | tail-sensitive 應用（金融、即時報表）選 TiDB 較保險 |
| **4** | 3s3r 退化幅度 YBDB > TiDB | 1s1r → 3s3r-direct：<br/>TiDB **−23.3%**（19,654→15,082）<br/>YBDB **−36.4%**（13,725→8,729） | YBDB 9 表 × 3 tablets × 3 replicas = **81 replicas** on 4 vCPU；mpstat 顯示 t=32/64 CPU 24–42% idle 但 throughput drop（協調瓶頸非 CPU） | 3s3r 是 YBDB 真實災難場景；TiDB 較可接受 |
| **5** | 代表點選擇分歧 | YBDB：1s1r/3s1r @ t=32 飽和（CPU 9% idle）；其他 cell @ t=128<br/>TiDB：1node 甜點 @ t=64（12,744 / p99 305ms）；3node 全 @ t=128 | 兩家 saturation 拐點不同 — YBDB CPU 限制較緊；TiDB raft batching 推到更高 thread | 跨家對標報數**必須**明標 thread 點口徑，否則歧義 |

### 1-A.5 已知 caveat

| # | Caveat | 證據 / 數值 | 影響 | 緩解 |
|:---:|---|---|:---:|---|
| **C1** | N=1 | 4 cell × 2 DB 全部 N=1 | **高** | 對外白皮書前須 N=3 重做（建議三家 3s3r 各補；~9h） |
| **C2** | TiDB l4r4 mixed-state | 3s3r / haproxy-3s3r 為「leader/replica rebalance ON、region 凍結」半受控；leader 最終 7/14/8 超 ±20% 容差 | 中 | README 主表標 caveat 註腳 / 或改 l0r0 重跑（~15h） |
| **C3** | DB-host metrics 只採單台 | `run.sh:63-65` CLUSTER_HOST 寫死；.33/.34 metrics 全無 | 中 | 跨節點負載 / placement skew 看不見；跨區 Track E 必補 fan-out |
| **C4** | HAProxy 機制未直接驗 | suite 跑期間 stats socket 未開；roundrobin 生效以 tpmC +78% 反推 | 低 | 補開 stats socket dump `show stat`（5 min patch） |
| **C5** | YBDB 3s3r-direct 極不穩 | 5-round stddev 1,400–2,615；t=16 min/max 4.9×；haproxy 改善至 178–401（**14.7× 改善**） | 中 | 已用 haproxy 緩解；若 direct 仍需用，需 vCPU ≥ 8 |

### 1-A.6 來源 / 對應 dispatch 文件

| 區段 | 文件 |
|---|---|
| YBDB 4 cell（1s1r/1s3r/3s1r/3s3r）| [`results/dispatch-records/2026-05-25-vm-3node-ybdb-all4-rc-analysis.md`](../results/dispatch-records/2026-05-25-vm-3node-ybdb-all4-rc-analysis.md) |
| YBDB haproxy vs direct | [`results/dispatch-records/2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md`](../results/dispatch-records/2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md) |
| TiDB schedule-limit l0r0 vs l4r4 | [`results/dispatch-records/2026-05-31-tidb-schedule-limit-0-vs-4.md`](../results/dispatch-records/2026-05-31-tidb-schedule-limit-0-vs-4.md) |
| TiDB haproxy vs direct | [`results/dispatch-records/2026-06-01-tidb-haproxy-vs-direct-3s3r-l4r4.md`](../results/dispatch-records/2026-06-01-tidb-haproxy-vs-direct-3s3r-l4r4.md) |
| TiDB vm-1node-rc summary | [`results/tidb-tc1/S-BASE/vm-1node-rc/tidb-vm-1node-rc-20260518T202009+0800/summary.json`](../results/tidb-tc1/S-BASE/vm-1node-rc/tidb-vm-1node-rc-20260518T202009+0800/summary.json) |
| YBDB vm-1node-rc pipeline | [`results/yuga-tc1/S-BASE/pipeline-log.md`](../results/yuga-tc1/S-BASE/pipeline-log.md) §vm-1node-rc |
| TiDB vm-3node-1s1r-rc artifact | [`results/tidb-tc1/S-BASE/vm-3node-1s1r-rc/tidb-vm-3node-1s1r-rc-20260529T132940+0800/`](../results/tidb-tc1/S-BASE/vm-3node-1s1r-rc/tidb-vm-3node-1s1r-rc-20260529T132940+0800/) |
| YBDB vm-3node 四 cell artifact | `results/yuga-tc1/S-BASE/vm-3node-{1s1r,1s3r,3s1r,3s3r}-rc/` |
| 跨家 README 主表（含 vm-1node baseline） | [`results/README.md`](../results/README.md) |

---

## §2. 第一階段 分散式資料庫架構重點關注

1. **Shard 鎖定（manual SPLIT）作 baseline 的必要性**
   - 三家自然 shard 數皆不可控（TiDB `region-split-size`、CRDB `range_max_bytes`、YBDB tserver gflag）
   - 跨 cell 對照需強鎖；exploratory 路徑獨立成 caveat 段

2. **Auto rebalance / split 對 TPC-C 的衝擊**
   - run 期間任一 trigger 都汙染結果（split → p99 飆；leader move → tpmC 跌 5–15%）
   - TiDB l4r4 是已知例外（leader/replica 允許搬、region 凍結）

3. **CRDB v26.2.0 內部 API 變動風險**
   - `crdb_internal.*` 多數受限（SQLSTATE 42501）
   - 已知影響：F-A、F-D；其他散落呼叫尚未 audit（silent fail 風險）

4. **DB-host metrics 採集範圍**
   - 現況：只採 CLUSTER_HOST 單台（.32）
   - 影響：跨節點負載 / placement skew 看不見
   - 跨區（§3）必須補 fan-out

5. **Exploratory tracks 取捨（Track B/C/D）**
   - B = default-shard / C = auto-split ON / D = scale-out
   - 待決：哪些落地（成本 vs ROI）；建議：P3+P6 落地、P4 緩、P5 整合進 Track E

6. **建議新增 hard gate**
   - rebalance complete（`under_replicated==0` 連續 N 秒）
   - leader/leaseholder settle（stddev 收斂）
   - placement leader-affinity（Track E 用）
   - TiDB schedule-limit verify（驗 `pd-ctl config show schedule` 實際生效）

---

## §3. 第二階段 跨專線測試固定條件

1. **拓樸（10 nodes）**
   - IDC：172.24.40.31 (client) / 172.24.47.20 (HAProxy) / 172.24.40.32–34 (cluster ×3)
   - GCP：10.162.0.11 (client) / 10.162.0.12 (HAProxy) / 10.162.0.13–15 (cluster ×3)
   - 應用層守不跨區；DB raft 跨 WAN 是測量對象

2. **鎖定變數**
   - iso = rc / HAProxy = 每區 1 / 3 shard × 3 replica / W = 128

3. **Cluster 拓樸** ✓ single 6-node（B1）
   - 選項 A：single 6-node cluster — 測 raft 跨 WAN（PoC 重點）
   - 選項 B：two 3-node + 邏輯複製 (CDC) — 物理隔離、無 raft 跨區、測場景不同

4. **Placement 策略** ✓ P-A + P-B 兩拓樸都測（B2）
   - P-A：2-IDC + 1-GCP（majority IDC，GCP 純 follower）— 適 Test 1
   - P-B：1-IDC + 1-GCP + 1-arbiter / leader 各區散 — 適 Test 2

5. **DB 範圍** ✓ 先 TiDB（B3 / C3）
   - 選項 A：三家全測；選項 B：先 CRDB（跨區語義最完整）；選項 C：先 TiDB（既有最熟）

6. **N 數** ✓ 全部 N=1（B5；caveat: exploratory only，不入跨家 median table）
   - 建議：N=1 先 → 確認趨勢後挑代表 cell 補 N=3

---

## §4. 第二階段 跨專線測試方法論

1. **Test 1 — IDC 獨立 TPCC**
   - 目的:量化 raft 跨 WAN 對單側寫的損耗
   - 拓樸：6-node + P-A placement / 只 IDC client → IDC haproxy → IDC nodes
   - 預期：tpmC ↓ 10–30%（依 RTT）

2. **Test 2 — 兩區並發 TPCC** ✓ W 分配 Option B（C6）
   - 目的：量化 WAN 競爭 + 跨區 conflict
   - 拓樸：6-node + P-B placement / IDC + GCP 並行
   - W 分配選擇：
     - 選項 A：兩側都 W=1–128（測極端 contention）
     - 選項 B：IDC W=1–64, GCP W=65–128（隔離 key conflict 與 WAN 互擾）

3. **Test 3 — Chaos / Failover 7 場景** ✓ 首輪 4 場景 C1/C3/C4/C7（C7）
   - C1：IDC node 1 down / C2：IDC haproxy down
   - C3：WAN 全斷 / C4：WAN +200ms 延遲 / C5：WAN packet loss 5%
   - C6：慢 disk / C7：IDC 全 3 node down
   - C8（可選）：clock skew injection
   - 範圍取捨：
     - 選項 A：7 場景全跑（~21h）
     - 選項 B：挑關鍵 C1/C3/C4/C7（~12h）

4. **Baseline 對照來源** ✓ current haproxy-3s3r 3-node only（B7/C4，caveat: WAN + scale-out delta 混合）
   - 選項 A：現行 vm-3node-haproxy-3s3r 主表（直接 delta，拓樸非全同）
   - 選項 B：另跑純 IDC 6-node 同規格（拓樸對齊，+12h）

5. **WAN baseline 量測** ✓ Pre-P0 hard gate（B4；iperf3 + ping + MTU + 飽和 packet loss，多時段）
   - 必跑 iperf3 + ping p50/p99（起前 60s + 起末 60s）

6. **Chaos C3 / C7 風險** ✓ lab 模式（C5；首輪讓 failure 持續整 5 round）
   - C3：GCP minority 期間 read-only；C7：全 cluster 寫拒
   - 待決：production-like 或 lab 模式

7. **新增 artifact**
   - `wan/baseline-rtt.txt`、`wan/baseline-bw.txt`、`wan/runtime-bytes.txt`
   - `placement/leader-region.txt`、`placement/voter-region.txt`
   - `chaos/<C-id>/timeline.json` 等
   - **DB-host metrics fan-out 6 node 全採（Track E 必補）**

---

## §5. 專案進度時程表

### 第一階段（單區 vm-3node）

| # | 項目 | 狀態 |
|---|---|---|
| 1 | CRDB 5-cell suite | ✓ 完成（dispatch-records 系列 / commit 系列）|
| 2 | TiDB 5-cell suite | ✓ 完成（含 1s1r 數據回填 F7）|
| 3 | YBDB vm-3node | ✓ 完成 N=1 |
| 4 | TiDB dispatch 前 strict patch | — pending 釐清（settle gate / schedule-limit verify）|
| 5 | TiDB dispatch 觸發方式 | ✓ 完成（手動 batch dispatch 已執行）|
| 6 | N=3 補測 | ⏳ 待 §12 A6（建議選項 D：3s3r + haproxy-3s3r × 三家 ~18h）|
| 7 | 0602.md §13/§14 數據結論 + 決策結果 | ⏳ §14 跨區部分完成（[`0602-decisions-track-E.md`](./0602-decisions-track-E.md)）；§13 數據結論待 N=3 補測後彙整 |

### 第二階段（跨專線 vm-6node）

| # | 項目 | 預估 | 阻塞 |
|---|---|---|---|
| 1 | Pre-P0：WAN baseline + TiDB 6-node ansible + placement rule + dry-run gate + results 子目錄 | 3 工作天 | ✓ 全解除（可啟動）|
| 2 | P0：IDC-only-6-node TiDB 5-cell（選跑作 ansible 熱身）| ~3h × 5 cell | Pre-P0 完 |
| 3 | P1 Test 1：P-A 拓樸（IDC-only TPCC，GCP follower）| ~3h × 5 cell | P0 完 |
| 4 | P2 Test 2：P-B 拓樸（IDC+GCP 並行，Option B W 分配）| ~3h × 5 cell | P1 完 |
| 5 | P3 Test 3：4 chaos 場景 C1/C3/C4/C7 lab 模式 | ~半天 × 4 | P2 完 |
| 6 | P4：Track E 報告產出（pipeline-log + SUMMARY + 跨家對齊矩陣）| ~1 工作天 | P3 完 |

### 阻塞點

- ~~GCP IP 10.162.0.x 路由是否開通~~ → ✓ 已開通（C1）
- ~~iac/ansible 全未支援 6-node 跨區~~ → ✓ 已決定一次性 6-node ansible 重寫（C2，2-3 天）
- ~~Pre-P0 是否接受~~ → ✓ 接受 ansible 重寫路線（C2）

### 文件 / Doc 待辦

- Batch script 入庫（§1 第 4 項）— ⏳ 待 §12 A4
- PoC-DESIGN §6.5「Track 分類」章節 — ⏳
- PoC-DESIGN §「硬體飽和假設」— ⏳ 待 0605 #1 拍板（CPU ~80% 條件下調參目的論述）
- pipeline-log-template 加 settle 欄位 — ⏳
- pipeline-log-template 加 db-config dump checklist — ⏳ 待 0605 #2 拍板
- 0602.md 補 §13 數據結論 + §14 決策結果 — ⏳（§14 跨區部分完成）
- 三家統一 8-col TL;DR ranking — ✓ 完成（commit `8d4dded`，含 template 更新）
- audit-2026-06-04-pipeline-log-spec — ✓ 完成（commit `eb22cc4`，含 F-001 to F-006）
- **IaC phase isolation framework — ✓ 完成（commits `832a3b3..0b59897` 共 7 個，codex v4 approve）**
  - 新增 `results/PHASES.md` registry（4 scope SSOT：S-BASE / S-K8S / T-THRD / X-CROSS）
  - 三個頂層 phase dir：`phase-k8s/`、`phase-threadcontrol/`、`phase-crossregion/`
  - 三層 hard gate（path / marker / Makefile fail-fast via `tests/common/lib/guard.sh`）
  - metrics fan-out abstraction（backward-compat；K8s/crossregion 用 logical host id）
  - Makefile 三 phase target（plan ✓、deploy/run 視 phase 完成度 exit 1）
  - `verify-readme-gates.sh` 新增 P4f「phase scope contamination」check
  - codex review 環節走完 v1 → v2 (approve-with-constraints) → v3 (changes-required) → v4 (approve)

---

## §6. 新議題（2026-06-05 補充）

> 對應文件：[`0605.md`](./0605.md) §0 討論項目（commit `9dc0231`）

1. **CPU ~80% 飽和條件下，調整 process/thread/admission 參數的目的為何？** ⏳
   - 背景：TiDB / YBDB 4 vCPU 已 CPU-bound（~95% / ~92%）；CRDB rc 是 IO-bound 例外
   - 論述：A 池大小 / C memory budget / D split guardrails 三類服務 controlled experiment 而非 throughput tuning；只有 B admission control 在飽和下直接改 throughput
   - 待決：(a) 寫入 PoC-DESIGN §「硬體飽和假設」？ (b) README 主表加註？ (c) pipeline-log template `db-config-dump` 段標明「dump 出來只供 controlled experiment 驗證」？

2. **§6.1 config dump 清單是否同步落地到 pipeline-log-template？** ⏳
   - 現況：pipeline-log-template `db-config` 只列 effective-config.txt + cluster-settings.txt；0605 §6.1 列更細的 dump 需求
   - 待決：(a) 寫入 template 為 mandatory checklist / (b) 補三家 `db-config-dump.sh` 對齊 / (c) 只在新測項追加

3. **三家參數不對等對 cross-DB comparison 的 caveat 寫法** ⏳
   - 不對等：TiDB/YBDB 顯式 thread pool；CRDB 無等價 knob（單 process）
   - 待決：(a) README 主表加 caveat 句 / (b) 顯式列三家不可調項 / (c) implicit 假設不寫

4. **§6.3 第 4 點「tuning track 與 baseline track 分離」是否立為 PoC-DESIGN 條款？** ⏳
   - 現況：TiDB l4r4 caveat 即「tuning 混入 baseline」反例（dispatch-records 2026-05-31）
   - 待決：(a) 寫入 PoC-DESIGN / (b) Track E 是否也適用 / (c) 連動 §12 A2/A3：l4r4 caveat 是否拉出 baseline 獨立 tuning cell
