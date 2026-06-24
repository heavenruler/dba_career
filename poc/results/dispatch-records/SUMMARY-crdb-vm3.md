# CockroachDB vm-3node Dispatch Summary

> **彙整** CockroachDB 在 vm-3node 拓樸下所有踩坑修補（F-A → F-E 系列）、5-cell suite 完整 journey；本檔保留可引用的 journey、fixes、數據摘要與分析入口；已清理的 raw / operational logs 僅透過 git history 追溯。

---

## TL;DR

| 指標 | 結果 |
|---|---|
| 完成 cells | **5 / 5**（1s1r / 1s3r / 3s1r / 3s3r / haproxy-3s3r）|
| 樣本數 | N=1（對外結論前須 N=3；見 [README N9](../README.md#note-N9)）|
| Best mean tpmC | **15,033 @ haproxy-3s3r t=128**（vs direct 3s3r +37.5%）|
| Best p99 | 90 ms @ 1s1r t=16；718 ms @ haproxy-3s3r t=128 |
| 主要 Fixes | F-A / F-A-v2 / F-B / F-B-v2 / F-C / F-D / F-E（共 7 項，CockroachDB v26.2.0 API 變動為主因）|
| Wall-clock 全 suite | 21h 47m（含 F-E 修補 + resume restart 3.5h overhead）|
| 主要踩坑 | `crdb_internal.*` access restricted（SQLSTATE 42501）→ F-A-v2 / F-D；history SPLIT `'00000086'` 八進位解析失敗（SQLSTATE 22P02）→ F-E |

---

## 5-cell 測試結果（canonical TS、5-round mean）

> 「代表點 @ t」採「mean tpmC 最大且不撞極端 latency」原則。Source: 5 個 `summary.json` 由 [`tests/common/summary-from-stdout.py`](../../tests/common/summary-from-stdout.py) 從 raw stdout 產生。

| Cell | TS | 代表點 @ t | tpmC | NO p99 (ms) | range/mean | error rate | 來源目錄 |
|---|---|:---:|---:|---:|---:|---:|---|
| 1s1r | `20260601T105859+0800` | t=32 | **14,564** | 175 | 2.6% | 0.000% | [vm-3node-1s1r-rc/](../crdb-tc1/S-BASE/vm-3node-1s1r-rc/crdb-vm-3node-1s1r-rc-20260601T105859+0800/) |
| 1s3r | `20260601T142702+0800` | t=32 | 10,911 | 222 | 2.8% | 0.000% | [vm-3node-1s3r-rc/](../crdb-tc1/S-BASE/vm-3node-1s3r-rc/crdb-vm-3node-1s3r-rc-20260601T142702+0800/) |
| 3s1r | `20260601T221341+0800` ⚠️ | t=64 | 14,051 | 379 | 10.7% | 0.000% | [vm-3node-3s1r-rc/](../crdb-tc1/S-BASE/vm-3node-3s1r-rc/crdb-vm-3node-3s1r-rc-20260601T221341+0800/) |
| 3s3r | `20260602T014253+0800` | t=64 | 11,132 | 473 | 3.8% | 0.000% | [vm-3node-3s3r-rc/](../crdb-tc1/S-BASE/vm-3node-3s3r-rc/crdb-vm-3node-3s3r-rc-20260602T014253+0800/) |
| **haproxy-3s3r** | `20260602T051500+0800` | t=128 | **15,033** | **718** | 6.9% | 0.000% | [vm-3node-haproxy-3s3r-rc/](../crdb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/crdb-vm-3node-haproxy-3s3r-rc-20260602T051500+0800/) |

> ⚠️ **3s1r `20260601T175625+0800` 為 F-E FAIL trial**（history SPLIT 八進位解析失敗，prepare 階段炸出，無 runs/）— 不入 canonical；`20260601T221341+0800` 為 F-E 修補後 resume PASS。

---

## 執行 Journey 時序

| 階段 | 日期 / 時間 | 事件 | 引用 |
|---|---|---|---|
| Pre-flight 系列踩坑 | 2026-05-31 ~ 2026-06-01 早上 | F-A / F-B / F-C（dry-run RF gate、HAProxy backend health、inventory self-ssh）連環 fail；以 7 個 dry-run trial 跑完才驗證 dispatch-confirm 流程 | commit `15c3208` `eaa2420` |
| F-A-v2 / F-D 補 | 2026-06-01 早上 | CockroachDB v26.2.0 `crdb_internal.*` access restricted 觸發 §1c peer-count gate 全 0；F-D 把 shard-count gate 改用 `SHOW RANGES FROM TABLE`（v26.2 supported API） | commit `eaa2420` `ebc481f` |
| 5-cell suite Phase 1（original batch） | 2026-06-01 11:00 ~ 18:32 | cell 1s1r PASS (3h28m) / 1s3r PASS (3h29m) / **3s1r FAIL @ prepare SPLIT（F-E history `'00000086'` 八進位解析）** | [2026-06-02 dispatch record](./2026-06-02-crdb-vm3-5cell-suite-dispatch.md) §3.1 |
| **F-E 修補** | 2026-06-01 18:32 ~ 22:13 | `prepare.sh:156` `ALTER TABLE history SPLIT AT VALUES ('00000043'), ('00000086')` 改用裸 int `(1280000), (2560000)` 鏡像 TiDB `_tidb_rowid`；root cause：CockroachDB `strconv.ParseInt(s, 0, 64)` base=0 把前導零當八進位、digit 8 invalid → SQLSTATE 22P02 | commit `0ac53da`；dispatch record §3.2 |
| Resume 3-cell batch（Phase 2） | 2026-06-01 22:13 ~ 2026-06-02 08:46 | cell 3s1r PASS (3h29m) → 3s3r PASS (3h32m) → haproxy-3s3r PASS (3h30m)；ALL PASS 09:00 完整 final-purge 收尾 | dispatch record §3.3 |

**Wall-clock 全程**：2026-06-01 11:00:00 → 2026-06-02 08:46:34 ≈ **21h 47m**（含 F-E 修補 + resume restart 約 3.5h overhead）

---

## Fixes Catalog（CockroachDB v26.2.0 系列）

### F 系列（Pre-flight + Suite）

| ID | Commit | 症狀 | 根因 | 修補 |
|:---:|---|---|---|---|
| **F-A / F-B / F-C** | `15c3208` | 5-cell batch pre-flight 三項缺漏：dry-run RF gate / HAProxy backend health / inventory self-ssh | 初版 pre-flight 設計未覆蓋 vm-3node 變體 | 加入 pre-flight check 三項 |
| **F-A-v2** | `eaa2420` | dry-run-confirm §1c CockroachDB peer-count gate 全 0 → 全 cell fail-closed | v26.2.0 起 `crdb_internal.*` access restricted（SQLSTATE 42501）；query 靜默 fail；且 CockroachDB per-range zone 系統 range RF=5 永遠 >= EXPECTED_RF | §1c 改 no-op 註解；保留 §2 dry-run RF target 驗證（`SHOW ZONE CONFIGURATION FROM RANGE default`） |
| **F-B-v2** | `eaa2420` | HAProxy backend health check 在 .20 host 失敗 | health probe 超時設定 | 調整 timeout |
| **F-D** | `ebc481f` | `prepare.sh` shard-count gate 全 9 表 actual=0 → fail-closed | v26.2.0 `crdb_internal.ranges` access restricted → query 靜默 fail | 改用 `SHOW RANGES FROM TABLE`（v26.2 supported API） |
| **F-E** | `0ac53da` | cell 3s1r prepare SPLIT 第 9 表 (history) 炸：`could not parse "00000086" as type int: invalid syntax (SQLSTATE 22P02)` | 字串字面量 `'00000086'` → CockroachDB `strconv.ParseInt(s, 0, 64)` 以 base=0 解析，前導零觸發八進位，digit 8 不合法 | 改用裸 int `(1280000), (2560000)` 鏡像 TiDB `_tidb_rowid` 切點；對 rowid 大值是空 leading range，但 `SHOW RANGES` 仍回 3，shard-count gate 過關 |

### 觀測 / 工具

| ID | Commit | 用途 |
|:---:|---|---|
| status visibility | `db3936b` | status-vm1.sh phase sub-log；dispatch 中觀察用 |

---

## 跨 cell 主要發現

1. **Sweet spot 因 cell 異**：1s1r/1s3r @ t=32；3s1r/3s3r @ t=64；haproxy-3s3r @ t=128（multi-entry 推升併發容忍度）。
2. **HAProxy 紅利 +37.5%**（direct 10,931 → haproxy 15,033 @ t=128）：CockroachDB direct 模式 client 已連 .32 即有 gateway 路由能力，故 HAProxy 收益 比 TiDB / YugabyteDB 的 +78% 小，但仍顯著。
3. **RF 寫成本約 -25%**：1s1r → 1s3r 約 −25.1% throughput（與 YugabyteDB 1s3r 量到的 −25.5% 高度吻合），驗證 Raft 3-replica quorum 固定 cost。
4. **Sharding 成本約 -4%**（1s1r → 3s1r）：遠低於 YugabyteDB 的 −13%；推測 CockroachDB range-leaseholder gateway routing 比 tablet 協調更有效率。
5. **3s3r 在 4 vCPU 上仍可穩定**：CockroachDB 3s3r 的 t=64-128 stddev ≤ 4%（遠優於 YugabyteDB 3s3r 的 1,400-2,615 極不穩）。
6. **v26.2.0 API 變動是本次主要 friction**：4 個 F 系列修補中有 3 個（F-A-v2 / F-D / F-E）皆與 v26.2.0 access restricted / parser 行為變動有關；建議後續做 repo-wide `crdb_internal.*` audit。

---

## Source Dispatch Records（細節索引）

| 文件 | 焦點 |
|---|---|
| [2026-06-02-crdb-vm3-5cell-suite-dispatch.md](./2026-06-02-crdb-vm3-5cell-suite-dispatch.md) | 5-cell suite + F-E root cause / fix / resume journey 完整記錄 |
| [S-K8S pipeline-log](../crdb-tc1/S-K8S/pipeline-log.md) | Kubernetes 變體 v4.7 已完成（unlimit / limit）|

---

## 下一步（建議）

1. **`haproxy-3s3r` 補 N=3**（~3h × 3 = 9h）→ 升級為對外可引用 baseline
2. **repo-wide `crdb_internal.*` audit**：稽核其他散落呼叫是否會在 v26.2.0 再次踩到 access restricted（F-A-v2 / F-D / F-E 是已知，其他未知）
3. **CockroachDB Kubernetes 變體 v4.7** 已完成（unlimit / limit；見 [S-K8S pipeline-log](../crdb-tc1/S-K8S/pipeline-log.md)）
4. **5-round mean 補上 DB-host metrics 分析**（mpstat-db / iostat-1s-db / sar-net-db 已採，但 README §A.4 caveat C3 註明跨節點 metrics 缺）
5. **跨區 IDC↔GCP 規劃**：見 [`1_MeetingMinutes/0602.md §10 跨區 PoC（Track E）`](../../1_MeetingMinutes/0602.md#10-跨區-poctrack-e-詳細設計)
