# YugabyteDB vm-3node Dispatch Summary

> **彙整** YugabyteDB 在 vm-3node 拓樸下所有 dispatch records、踩坑修補、跨 cell 分析、Leader-balance verification；底層 raw records 保留於本目錄，供細節查閱。

---

## TL;DR

| 指標 | 結果 |
|---|---|
| 完成 cells | **5 / 5**（1s1r / 1s3r / 3s1r / 3s3r / haproxy-3s3r）|
| 樣本數 | N=1（對外結論前須 N=3）|
| Best mean tpmC | **15,632 @ haproxy-3s3r t=128**（vs direct 3s3r +79.1%）|
| Best p99 | 90 ms @ 1s1r t=16；705 ms @ haproxy-3s3r t=128 |
| 主要 Fixes | YBDB vm3 a/b/c（serial join + stabilize position + RF-aware gate）+ `SPLIT INTO 3 TABLETS` pre-create 修法 |
| 主要踩坑 | parallel `yugabyted --join` 造成 tserver_master_addrs 不一致 → LookupByIdRpc cascade；RF=1 placement 只覆蓋 1 tserver（不是 3 tservers × 1 = 3）|

---

## 5-cell 測試結果（canonical TS、5-round mean）

| Cell | TS | best @ t | tpmC | NO p99 (ms) | stddev | 來源目錄 |
|---|---|:---:|---:|---:|---:|---|
| 1s1r | `20260524T032814+0800` | t=32 | **13,702** | 205 | ≤608 | [vm-3node-1s1r-rc/](../yuga-tc1/S-BASE/vm-3node-1s1r-rc/ybdb-vm-3node-1s1r-rc-20260524T032814+0800/) |
| 1s3r | `20260524T074754+0800` | t=128 | 10,228 | 1,034 | ≤86 | [vm-3node-1s3r-rc/](../yuga-tc1/S-BASE/vm-3node-1s3r-rc/ybdb-vm-3node-1s3r-rc-20260524T074754+0800/) |
| 3s1r | `20260524T202219+0800` | t=32 | 11,967 | 203 | ≤142（最穩）| [vm-3node-3s1r-rc/](../yuga-tc1/S-BASE/vm-3node-3s1r-rc/ybdb-vm-3node-3s1r-rc-20260524T202219+0800/) |
| 3s3r | `20260525T031918+0800` | t=128 | 8,729 | 1,114 | **1,400-2,615**（極不穩）| [vm-3node-3s3r-rc/](../yuga-tc1/S-BASE/vm-3node-3s3r-rc/ybdb-vm-3node-3s3r-rc-20260525T031918+0800/) |
| **haproxy-3s3r** | `20260525T193740+0800` | t=128 | **15,632** | **705** | 178-401（14.7× 改善）| [vm-3node-haproxy-3s3r-rc/](../yuga-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/) |

---

## 執行 Journey 時序

| 階段 | 日期 | 事件 | 引用 |
|---|---|---|---|
| Pre-check | 2026-05-22 | vm-3node RC pre-flight（三家共用） | [2026-05-22-vm-3node-rc-pre-check.md](./2026-05-22-vm-3node-rc-pre-check.md) |
| Handover | 2026-05-24 | vm-3node 剩餘任務交接清單 | [HANDOVER-2026-05-24-vm3-poc-remaining.md](./HANDOVER-2026-05-24-vm3-poc-remaining.md) |
| Cell 1s1r 首跑 | 2026-05-23 | 第一個 vm-3node cell；踩 LookupByIdRpc / kResponseSent timeout cascade（parallel `yugabyted --join` 導致 tserver_master_addrs 不一致）；同時發現 `SPLIT INTO 1 TABLETS` pre-create 對 RF=1 placement 只覆蓋 1 tserver（不是「自然 3 tablets」）→ 需顯式 `SPLIT INTO 3 TABLETS` | [2026-05-23-vm-3node-ybdb-1s1r-rc-result.md](./2026-05-23-vm-3node-ybdb-1s1r-rc-result.md) |
| Playbook 修補 | 2026-05-23/24 | commit `d654824`（serial worker join + stabilize + master_addrs gate）；`68189bc`（stabilize 移至 workers-only，在 `configure data_placement` 之後）；`29b5fc5`（RF-aware cluster health gate + drop ineffective stabilize-workers） | commit log |
| Cells 1s1r / 1s3r / 3s1r / 3s3r 全跑 | 2026-05-24 ~ 05-25 | 4 cells × N=1，5-round mean；3s3r 首跑中斷一次（cold-reset 失敗）後 2026-05-25 重跑成功 | [2026-05-25-vm-3node-ybdb-all4-rc-analysis.md](./2026-05-25-vm-3node-ybdb-all4-rc-analysis.md) |
| HAProxy 變體 dispatch | 2026-05-25 | 3 tservers + HAProxy round-robin 量化分散收益；首次 dispatch 因 coldreset-ybdb.sh 漏 patch 中斷 → 用新 TS `20260525T193740+0800` 重跑成功 | [2026-05-25-vm-3node-haproxy-3s3r-ybdb-dispatch.md](./2026-05-25-vm-3node-haproxy-3s3r-ybdb-dispatch.md) |
| HAProxy 跨 cell 分析 | 2026-05-26 | direct vs haproxy 3s3r 對照：+79.1% tpmC / −36.7% p99 / 14.7× stability 改善 | [2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md](./2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md) |
| D10 leader balance verification | 2026-05-31 | first-hand 驗證 YBDB 3s3r 在 default `--enable_load_balancing=true` 下 27 tablet leaders 收斂至 **9/9/9 per tserver**（零偏差）；對比 TiDB 同期 27/0/0 全集中（D10 修補前狀態）| [2026-05-31-ybdb-leader-balance-verification.md](./2026-05-31-ybdb-leader-balance-verification.md) + [check artifact](./2026-05-31-ybdb-leader-balance-check/) |

---

## Fixes Catalog（YugabyteDB-specific）

| ID | Commit | 症狀 | 根因 | 修補 |
|:---:|---|---|---|---|
| **YBDB vm3 a** | `d654824` | parallel `yugabyted --join` 觸發 LookupByIdRpc / kResponseSent timeout cascade；tserver_master_addrs 不一致 | 多 worker tserver 同步 join primary master 造成 race | ansible playbook 加 `serial: 1` on Join workers；新增 master_addrs gate + stabilize step |
| **YBDB vm3 b** | `68189bc` | stabilize-workers step 在 `configure data_placement` 之前執行 → placement 還沒 ready 就驗 | step 順序錯置 | stabilize 移至 workers-only，在 `configure data_placement` 之後 |
| **YBDB vm3 c** | `29b5fc5` | dry-run-confirm cluster health gate 不認 RF=1（只覆蓋 1 tserver） | gate 假設「3 tservers 全 ALIVE」對 RF=1 不適用 | 改 RF-aware：master raft alive = expected_rf；3 tservers ALIVE heartbeating（必驗）；每 tserver cmdline ≥ 1 raft master endpoint |
| **SPLIT INTO N TABLETS pre-create** | （在 `tests/common/prepare.sh` 內 sed schema file） | 原以為「3 tservers × `ysql_num_shards_per_tserver=1` = 3 tablets 自然」**錯**：`yugabyted configure data_placement --rf=1` 之後 placement 只覆蓋 1 tserver，table 預設 tablets = 1 × 1 = 1 | YBDB placement 對 RF=1 與 RF=3 行為不同；自然 shard 數不可控 | `prepare.sh` 用 sed 把 schema file 的 `SPLIT INTO 1 TABLETS` 替換為 `SPLIT INTO 3 TABLETS`（covers 1s/3s 兩種 case） |
| **3s3r coldreset 中斷** | （coldreset-ybdb.sh patch） | 2026-05-25 首次 3s3r dispatch 在 run phase cold-reset 失敗，prepare 跑完 50 min 才掛 | coldreset-ybdb.sh 對 ybdb-vm3 拓樸不完整 | patch + 用新 TS `20260525T193740+0800` 重跑成功 |

---

## 跨 cell 主要發現

1. **變數獨立成本拆解**（與其他 DB 對標）：
   - **RF=1→3** @ 1-shard, t=128: **−25.5% tpmC** / +36% NO_p99（Raft replication 三副本固定成本）
   - **1-shard→3-shard** @ RF=1, t=32: **−12.7% tpmC** / −1% NO_p99（sharding 純成本 ~13%）
   - **疊加** (1s1r → 3s3r, t=128): **−36.4% tpmC** / +47% NO_p99（RF + shard 成本疊加）
2. **3s3r 在 4 vCPU 上極不穩**：t=32/64 CPU idle 高達 24–42% 但 throughput 反而 drop → workload 卡 tablet/raft 協調而非 CPU；27 tablets × 3 replicas = **81 replicas on 4 vCPU**。生產配置需 vCPU ≥ 8。
3. **代表點選擇分歧**：1s1r/3s1r 在 t=32 飽和（CPU idle 7-9%），1s3r/3s3r 推到 t=128 才 plateau。
4. **YBDB Leader balance default 自動均衡**：3s3r 27 leaders → **9/9/9 per tserver**（零偏差），對比 TiDB 同期 27/0/0（D10 修補前）— YugabyteDB `--enable_load_balancing` 預設 true，不踩 TiDB 同坑。
5. **HAProxy 紅利 +79.1%**（direct 8,729 → haproxy 15,632 @ t=128）+ **14.7× stability 改善**（direct stddev 2,615 → haproxy 178）：分散 connect 解決 tserver 協調過載 + outlier 抑制。

---

## Source Dispatch Records（細節索引）

| 文件 | 焦點 |
|---|---|
| [2026-05-22-vm-3node-rc-pre-check.md](./2026-05-22-vm-3node-rc-pre-check.md) | vm-3node pre-flight check（三家共用）|
| [HANDOVER-2026-05-24-vm3-poc-remaining.md](./HANDOVER-2026-05-24-vm3-poc-remaining.md) | vm-3node 剩餘任務交接清單 |
| [2026-05-23-vm-3node-ybdb-1s1r-rc-result.md](./2026-05-23-vm-3node-ybdb-1s1r-rc-result.md) | 1s1r 首跑 LookupByIdRpc / placement 踩坑紀錄 |
| [2026-05-25-vm-3node-haproxy-3s3r-ybdb-dispatch.md](./2026-05-25-vm-3node-haproxy-3s3r-ybdb-dispatch.md) | HAProxy 3s3r dispatch 與 first-dispatch 中斷處置 |
| [2026-05-25-vm-3node-ybdb-all4-rc-analysis.md](./2026-05-25-vm-3node-ybdb-all4-rc-analysis.md) | 4 cells（1s1r/1s3r/3s1r/3s3r）跨 cell 對標分析 — 含變數獨立成本拆解 |
| [2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md](./2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md) | HAProxy vs direct 3s3r 對照（+79.1% tpmC、14.7× stability）|
| [2026-05-31-ybdb-leader-balance-check/](./2026-05-31-ybdb-leader-balance-check/) | Leader balance verification 原始檢查 artifact |
| [2026-05-31-ybdb-leader-balance-verification.md](./2026-05-31-ybdb-leader-balance-verification.md) | D10 first-hand verification：27 leaders → 9/9/9 per tserver |

---

## 下一步（建議）

1. **`haproxy-3s3r` 補 N=3**（~3h × 3 = 9h）→ 升級為對外可引用 baseline
2. **DB-host metrics fan-out**（README §A.4 caveat C3）：補 .33/.34 mpstat-db / iostat-1s-db 採集，跨節點負載 / placement skew 看得見
3. **YugabyteDB Kubernetes 變體 v4.7 重跑**（unlimit / limit 各一）
4. **3s3r 在 vCPU ≥ 8 重做**：驗證「4 vCPU 不適合 3s3r」的硬體假設
5. **跨區 IDC↔GCP 規劃**：見 [`1_MeetingMinutes/0602.md §10`](../../1_MeetingMinutes/0602.md)
