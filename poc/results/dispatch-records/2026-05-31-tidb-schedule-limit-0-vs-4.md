# TiDB vm-3node — PD schedule-limit 0 vs 4 跨 cell 差異分析

**Scope**：TiDB v8.5.2 (tidb-tc1, S-BASE)；vm-3node 拓樸下 RC 隔離
**Date**：2026-05-31
**Sub-topologies 涵蓋**：`vm-3node-1s3r-rc`、`vm-3node-3s3r-rc`（兩組皆設計 RF=3）
**Variant pair**：`pd-sched-l0r0`（baseline，broken）vs `pd-sched-l4r4`（fixed）
**N**：1 per variant（共 4 cells）
**Cell 1（1s1r）／ Cell 3（3s1r）不在本對照範圍**（RF=1、無 leader balance 議題）

---

## 1. 為何需要這份對照

兩個 vm-3node config bug 同時發現於 2026-05-30 Cell 4 跨 cell 分析：

| Bug | PD config | 實際影響 |
|---|---|---|
| Fix #11 | `replica-schedule-limit=0` | PD 不做 make-up-replica → 雖然 `max-replicas=3`，每 region 實際 peer count=1（**RF=1 in practice，假 RF=3**）|
| D10 | `leader-schedule-limit=0` | PD 不 rebalance leader → vm-3node-3s3r-rc baseline 量到 27/0/0（全 leaders 集中單一 store）|

baseline（l0r0）資料因此**並非設計值 RF=3 的真實表現**，而是「配置故障下退化為單 store cluster」的數據。本對照量化：兩個 schedule-limit 0→4 同時開啟後，tpmC / latency / disk I/O 的真實變化。

> ⚠️ **變因為「套餐」**：本對照是 `replica + leader` 雙 schedule-limit **同時** 0→4，非單變因 A/B。若要切開兩變因，需再跑 `replica=4, leader=0` 一組（未執行）。

---

## 2. Config differential

| key | l0r0 baseline | l4r4 fixed |
|---|---|---|
| `pd.schedule.replica-schedule-limit` | `0` | `4` |
| `pd.schedule.leader-schedule-limit` | `0` | `4` |
| `pd.replication.max-replicas` | `3` | `3` |
| Region per region `MIN(peer_count)`（actual RF） | **1** | **3** |
| dry-run `actual-rf-peer-min` gate（Fix #11 dry-run） | n/a（gate 前置） | `3` |
| 3s3r 最終 leader 分佈（per store） | `27 / 0 / 0` | `4 / 15 / 10` |
| TiDB / PD / TiKV 版本 | v8.5.2 / 同 |（未變） |

ansible / playbook 來源：`poc/ansible/playbooks/tidb-vm3.yml`（commit `97ce300` 開啟 leader-rebalance；`d30bceb` 開啟 replica-rebalance + dry-run actual peer gate）。

---

## 3. tpmC 對照（5-round mean × 4 thread groups）

### 3.1 vm-3node-1s3r-rc

| threads | l0r0 mean | l4r4 mean | Δ (絕對) | Δ (%) |
|---|---|---|---|---|
| 16 | 10,856 | 11,199 | +343 | **+3.2%** |
| 32 | 12,532 | 14,765 | +2,233 | **+17.8%** |
| 64 | 13,823 | 15,309 | +1,486 | +10.7% |
| 128 | 14,130 | 16,336 | +2,206 | **+15.6%** |

l4r4 ≥ l0r0 全 thread 組。Fix #11 把 RF=3 真實開出，3 stores 同時負擔 region peer → 單一 SQL 入口下仍取得 sharding 紅利。

### 3.2 vm-3node-3s3r-rc

| threads | l0r0 mean | l4r4 mean | Δ (絕對) | Δ (%) |
|---|---|---|---|---|
| 16 | 14,041 | 11,034 | −3,007 | **−21.4%** |
| 32 | 18,130 | 13,111 | −5,019 | **−27.7%** |
| 64 | 19,997 | 14,733 | −5,263 | **−26.3%** |
| 128 | 20,455 | 15,082 | −5,373 | **−26.3%** |

l4r4 < l0r0 全 thread 組（−21~−28%）。**這不是退化，是還原真實成本**：l0r0 baseline 把所有 raft work / leader 集中於單 store，跑出「假 3-node 真 1-store」的 throughput；l4r4 開啟正確 Raft replication + leader balance 後，露出 3-replica commit + cross-store coord 的真實成本。

### 3.3 Round-by-round stability（range / mean）

| sub | variant | t=16 | t=32 | t=64 | t=128 |
|---|---|---|---|---|---|
| 1s3r | l0r0 | 11.9% | 15.8% | 15.4% | 9.6% |
| 1s3r | l4r4 | 12.1% | 5.8% | 31.5% ⚠️ | 1.6% |
| 3s3r | l0r0 | 7.5% | 3.9% | 4.6% | 3.5% |
| 3s3r | l4r4 | 7.6% | 9.0% | 19.7% ⚠️ | 11.6% |

l0r0「假 3-node」反而穩定（單 store 一切 deterministic）；l4r4 真 RF=3 + PD active rebalance 引入跨節點協調變異，t=64 round 4 兩組皆有 outlier。

### 3.4 NEW_ORDER p99 latency (5-round mean, ms)

| sub | variant | t=16 | t=32 | t=64 | t=128 |
|---|---|---|---|---|---|
| 1s3r | l0r0 | 85.6 | 151.0 | 273.5 | 567.1 |
| 1s3r | l4r4 | 84.7 | 138.4 | 275.1 | **526.8** |
| 3s3r | l0r0 | 73.8 | 123.3 | 228.2 | **422.8** |
| 3s3r | l4r4 | 85.6 | 152.7 | 291.9 | 590.5 |

1s3r：l4r4 p99 略降（更多 store 分擔 → 排隊降低）。
3s3r：l4r4 p99 全面上升（Raft commit + cross-store leader → 多一跳 RTT）。

---

## 4. Disk I/O — RF=3 真生效的物理證據

樣本：`runs/threads-128/round-3/iostat-1s-db.txt`，主機 .32（client entry / TiDB+PD+TiKV-1）。
305 個 1s 採樣均值：

| sub | variant | r/s | w/s | rkB/s | **wkB/s** |
|---|---|---|---|---|---|
| 1s3r | l0r0 | 1,579 | 573 | 22,853 | 21,167 |
| 1s3r | l4r4 | 940 | 500 | 11,804 | 18,450 |
| 3s3r | **l0r0** | **0** | **60** | **8** | **297** |
| 3s3r | l4r4 | 776 | 475 | 10,475 | 22,052 |

**3s3r l0r0 .32 幾乎沒寫入（wkB/s=297）**：所有 leader 與 raft 寫入都跑去 .33（或 .34），.32 只是 TiDB SQL 入口 / coord 流量。這正是 D10 觀察到的 27/0/0 leader 分佈在物理層的證據。

**3s3r l4r4 .32 寫入跳到 22,052 kB/s（~74×）**：Fix #11 + D10 後 .32 既持有 4 個 leader、又作為 RF=3 的 follower 接收另兩 store 的 raft 寫入。

1s3r l0r0 → l4r4 .32 read drops（22,853 → 11,804 kB/s）：l0r0 的 1 store 設計強迫所有 read 走 .32；l4r4 後 PD 把 leader 分散，read 也可從 .33/.34 leader 處服務。

---

## 5. 結論與適用範圍

1. **3s3r l0r0 baseline 不可作為對外 throughput 參考數字**。它代表「配置故障下退化為單 store」的 throughput，無法反映 3-replica TiDB 真實負載。
2. **1s3r l4r4 為 RF=3 + 單 SQL 入口的可信 baseline**（t=128 mean ≈ 16k）。
3. **3s3r l4r4 為 RF=3 + 3 SQL 入口的可信 baseline**（t=128 mean ≈ 15k）。
   3s3r vs 1s3r 在 l4r4 下差異很小（3 SQL 入口紅利被 leader-skew 4/15/10 吃掉，PoC 5h 內 PD 未完全收斂；leader balance 真正穩定後預期 3s3r 應 ≥ 1s3r）。
4. **任何用 l0r0 baseline 做的「sharding/replication 成本拆解」結論需重新計算**（在 §3.1、§3.2、§4.4 設計文件中相關段落需註記 "supersedes" 指向本檔）。

---

## 6. Caveat

| caveat | 細節 |
|---|---|
| 變因混合 | replica + leader schedule-limit 同時 0→4；非單變因 A/B |
| N=1 | 每 variant 跑 1 次；變異區間僅 round-to-round 內 |
| Leader balance 未完全收斂 | 3s3r l4r4 跑完最終 4/15/10，仍超出 D10 ±20% 容差。PD `leader-schedule-limit=4` 是 rate-limit、不是 weight；5h 工作負載未足以全收斂 |
| 1s3r l4r4 t=64 round 4 outlier | 12,868（rounds 1-3 ≥ 15k），疑似 PD 該段時間做 region split / leader transfer。未深查 |
| Auto-split | Fix #12（`shard-count gate >=`）後容許 TiKV 在 prepare 階段把 order_line 從 3 → 4 region；不影響 RF 計算 |
| Cell 1（1s1r）/ Cell 3（3s1r）未在本對照 | RF=1 設計，無 replica-schedule-limit / leader-schedule-limit 議題；數值見 `pipeline-log.md` |

---

## 7. Reproducibility — TS pointers

| sub | variant | TS | artifact dir |
|---|---|---|---|
| 1s3r | l0r0 | `20260529T170933+0800` | `poc/results/tidb-tc1/S-BASE/vm-3node-1s3r-rc-pd-sched-l0r0/tidb-vm-3node-1s3r-rc-20260529T170933+0800/` |
| 1s3r | l4r4 | `20260530T162428+0800` | `poc/results/tidb-tc1/S-BASE/vm-3node-1s3r-rc-pd-sched-l4r4/tidb-vm-3node-1s3r-rc-20260530T162428+0800/` |
| 3s3r | l0r0 | `20260530T061352+0800` | `poc/results/tidb-tc1/S-BASE/vm-3node-3s3r-rc-pd-sched-l0r0/tidb-vm-3node-3s3r-rc-20260530T061352+0800/` |
| 3s3r | l4r4 | `20260531T085812+0800` | `poc/results/tidb-tc1/S-BASE/vm-3node-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-3s3r-rc-20260531T085812+0800/` |

修法 commits：
- `97ce300` — `tidb-vm3.yml`：`leader-schedule-limit 0 → 4`（D10）
- `d30bceb` — `tidb-vm3.yml`：`replica-schedule-limit 0 → 4` + dry-run actual peer count gate（Fix #11）
- `07d9da9` — `tidb-vm3.yml`：ansible shell task `/bin/bash` for process substitution（Fix #11 amend）
- `24d0c05` — `prepare.sh`：shard-count gate accepts `actual >= expected`（Fix #12）

每個 cell 完整艙料：`.suite.done`, `.run.done`, `.collect.done`, `.gate*.done`, `db-config/`, `dry-run/`, `env/`, `gate/`, `prepare/`, `runs/threads-{16,32,64,128}/round-{1..5}/{go-tpc-stdout,iostat-1s,iostat-1s-db,mpstat,mpstat-db,vmstat-1s,vmstat-1s-db,sar-net,sar-net-db,free-1m}.txt`。
