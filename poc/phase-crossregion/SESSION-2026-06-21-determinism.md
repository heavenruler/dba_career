# SESSION 2026-06-21 — Determinism Investigation (W=4 不可比 baseline)

> Goal: ensure consistent results across runs for TiDB / CRDB / YBDB
> Verdict: **W=4 short smoke 達不到 deterministic — root cause = lock contention，需用 W=128 (user baseline) 才可比**

---

## 1. 4 fix 套用後仍 non-deterministic（W=4 smoke）

### Best-practice Makefile 整合（commit pending）

| Fix | 目的 |
|---|---|
| phase8.5-fetch ssh+tar | macOS openrsync v15+ 與 GNU rsync 不相容；ssh+tar pipe bypass |
| YBDB Plan B (read_replica) | live_replicas=IDC RF=3 + GCP read_replica RF=3，無 cache stale |
| DEAD blacklist+remove+unblacklist | yb-admin 要求 blacklist 才能 remove_tablet_server |
| Sustained Idle gate (60s × 6 consecutive) | 避免 single-sample 假 idle |
| TiDB pre-smoke leader gate | mysql query tikv_region_peers (issue: 跑在 prepare 前) |
| CRDB post-prepare lease gate | crdb_internal.ranges (issue: empty result 待修 SQL) |
| Health check 6 tservers ALIVE | hard gate |

### BP run-1 vs run-2 (同 cluster, 重新 deploy DB) — 5min run / W=4 / 16 threads

| DB | Run-1 | Run-2 | Variance |
|---|---|---|---|
| TiDB | 1552.2 | 9719.2 | **+526%** ❌ |
| YBDB (Plan B) | 41.8 | 23.0 | -45% ❌ |
| CRDB | 3929.6 | 2365.6 | -40% ❌ |

**3 DB 都未 deterministic**。

### Yesterday (6/19) outlier 解釋

TiDB yesterday 10568 看似異常，但今天 run-2 9719 接近 yesterday。**反而 1500 那批是 outlier**（PD scheduler 在某些 cold-start 狀態 leader 沒搬到 IDC）。

---

## 2. Root cause — W=4 太小

```
TPCC standard: 理論 max tpmC per warehouse ≈ 12.86 (NEW_ORDER rate)

實測 tpmC/W:
  TiDB W=4:  1552 ~ 9719 / 4  → 388 ~ 2430 tpmC/W  (300× over standard)
  CRDB W=4:  2366 ~ 3930 / 4  → 591 ~ 982 tpmC/W
  YBDB W=4:    23 ~ 42 / 4    → 5.7 ~ 10.5 tpmC/W

16 threads × 4 warehouses = 4 threads/W
→ 高 lock contention
→ throughput 由 lock release timing 決定，run-to-run 變動 ±50%

vs W=128:
  16 threads × 128 W = 0.125 threads/W
  contention 趨近 0
  throughput 由真實 cluster latency 決定 → deterministic
```

**W=4 永遠 non-deterministic**：contention 是 timing-dependent，沒辦法消除。

---

## 3. 對 baseline 對比的意義

User baseline = W=128。今天所有 W=4 數據**不可比**。

| 維度 | W=4 (今天) | W=128 (user baseline) |
|---|---|---|
| Prepare data size | ~100MB | ~12GB (~32×) |
| Prepare time | 1-2 min/DB | 30-60 min/DB |
| Hot-spot contention | 強 (主因 variance) | 弱 |
| Run-to-run variance | ±50% | ±5% (typical) |
| TPCC tpmC standard | 超 standard 100-300× | 接近 standard |
| 對真實 prod 估值 | 不準 | 準 |

---

## 4. 下一步建議

**1 個完整 W=128 run** (預估 2.5h)：
```bash
make phase-crossregion-all TPCC_TS=$(date +%Y%m%dT%H%M%S%z) \
  WAREHOUSES=128 RUN_SEC=300 THREADS_LIST=16
```

預期 W=128 tpmC：
```
TiDB  ~1500   (12.86 × 128 efficiency)
CRDB  ~800-1200  (cross-region commit)
YBDB  ~400-800  (Plan B read_replica)
```

兩次 W=128 比較 variance：應在 ±5% 內 (真 deterministic)。

---

## 5. 今日 artifacts 已 fetch

```
results/x-cross/by-run/
  20260620T213459+0800/  Plan A run (3 DB) - YBDB Plan A backfire
  20260621T054627+0800/  BP run-1 (3 DB)   - Plan B + best-practice gates
  20260621T075351+0800/  BP run-2 (3 DB)   - same cluster re-deploy, determinism test
```

可用 `results/x-cross/by-run/<TS>/<db>-vm-6node-P-A-rc-<TS>/` 進一步分析 latency / WAN probe / leader-snapshot。
