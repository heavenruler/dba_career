# YugabyteDB TPC-C Pipeline Log — yuga-tc1 / S-BASE

> 本檔為 PoC v4.7 框架下的 YugabyteDB baseline。**先前 pre-v4.7 single-run wrapper 結果（vm-1node、k8s-3node-unlimit、k8s-3node-limit、YugabyteDB 2.20 issue 紀錄、AlmaLinux 8.10 改造紀錄）已全數存檔於 [`pipeline-log_old.md`](./pipeline-log_old.md)**。本檔等待 v4.7 detached suite（5-round × 5 min × 4 thread groups + 20min warmup × DB-host 雙邊監控）三 isolation 矩陣重跑後填入。

---

## TL;DR — 待 vm-1node 三 isolation 矩陣完成（v4.7）

> 重跑完成後此段補：tpmC 排行、三大發現、業務啟示、完整資料目錄。
> Pattern 對齊：
> - `results/tidb-tc1/S-BASE/pipeline-log.md` TL;DR 段
> - `results/crdb-tc1/S-BASE/pipeline-log.md` TL;DR 段

---

## YugabyteDB Isolation 注意事項（重跑前置 — 必讀）

YugabyteDB 三個 isolation 層級設定分**兩層雙閘**，缺一層即不生效；本 PoC 設定錯誤時會觸發 `Restart read required` / `could not serialize access` 並使吞吐失真。

### 啟用層（tserver gflag，預設 false）

```
yb_enable_read_committed_isolation=true
```

- 文件：[yb_enable_read_committed_isolation (stable 2025.2)](https://docs.yugabyte.com/stable/reference/configuration/yb-tserver/#yb-enable-read-committed-isolation)
- 設為 false 時，`read committed` 與 `read uncommitted` **悄悄 fallback 到 snapshot isolation**，SQL 層設定無效。

### 設定層（session / transaction）

```sql
SET transaction_isolation = 'read committed';  -- 或 'repeatable read' / 'serializable'
```

### 雙閘驗證

```sql
SHOW transaction_isolation;                          -- session 層
SHOW yb_effective_transaction_isolation_level;        -- 底層實際 isolation
```

> ⚠️ 只看 `transaction_isolation` 不夠，必須同時驗證 `yb_effective_transaction_isolation_level`；兩者一致才代表 isolation 真正生效。

### Isolation 模式對照

| 模式 | go-tpc flag | 說明 |
|------|-------------|------|
| `read committed` | `--isolation 2` | 與 PostgreSQL 相容；每 statement 新 snapshot，減少 write-write conflict |
| `repeatable read` (YB 預設) | `--isolation 3` | 底層 = snapshot isolation，**非** PostgreSQL `repeatable read` 語意 |
| `serializable` | `--isolation 4` | 最嚴格；高競爭下 retry 最多 |

官方文件：
- [Transaction Isolation Levels (stable 2025.2)](https://docs.yugabyte.com/stable/architecture/transactions/isolation-levels/)
- [Read Committed Isolation (stable 2025.2)](https://docs.yugabyte.com/stable/architecture/transactions/read-committed/)

---

## vm-1node-rc — 待測（v4.7）

> 重跑完成後此段對齊 `tidb-tc1` / `crdb-tc1` 的 vm-1node-rc 段結構填入：
>
> - **環境**：版本 / 硬體 / 部署 playbook / cluster setting / conn-params / Warehouses / Warmup / Run / Threads / OS 監控 / TPCC_TS / 結果目錄
> - **Suite 階段時序**：gate / prepare / gate-isolation / run / collect / total
> - **Gate 結果**：iso 雙閘 + THP / swappiness / ulimit / NTP / disk
> - **Prepare**：時間、check-all、schema
> - **Execute 結果**：5-round tpmC mean + range/mean + tpmTotal + efficiency + NO p50/p95/p99（latency 亦取 5-round mean）
> - **Round-by-round tpmC**：r1–r5 表，檢驗穩定性
> - **DB-host (.32) 飽和分析**：mpstat / iostat / 飽和歸因表
> - **vs 同硬體對比**：對 tidb-rc / crdb-rc
> - **Saturation 分析**：tpmC / p99 / %idle / %iowait 隨 thread 變化
> - **觀察**：sweet spot、瓶頸成因、業務啟示
> - **結論**：1 段總結

---

## vm-1node-rr — 待測（v4.7）

> 重跑完成後此段對齊 `tidb-tc1` / `crdb-tc1` 的 vm-1node-rr 段結構填入；YBDB rr = snapshot isolation 機制需在「結果分析」中明確標示，並與 TiDB rr (pessimistic SI) / CRDB rr (preview SI) 對標。

---

## vm-1node-strict — 待測（v4.7）

> 重跑完成後此段對齊 `crdb-tc1` 的 vm-1node-strict 段結構填入（TiDB 不支援原生 SERIALIZABLE，跨家 strict 對標主要對 CRDB SSI 與 YBDB SSI）。

---

## v4.7 重跑檢核項

每組 `(vm-1node, iso)` 完成後逐項勾選；全部齊備才能在 README 從 🟡 升為 ✅。

| 項目 | v4.7 目標 |
|------|-----------|
| Run 結構 | 5 round × 5 min × 4 thread groups (16/32/64/128) + 20min warmup @ 64 threads |
| Round artifact 格式 | `runs/threads-X/round-Y/go-tpc-stdout.txt`（per-round 結構化） |
| DB-host 監控 | mpstat / iostat / vmstat / sar 1s 取樣，client (`*.txt`) + db-host (`*-db.txt`) 雙邊 |
| Gate 雙閘 | `isolation-db.txt` + `isolation-driver-verify.txt`，兩者一致才放行 prepare；同時驗 `yb_effective_transaction_isolation_level` |
| Suite marker | `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.suite.done` |
| TPCC_TS | `yyyyMMddTHHmmss+0800` 共用整 suite |
| 平均口徑 | tpmC / p50 / p95 / p99 全為 5-round mean，range/mean 看穩定性 |
| Latency aggregate | NO p50 / p95 / p99（5-round mean） |
| 三 isolation 矩陣 | RC + RR + Strict |

---

## K8s 段 — 已存檔於 pipeline-log_old.md

> 2026-05-13 的 k8s-3node-unlimit / k8s-3node-limit 為 pre-v4.7 單次 10min wrapper 結果，已隨主檔清空動作存檔於 [`pipeline-log_old.md`](./pipeline-log_old.md)。待 K8s 環境以 v4.7 detached suite 重跑後，將回填正式段落。
