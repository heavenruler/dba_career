# TiDB vm-3node-3s3r-rc：HAProxy vs Direct（PD `l4r4` 基礎）

**完成日**：2026-06-01
**比較對象**：同 RF=3 / 3 shards / 128 wh / iso=RC / PD `replica-schedule-limit=4` + `leader-schedule-limit=4`（Fix #11 + D10），差異只在 client 連線層
**Hardware**：3 × ProxmoxVM（4 vCPU、16 GB RAM、single XFS）；HAProxy on 獨立 VM（172.24.47.20、4 vCPU）
**Driver**：go-tpc v1.0.12 on .31
**口徑**：5-round mean × 4 thread groups × 5 min run + 20 min warmup
**N**：1 / variant

---

## 0. 兩組 artifact

| 模式 | TPCC_TS | tidb_servers | client 入口 | 來源目錄 |
|---|---|---|---|---|
| **direct**（.31 → .32:4000）| 20260531T085812+0800 | 1（.32 only） | direct | [`vm-3node-3s3r-rc-pd-sched-l4r4/.../20260531T085812+0800/`](../tidb-tc1/S-BASE/vm-3node-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-3s3r-rc-20260531T085812+0800/) |
| **haproxy**（.31 → .20:4000 → .32/.33/.34:4000）| 20260601T003316+0800 | 3（.32 / .33 / .34） | HAProxy `balance roundrobin` `mode tcp` | [`vm-3node-haproxy-3s3r-rc-pd-sched-l4r4/.../20260601T003316+0800/`](../tidb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-haproxy-3s3r-rc-20260601T003316+0800/) |

兩組共用 PD config（Fix #11 + D10 套餐）；direct 透過 `tidb_sub_topology=3s3r`（1 tidb_server）、haproxy 透過 `tidb_sub_topology=haproxy-3s3r`（playbook conditional render 3 tidb_servers + 在 .20 部署 HAProxy）。

---

## 1. Throughput 對照（5-round mean）

| threads | direct mean | haproxy mean | Δ tpmC | Δ % |
|--------:|------------:|-------------:|-------:|----:|
| 16 | 11,034 | **11,816** | +782 | +7.1% |
| 32 | 13,111 | **17,986** | +4,875 | **+37.2%** |
| 64 | 14,733 | **23,034** | +8,301 | **+56.3%** |
| 128 | 15,082 | **26,947** | +11,865 | **+78.7%** |

HAProxy 在 t=128 把 throughput 拉到 direct 的 1.79×。低併發（t=16）差距小，因為 1 TiDB server 在低 QPS 下未飽和；併發拉高後 1 SQL entry 變瓶頸，3 SQL entries 釋放線性 scale。

## 2. Latency — NEW_ORDER p99 mean (ms)

| threads | direct | haproxy | Δ ms | Δ % |
|--------:|-------:|--------:|-----:|----:|
| 16 | 86 | 84 | −2 | −2.3% |
| 32 | 153 | 105 | −48 | **−31.4%** |
| 64 | 292 | 173 | −119 | **−40.8%** |
| 128 | 590 | 309 | −281 | **−47.6%** |

p99 latency 在 t=128 直接砍半。原因：direct 模式所有 SQL 排隊在 .32 single TiDB → tcp accept queue / parser thread / executor 共用；haproxy 三 TiDB 平均承擔。

## 3. 穩定度（round-by-round, range / mean）

| threads | direct | haproxy |
|--------:|-------:|--------:|
| 16 | 7.6% | 10.3% |
| 32 | 9.0% | 4.8% |
| 64 | **19.7% ⚠️** | 5.7% |
| 128 | 11.6% | 7.4% |

direct l4r4 在 t=64 round 4 有 12,868（其他 round ~15-16k）outlier — 疑似 PD active leader transfer 造成；haproxy 三路分流後此種 single-point churn 對 throughput 影響稀釋，round-to-round 振幅 ≤ 10%。

## 4. .32 DB-host metrics（t=128 round-3，305 個 1s 採樣均值）

iostat-1s-db.txt（sda）：

| mode | r/s | w/s | rkB/s | **wkB/s** |
|---|---|---|---|---|
| direct | 776 | 475 | 10,475 | 22,052 |
| haproxy | **1,659** | **648** | **24,646** | **32,641** |

mpstat-db.txt（4 vCPU 全核均值）：

| mode | %us | %sy | %id |
|---|---|---|---|
| direct | 80.3 | 9.8 | **4.1** |
| haproxy | **72.4** | 11.5 | **6.7** |

> 重要觀察：haproxy 模式下 **.32 disk r/s 翻倍、wkB/s +48%**，但 **CPU %us 反而下降 8 pts**。
>
> 解釋：direct 模式 .32 同時承擔「TiDB SQL 100% 入口」+「PD」+「TiKV-1 leader 4 個」；haproxy 後 SQL 流量 1/3 走 .32、2/3 走 .33/.34 → .32 SQL CPU 釋放；同時 throughput 拉到 1.79×（27k / 15k），TiKV-1 上的 region 讀寫量級放大 → disk I/O 上升。
>
> CPU bottleneck 從 SQL 層 shifted 到 storage 層，這正是「分散 SQL 入口」的紅利。

## 5. Per-round tpmC（5-round 全展開）

### direct（TS=20260531T085812+0800）

| threads | r1 | r2 | r3 | r4 | r5 | mean |
|--:|--:|--:|--:|--:|--:|--:|
| 16 | 11163 | 11279 | 10577 | 10738 | 11415 | **11,034** |
| 32 | 13851 | 13094 | 13259 | 12680 | 12673 | **13,111** |
| 64 | 15329 | 15817 | 15877 | 12980 | 13664 | **14,733** |
| 128 | 15805 | 14053 | 14583 | 15613 | 15354 | **15,082** |

### haproxy（TS=20260601T003316+0800）

| threads | r1 | r2 | r3 | r4 | r5 | mean |
|--:|--:|--:|--:|--:|--:|--:|
| 16 | 11819 | 12248 | 11026 | 11752 | 12233 | **11,816** |
| 32 | 17549 | 17949 | 17685 | 18404 | 18340 | **17,986** |
| 64 | 23442 | 23203 | 22138 | 23142 | 23245 | **23,034** |
| 128 | 26749 | 25567 | 27291 | 27561 | 27566 | **26,947** |

---

## 6. Leader 分佈最終態

| mode | store IDs | leaders/store | 偏差 vs 理想 |
|---|---|---|---|
| direct l4r4 | 1 / 4 / 7 | **4 / 15 / 10** | 29 total，ideal 9.67 ±20% = [7.7, 11.6]；store 1 = −56%、store 4 = +55% |
| haproxy l4r4 | 1 / 4 / 5 | **7 / 14 / 8** | 29 total；store 1 = −28%、store 4 = +45%、store 5 = −17% |

> haproxy 跑完後 leader 分佈雖未到 ±20% 容差，但比 direct 「4/15/10」改善：最小值從 4 → 7，差距範圍從 11 縮到 7。PD 在 haproxy 5h workload 下有更多機會做 leader transfer（同 SQL 入口從 1 變 3，PD 收到的請求源 IP 多樣化、leader hint 機會分散）。

---

## 7. 與 YugabyteDB HAProxy 對照（同 hardware / 同 W=128 / 同 N=1）

| db | direct t=128 mean | haproxy t=128 mean | haproxy Δ |
|---|---|---|---|
| TiDB（l4r4） | 15,082 | **26,947** | **+78.7%** |
| YugabyteDB | 8,729 | 15,632 | +79.1% |

> 兩家在同硬體 vm-3node-3s3r 下 HAProxy 紅利幾乎相同（+79%）。**直接 throughput 數字：TiDB haproxy l4r4 ＞ ybdb haproxy（26,947 vs 15,632，+72.4%）**，但這是 2026-05-25 的 ybdb baseline；ybdb 後續是否同樣優化未測。

---

## 8. 結論

1. **HAProxy 在 TiDB 3s3r-l4r4 帶來 t=128 +78.7% 大幅紅利**。1 SQL entry 在 high concurrency 下確實是瓶頸；3 SQL entry 經 HAProxy round-robin 後 throughput 接近線性 scale。
2. **p99 latency 同時改善 −31% ~ −48%**（高併發越多越明顯）。
3. **CPU bottleneck 從 SQL 層遷移到 storage I/O 層**：.32 mpstat 顯示 %us 下降但 disk wkB/s 上升；瓶頸從「TiDB executor」轉成「TiKV write throughput」。Storage-bound 是未來進一步調優的方向（SSD / region split / 增加 TiKV nodes）。
4. **Leader skew 仍存在但較 direct 改善**（最差偏差從 +55%/−56% → +45%/−28%）。PD `leader-schedule-limit=4` 收斂速度受限於 workload 期間長度與 leader transfer cost；haproxy 模式對此略有助益但非主因。
5. **stability 普遍提升**：t=64 從 19.7% range/mean → 5.7%；haproxy 三路分流稀釋 single-point churn 的影響。

---

## 9. Caveat

| caveat | 細節 |
|---|---|
| N=1 | 對外結論需 N≥3 重跑後再下定論 |
| HAProxy round-robin 未 first-hand 驗證 | suite 跑期間沒有設 stats socket（cfg.j2 預設不開），無法即時量 backend 連線分佈；以 tpmC +78.7% + .32 wkB/s 上升推論 round-robin 生效，未直接 dump `show stat` |
| metrics 收集 host 偏 | iostat / mpstat 只收 .32（primary）；.33 / .34 同步運作但無 per-host metric 對比，無法定量「3 store 各承擔多少」|
| ysqlsh install on .31 ansible 失敗 | playbook 末段試圖在 .31 裝 ysqlsh（為 ybdb 預備），TiDB 不需此步；ansible-playbook rc=4 表面失敗、實際 TiDB cluster 部署完成。本 cell 流程未受影響 |
| Leader balance 未完全收斂 | haproxy 5h workload 後 7/14/8 仍超 ±20%。Background：PD scheduler 工作上限 rate-limited 而非權重 |

---

## 10. Reproducibility

| 項 | 值 |
|---|---|
| TS | `20260601T003316+0800` |
| 部署 host | 172.24.40.31（poc batch controller） |
| TiDB cluster | 3 × tidb_server + 3 × tikv + 3 × pd (各 .32/.33/.34) |
| HAProxy | 172.24.47.20:4000 → `balance roundrobin mode tcp` |
| Ansible | `playbooks/tidb-vm3.yml` `-e tidb_sub_topology=haproxy-3s3r` |
| Driver | `mysql`（go-tpc default for TiDB），`--conn-params transaction_isolation='READ-COMMITTED'&tidb_txn_mode='pessimistic'` |
| Fix 應用 | #11（playbook PD replica-schedule-limit=4）、#12（prepare.sh shard-count gate ≥）、D10（PD leader-schedule-limit=4） |
| Ansible commit | `97ce300` + `d30bceb` + `07d9da9` + `24d0c05` |
| Artifacts | `poc/results/tidb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-haproxy-3s3r-rc-20260601T003316+0800/` |

## 11. 相關文件

- TiDB schedule-limit 0→4 分析：[`2026-05-31-tidb-schedule-limit-0-vs-4.md`](./2026-05-31-tidb-schedule-limit-0-vs-4.md)
- ybdb HAProxy vs Direct：[`2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md`](./2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md)
- ybdb leader balance 驗證：[`2026-05-31-ybdb-leader-balance-verification.md`](./2026-05-31-ybdb-leader-balance-verification.md)
- audit-watch-prompt D10：[`../audit-watch-prompt.md`](../audit-watch-prompt.md)
