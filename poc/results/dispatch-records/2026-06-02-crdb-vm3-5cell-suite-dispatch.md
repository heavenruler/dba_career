# CRDB vm-3node 5-cell Suite Dispatch — F-E patch + Resume (2026-06-02)

> 對應對話：2026-06-01 ~ 2026-06-02 CockroachDB Phase 2 5-cell suite batch
> 規劃文件：[`poc/1_MeetingMinutes/0602.md`](../../1_MeetingMinutes/0602.md), [`0602-agenda.md`](../../1_MeetingMinutes/0602-agenda.md)
> 兩 batch 串接（original + resume after F-E）；CockroachDB v26.2.0；N=1。

---

## 1. Executive Summary

CockroachDB v26.2.0 vm-3node 5-cell suite（`1s1r / 1s3r / 3s1r / 3s3r / haproxy-3s3r`）全部 PASS。途中踩 **F-E**（`prepare.sh` history `SPLIT AT VALUES ('00000086')` 引號 + 前導零被 CockroachDB 當八進位解析），cell 3s1r 於 prepare SPLIT 階段炸出 SQLSTATE 22P02 fail-fast。修補 `prepare.sh` 改用裸 int → resume batch（3-cell）順利全綠。Wall-clock 21h47m（含 F-E 修復 + resume restart 約 3.5h overhead）。

---

## 2. 條件 / 拓樸

| 維度 | 值 |
|---|---|
| DB | CockroachDB **v26.2.0** |
| iso | rc (READ COMMITTED) |
| Warehouses | 128 |
| Sub-topologies | `1s1r / 1s3r / 3s1r / 3s3r / haproxy-3s3r` |
| Thread groups | 16, 32, 64, 128 × 5 rounds each |
| DB nodes | 172.24.40.{32, 33, 34} |
| HAProxy（haproxy-3s3r cell） | 172.24.47.20:26257 `balance roundrobin mode tcp` |
| Client | 172.24.40.31（poc batch controller）|
| Driver | postgres (`go-tpc -d postgres`)；`--conn-params options=-c default_transaction_isolation=read\ committed` |

---

## 3. 執行時序

### 3.1 Phase 1 — Original 5-cell batch

| TS | Event |
|---|---|
| 2026-06-01 10:58:59 | Original batch dispatched `PID=1119304` `BATCH=20260601T105859+0800` |
| 11:00:48 | cell 1s1r dry-run PASS |
| 14:27:42 | **cell 1s1r SUITE PASS** dur=12483s (3h28m) |
| 14:28:31 | cell 1s3r dry-run PASS |
| 17:56:25 | **cell 1s3r SUITE PASS** dur=12563s (3h29m) |
| 17:58:14 | cell 3s1r deploy + dry-run PASS |
| 18:32:11 | post-prepare SPLIT 9 tables → **FAILED at 9th (history)** ← F-E |
| 18:32:15 | suite fail-fast (rc=1); original batch exit |

### 3.2 F-E Root Cause & Fix

**Symptom** (`/tmp/batch-crdb-5cell-suite.log:264`)：
```
ERROR: could not parse "00000086" as type int: strconv.ParseInt: parsing "00000086": invalid syntax
SQLSTATE: 22P02
Failed running "sql"
```

**Trigger** (`tests/common/prepare.sh:156`，修補前)：
```sql
ALTER TABLE history    SPLIT AT VALUES ('00000043'), ('00000086');
```

**Root cause**：
- TPCC `history` 表無顯式 PK → CockroachDB 自動添加隱式 `rowid INT8`（`unique_rowid()` 生成的時間+節點位元組合，實際值 ~10^17 範圍）
- SPLIT 值被傳為 zero-padded **字串字面量** `'00000086'`
- CockroachDB v26.2.0 走 Go `strconv.ParseInt(s, 0, 64)` (`base=0` auto-detect)
- 前導 `0` 觸發**八進位**解析 → digit `8` 在 octal 不合法 → `SQLSTATE 22P02`
- 其他 8 表（warehouse / district / customer / new_order / orders / order_line / stock / item）使用裸 int 字面量，全部成功；只有 history 因採用引號字串路徑炸鍋

**Fix** (commit `0ac53da`)：
```sql
-- history: CRDB 無顯式 PK → 隱式 rowid INT8 (unique_rowid()，~10^17 範圍)。
-- 用裸 int 值；早期版本帶引號的 '00000043' 被 CRDB parseInt(base=0) 當八進位
-- 解，digit 8 不合法 → SQLSTATE 22P02。改用裸 int，鏡像 TiDB 的 _tidb_rowid
-- 切點 (1280000),(2560000) — 對 rowid 大值是空 leading range，但 SHOW RANGES
-- 仍回 3，shard-count gate 過關。
ALTER TABLE history    SPLIT AT VALUES (1280000), (2560000);
```

**側效應**：1,280,000 / 2,560,000 對 CockroachDB 實際 rowid（~10^17）皆遠小於最小 rowid → leading ranges 邏輯上為空，所有 history 資料集中在第 3 range。`SHOW RANGES FROM TABLE history` 仍回 3 → 9-表 shard-count hard gate 過關。對 history 之 range-based scan 行為留 caveat（C2）。

### 3.3 Phase 2 — Resume 3-cell batch

| TS | Event |
|---|---|
| 2026-06-01 22:13:41 | Resume batch dispatched `PID=1178888` `BATCH=20260601T221341+0800` |
| 22:15:09 | cell 3s1r dry-run PASS |
| 2026-06-02 01:42:53 | **cell 3s1r SUITE PASS** dur=12552s (3h29m) — **F-E 修補驗證通過** ✅ |
| 01:44:48 | cell 3s3r dry-run PASS |
| 05:15:00 | **cell 3s3r SUITE PASS** dur=12727s (3h32m) |
| 05:16:59 | cell haproxy-3s3r dry-run PASS |
| 08:44:56 | **cell haproxy-3s3r SUITE PASS** dur=12596s (3h30m) |
| 08:46:34 | FINAL `purge_all_dbs` + verify all clean；batch ALL PASS |

**Wall-clock**：2026-06-01 11:00:00 → 2026-06-02 08:46:34 ≈ **21h47m**（含 F-E 修補 + resume restart overhead 約 3.5h）

---

## 4. 5-cell Summary

| Cell | Status | Duration | DB-host | TS | Batch |
|---|:---:|---:|---|---|---|
| 1s1r | ✅ PASS | 3h28m (12483s) | 172.24.40.32 | `20260601T105859+0800` | original |
| 1s3r | ✅ PASS | 3h29m (12563s) | 172.24.40.32 | `20260601T142702+0800` | original |
| 3s1r | ✅ PASS | 3h29m (12552s) | 172.24.40.32 | `20260601T221341+0800` | resume |
| 3s3r | ✅ PASS | 3h32m (12727s) | 172.24.40.32 | `20260602T014253+0800` | resume |
| haproxy-3s3r | ✅ PASS | 3h30m (12596s) | 172.24.47.20 | `20260602T051500+0800` | resume |

**5-cell 5-round mean tpmC**（由 `summary-from-stdout.py` 從 raw stdout 產生 summary.json 後彙整）：

| Cell | 代表點 @ t | tpmC | NO p99 (ms) | range/mean | summary.json |
|---|:---:|---:|---:|---:|---|
| 1s1r | t=32 | **14,564** | 175 | 2.6% | [link](../../crdb-tc1/S-BASE/vm-3node-1s1r-rc/crdb-vm-3node-1s1r-rc-20260601T105859+0800/summary.json) |
| 1s3r | t=32 | 10,911 | 222 | 2.8% | [link](../../crdb-tc1/S-BASE/vm-3node-1s3r-rc/crdb-vm-3node-1s3r-rc-20260601T142702+0800/summary.json) |
| 3s1r | t=64 | 14,051 | 379 | 10.7% | [link](../../crdb-tc1/S-BASE/vm-3node-3s1r-rc/crdb-vm-3node-3s1r-rc-20260601T221341+0800/summary.json) |
| 3s3r | t=64 | 11,132 | 473 | 3.8% | [link](../../crdb-tc1/S-BASE/vm-3node-3s3r-rc/crdb-vm-3node-3s3r-rc-20260602T014253+0800/summary.json) |
| **haproxy-3s3r** | t=128 | **15,033** | **718** | 6.9% | [link](../../crdb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/crdb-vm-3node-haproxy-3s3r-rc-20260602T051500+0800/summary.json) |

> 早期版本曾以 haproxy t=128 round-5 末段抽樣 `14,348 / 772ms` 呈現；5-round mean parser 跑完後實測 `15,033 / 718ms`（差異來自 round-1/2/3 較高 throughput）。

---

## 5. Caveat

| # | Caveat | 影響 | 緩解 |
|:---:|---|:---:|---|
| **C1** | N=1（每 cell 跑一次，5-round mean within cell）| **高** | 對外白皮書前須 N=3 重做（建議 3s3r / haproxy-3s3r 各補；~7h） |
| **C2** | F-E 修補後 history SPLIT 邊界 (1.28M/2.56M) 與 rowid 實際分布（~10^17）不重合，leading ranges 空，history 全資料壓 1 range | 低 | shard-count gate 仍 pass；range-scan 行為不對等。對 TPCC 影響可忽略（history 是寫密集，掃描極少）|
| **C3** | DB-host metrics 僅採 `CLUSTER_HOST`（vm-3node 直連 cell = .32，haproxy cell = .20）；.33/.34 跨節點 metrics 缺 | 中 | `run.sh:63-65` 已知 gap；跨區 Track E 必補 fan-out |
| **C4** | CockroachDB v26.2.0 `crdb_internal.*` 多處 access restricted（SQLSTATE 42501）；本 batch 已 sidestep（F-A-v2 dry-run §1c no-op + F-D shard-count gate 改 `SHOW RANGES FROM TABLE`），但 repo 散落呼叫未全 audit | 中 | 後續做 `grep -r crdb_internal` 稽核 |
| **C5** | Network 中段 SSH 斷線一次（07:04 Operation timed out），monitor v2 因 liveness probe 自身也 SSH 失敗被誤判 → exit；monitor v3 加 5×15s liveness probe retry 後續無誤判 | 低 | Batch 本身不受影響（執行於 .31 nohup detached）|

---

## 6. Commit Chain（本次涉及）

| Commit | Topic |
|---|---|
| `15c3208` | fix: pre-flight CRDB 5-cell batch — F-A / F-B / F-C（dry-run RF gate + haproxy backend health + inventory self-ssh fix）|
| `eaa2420` | fix: dry-run-confirm F-A-v2 + F-B-v2 — CRDB 5-cell dry-run validated（drop §1c CRDB peer-count gate；v26.2.0 不適用）|
| `db3936b` | feat: status-vm1.sh — show in-progress phase sub-log |
| `ebc481f` | fix: prepare.sh F-D — CRDB shard-count gate v26.2.0 supported API（改 `SHOW RANGES FROM TABLE`，原 `crdb_internal.ranges` 受限）|
| `0ac53da` | **fix: prepare.sh CRDB history SPLIT — F-E remove octal-parsed quoted ints**（本次新增）|

---

## 7. Artifact Paths

### Artifact directories (`.31:/tmp/poc-tpcc/artifacts/`)

```
crdb-vm-3node-1s1r-rc-20260601T105859+0800/         (original PASS)
crdb-vm-3node-1s3r-rc-20260601T142702+0800/         (original PASS)
crdb-vm-3node-3s1r-rc-20260601T175625+0800/         (original FAIL — F-E)
crdb-vm-3node-3s1r-rc-20260601T221341+0800/         (resume PASS)
crdb-vm-3node-3s3r-rc-20260602T014253+0800/         (resume PASS)
crdb-vm-3node-haproxy-3s3r-rc-20260602T051500+0800/ (resume PASS)
.crdb-5cell-suite-summary-20260601T105859+0800.txt  (1s1r/1s3r PASS + 3s1r SUITE_FAIL)
.crdb-3cell-resume-summary-20260601T221341+0800.txt (3s1r/3s3r/haproxy-3s3r PASS)
```

每 cell artifact 含：`db-config/ / dry-run/ / env/ / gate/ / prepare/ / runs/threads-{16,32,64,128}/round-{1..5}/{go-tpc-stdout.txt, mpstat-db.txt, iostat-1s-db.txt, sar-net-db.txt, vmstat-1s-db.txt} / .dry-run.done / .gate.done / .gate-isolation.done / .prepare.done / .lock-*`

### Batch scripts（transient on `.31`，**未入 repo**，0602-agenda §1 A4 待裁示）

- `/tmp/batch-crdb-5cell-suite.sh` — original 5-cell
- `/tmp/batch-crdb-3cell-resume.sh` — resume 3-cell（CELLS=(3s1r 3s3r haproxy-3s3r)）

### Logs

- `/tmp/batch-crdb-5cell-suite.log`（original）
- `/tmp/batch-crdb-3cell-resume.log`（resume）

---

## 8. Replay Commands

```bash
# 1. 抽某 cell 的 5-round tpmC (e.g. 3s3r t=128):
ssh root@172.24.40.31 'for r in 1 2 3 4 5; do
  grep "^tpmC:" /tmp/poc-tpcc/artifacts/crdb-vm-3node-3s3r-rc-20260602T014253+0800/runs/threads-128/round-$r/go-tpc-stdout.txt
done'

# 2. 抽 NEW_ORDER p99 (5-round):
ssh root@172.24.40.31 'for r in 1 2 3 4 5; do
  grep "\[Summary\] NEW_ORDER" /tmp/poc-tpcc/artifacts/crdb-vm-3node-3s3r-rc-20260602T014253+0800/runs/threads-128/round-$r/go-tpc-stdout.txt
done'

# 3. 跑 summary aggregation 產出 summary.json (每 cell):
ssh root@172.24.40.31 'cd /root/poc-batch && python3 tests/common/summary-from-stdout.py \
  /tmp/poc-tpcc/artifacts/crdb-vm-3node-3s3r-rc-20260602T014253+0800/'

# 4. 拉 artifact 回 Mac:
make fetch-vm3-crdb-3s3r-rc TPCC_TS=20260602T014253+0800
# (或 rsync 6 cells 一次拉回)
```

---

## 9. Next Steps

| # | 動作 | 狀態 |
|---|---|---|
| 1 | rsync 5 cells artifact 回 Mac → `results/crdb-tc1/S-BASE/vm-3node-*-rc/` | ✅ 完成（commit `4cc8e94`） |
| 2 | 跑 `summary-from-stdout.py` 產出 5 個 `summary.json` | ✅ 完成（commit `b4173c9`） |
| 3 | 更新 [`0602-agenda.md`](../../1_MeetingMinutes/0602-agenda.md) §1-A 數據表加入 CockroachDB 5 cells（補完三家對照） | 🔄 待做 |
| 4 | TiDB 5-cell batch dispatch（`.31:/tmp/batch-tidb-5cell-suite.sh` 已 ready）| 🔄 待做 |
| 5 | 三家（TiDB / CockroachDB / YugabyteDB）`haproxy-3s3r` 對照分析 → 新 dispatch record | 等 TiDB 跑完 |
| 6 | 0602-agenda §12 A4：CockroachDB + TiDB batch script 是否搬進 `poc/tests/batch/` 入庫 | 等裁示 |
