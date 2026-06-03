# TiDB vm-3node Dispatch Summary

> **彙整** TiDB 在 vm-3node 拓樸下所有踩坑修補、跨 cell 分析；本檔保留可引用的 journey、fixes、數據摘要與分析入口；已清理的 raw / operational logs 僅透過 git history 追溯。

---

## TL;DR

| 指標 | 結果 |
|---|---|
| 完成 cells | **5 / 5**（1s1r / 1s3r / 3s1r / 3s3r / haproxy-3s3r）|
| 樣本數 | N=1（對外結論前須 N=3；見 [README N9](../README.md#note-N9)）|
| Best mean tpmC | **26,947 @ haproxy-3s3r t=128**（vs direct 3s3r `l4r4` +78.7%） |
| Best p99 | 309 ms @ haproxy-3s3r t=128 |
| 主要 Fixes | D10 / Fix #9 / #10 / #11 / #12（共 5 項）|
| 主要踩坑 | PD `l0r0` 退化為 RF=1 假 baseline → 修為 `l4r4`；CLUSTERED PK 不能用 `SPLIT TABLE INDEX PRIMARY` → 改顯式分裂點；shard-count gate 嚴格比較與 auto-split 衝突 |

---

## 5-cell 測試結果（canonical TS、5-round mean）

> 「代表點 @ t」採「mean tpmC 最大且不撞極端 latency」原則；本批主表使用 t=128（3s1r 例外用 t=64，t=128 已開始撞 latency 翻倍 + range/mean 23.8%）。Source: 5 個 `summary.json` 由 [`tests/common/summary-from-stdout.py`](../../tests/common/summary-from-stdout.py) 從 raw stdout 產生。

| Cell | TS | 代表點 @ t | tpmC | NO p99 (ms) | range/mean | error rate | 來源目錄 |
|---|---|:---:|---:|---:|---:|---:|---|
| 1s1r | `20260529T132940+0800` | t=128 | 19,654 | 456 | 7.0% | 0.000% | [vm-3node-1s1r-rc/](../tidb-tc1/S-BASE/vm-3node-1s1r-rc/tidb-vm-3node-1s1r-rc-20260529T132940+0800/) |
| 1s3r `l4r4` | `20260530T162428+0800` | t=128 | 16,336 | 527 | 1.6% | 0.000% | [vm-3node-1s3r-rc-pd-sched-l4r4/](../tidb-tc1/S-BASE/vm-3node-1s3r-rc-pd-sched-l4r4/tidb-vm-3node-1s3r-rc-20260530T162428+0800/) |
| 1s3r `l0r0` (broken) | `20260529T170933+0800` | t=128 | 14,130 | 567 | — | — | [vm-3node-1s3r-rc-pd-sched-l0r0/](../tidb-tc1/S-BASE/vm-3node-1s3r-rc-pd-sched-l0r0/tidb-vm-3node-1s3r-rc-20260529T170933+0800/) |
| 3s1r | `20260530T023238+0800` | t=64 | 16,580 | 270 | 15.6% | 0.000% | [vm-3node-3s1r-rc/](../tidb-tc1/S-BASE/vm-3node-3s1r-rc/tidb-vm-3node-3s1r-rc-20260530T023238+0800/) |
| 3s3r `l4r4` | `20260531T085812+0800` | t=128 | 15,082 | 591 | 11.6% | 0.000% | [vm-3node-3s3r-rc-pd-sched-l4r4/](../tidb-tc1/S-BASE/vm-3node-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-3s3r-rc-20260531T085812+0800/) |
| 3s3r `l0r0` (broken) | `20260530T061352+0800` | t=128 | 20,455 | 423 | — | — | [vm-3node-3s3r-rc-pd-sched-l0r0/](../tidb-tc1/S-BASE/vm-3node-3s3r-rc-pd-sched-l0r0/tidb-vm-3node-3s3r-rc-20260530T061352+0800/) |
| **haproxy-3s3r** `l4r4` | `20260601T003316+0800` | t=128 | **26,947** | **309** | 7.4% | 0.000% | [vm-3node-haproxy-3s3r-rc-pd-sched-l4r4/](../tidb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-haproxy-3s3r-rc-20260601T003316+0800/) |

> **`l0r0` 為 broken baseline**（PD `replica-schedule-limit=0` + `leader-schedule-limit=0`，實際 RF=1、leader 集中單 store）— 不入主表，僅作 caveat 對照。
>
> 主表只列 **`l4r4`** 結果（Fix #11 + D10 修補後）。

---

## 執行 Journey 時序

| 階段 | 日期 | 事件 | 引用 |
|---|---|---|---|
| Initial batch | 2026-05-29 | TiDB vm-3node 4-cell batch（含 prepare/SPLIT 踩坑：CLUSTERED PK 無法 `INDEX PRIMARY` 分裂、warehouse 42 keys < 1000 觸發 ERROR 8212）→ Fix #9 / Fix #10 | commit `9fb9e5f` / `a35142d`（見下方 Fixes Catalog） |
| Schedule-limit 修補 | 2026-05-30/31 | PD `l0r0` 跑出來實際 RF=1（leader 27/0/0 全集中單 store）→ D10 / Fix #11 → 1s3r/3s3r 重跑 `l4r4` variant；shard-count gate 嚴格 `==` 與 auto-split 衝突 → Fix #12 | [2026-05-31-tidb-schedule-limit-0-vs-4.md](./2026-05-31-tidb-schedule-limit-0-vs-4.md) |
| HAProxy 變體 | 2026-06-01 | 3 tidb_servers + HAProxy round-robin (mode tcp)，量化 single-entry → multi-entry 紅利；vs direct `l4r4` +78.7% tpmC / −47.6% p99 | [2026-06-01-tidb-haproxy-vs-direct-3s3r-l4r4.md](./2026-06-01-tidb-haproxy-vs-direct-3s3r-l4r4.md) |

---

## Fixes Catalog（TiDB-specific）

| ID | Commit | 症狀 | 根因 | 修補 |
|:---:|---|---|---|---|
| **Fix #9** | `9fb9e5f` | `SPLIT TABLE ... INDEX PRIMARY` 對 CLUSTERED PK 表觸發 ERROR 1176 「split clustered index」 | TiDB v5.0+ default CLUSTERED PK；clustered index 無顯式 secondary index 可 split | 改用 `SPLIT TABLE ... BY (point1), (point2)` 顯式分裂點（去除 INDEX clause） |
| **Fix #10** | `a35142d` | `SPLIT TABLE ... BETWEEN/REGIONS` 對 warehouse（128 rows / 3 = 42 keys per region）觸發 ERROR 8212 「region size is too small」 | BETWEEN/REGIONS 要求每結果 region ≥ 1000 keys；小表撞牆 | 改用 `SPLIT TABLE ... BY` 顯式分裂點 `BY (43),(86)` |
| **D10** | `97ce300` | vm-3node 3s3r 跑完最終 leader 分佈 27 / 0 / 0（全集中單 store） | `tidb-vm3.yml` 寫死 PD `leader-schedule-limit=0`（沿用自 vm-1node 未調整） | vm-3node 改回 PD 預設 `4`；vm-1node 保留 0 |
| **Fix #11** | `d30bceb` + `07d9da9` | `replication.max-replicas=3` 但實際 region peer count = 1（假 RF=3） | PD `replica-schedule-limit=0` → PD 不做 make-up-replica；+ ansible shell task 用 `/bin/sh` 不支援 process substitution `<()` | 改 `replica-schedule-limit=4` + ansible task 加 `executable: /bin/bash`；dry-run-confirm 新增 actual peer count gate |
| **Fix #12** | `24d0c05` | shard-count gate 嚴格 `actual == EXPECTED_SHARDS`；3s3r `l4r4` 跑完 RF=3 真實生效後 order_line auto-split 3→4，整 cell fail-closed 報廢 | TiKV auto-split 對熱點 region 自動加切，與 strict gate 衝突 | gate 改 `actual >= EXPECTED_SHARDS`（SPLIT 為保底，allow auto-split 加 region） |

> 完整 commit 描述見 `git log --grep="Fix #9\|Fix #10\|Fix #11\|Fix #12\|D10"`。

---

## 跨 cell 主要發現

1. **Sweet spot 全 cell 落在 t=128**：不同 vm-1node（t=64 為 sweet spot）；3-node 分散 SQL/storage 後 worker queue 容量提升。
2. **PD `l4r4` 是 mixed state，非 steady-state baseline**：3s3r 跑完 leader 分佈 4/15/10 仍超 ±20% 容差；`leader-schedule-limit=4` 是 rate-limit 非 weight，5h workload 未足以全收斂。
3. **HAProxy 紅利 +78.7%**（direct 15,082 → haproxy 26,947 @ t=128）：3 tidb_servers 分擔 SQL 接收層 → .32 CPU `%us` 80.3 → 72.4%；.32 disk wkB/s 22,052 → 32,641（throughput 拉升 → storage 變主瓶頸）；leader 分佈 7/14/8（vs direct 4/15/10）較平均。
4. **`l0r0` 數字無法作正式 baseline**：3s3r `l0r0` 跑出 20,455 tpmC（甚至比 `l4r4` 高 36%），是「3 stores 中只有 1 個在工作」的退化拓樸 — 高 tpmC 反映「無 Raft replication overhead + 單 store local I/O」的人工捷徑，**不是真 RF=3 throughput**。
5. **Stability vs throughput trade-off**：t=128 `l4r4` direct range/mean 11.6%，haproxy 改善為 7.4%（分散負載降低 round-to-round 波動）。

---

## Source Dispatch Records（細節索引）

| 文件 | 焦點 |
|---|---|
| [2026-05-31-tidb-schedule-limit-0-vs-4.md](./2026-05-31-tidb-schedule-limit-0-vs-4.md) | PD schedule-limit `l0r0` vs `l4r4` 跨 cell 對照（含 1s3r/3s3r 兩 variant）|
| [2026-06-01-tidb-haproxy-vs-direct-3s3r-l4r4.md](./2026-06-01-tidb-haproxy-vs-direct-3s3r-l4r4.md) | HAProxy vs direct 3s3r-`l4r4` 對照（含 .32 disk/CPU shift 證據）|

---

## 下一步（建議）

1. **`haproxy-3s3r-l4r4` 補 N=3**（~3h × 3 = 9h）→ 升級為對外可引用 baseline
2. **`l4r4` mixed state caveat 移入主表註腳**（[`results/README.md §A.4`](../README.md) 已標）
3. **TiDB Kubernetes 變體 v4.7 重跑**（unlimit / limit 各一）
4. **跨區 IDC↔GCP 規劃**：見 [`1_MeetingMinutes/0602.md §10 跨區 PoC（Track E）`](../../1_MeetingMinutes/0602.md#10-跨區-poctrack-e-詳細設計)
