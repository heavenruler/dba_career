# YugabyteDB TPC-C Pipeline Log — yuga-tc1-old / S-BASE（DEPRECATED ARCHIVE）

> ⚠️ **本目錄為封存歷史資料，不再更新**。原為 PoC v4.7 框架下 YugabyteDB baseline 的「待重跑」骨架；2026-05-21 三 iso v4.7 重跑完成後，active 紀錄已搬至 [`../../yuga-tc1/S-BASE/pipeline-log.md`](../../yuga-tc1/S-BASE/pipeline-log.md)。
>
> 本目錄保留：
> - 此檔（待重跑骨架原版，便於追溯改寫前狀態）
> - [`archive/pipeline-log_old.md`](./archive/pipeline-log_old.md) — pre-v4.7 single-run wrapper 結果與 YugabyteDB 2.20 / AlmaLinux 8.10 改造歷史紀錄
> - 各 pre-v4.7 結果目錄：vm-1node/20260514-1337、k8s-3node-{unlimit,limit}/202605* 等

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

## v4.7 重跑 setup 修法紀錄（2026-05-20）

第一次 `make vm1-ybdb-rc` 啟動到 prepare 完成共撞 7 個 YBDB-specific 問題（tidb/crdb 路徑都不會觸發），全數修進 `poc/ansible/playbooks/yugabyte-vm1.yml`、`poc/tests/common/prepare.sh` 與 `poc/tests/common/gate-isolation.sh`。本段把 root cause / 修法 / commit SHA 留檔，避免下次 rr / strict / vm-3node 重跑時又踩同樣坑。

### 修法總覽

| # | 階段 | 錯誤訊息 | Root cause | 修法 | Commit |
|---|------|----------|-----------|------|--------|
| 1 | ansible deploy | `Could not import the dnf python module using /usr/bin/python3.12` | inventory 用 python3.12，但 AlmaLinux 8.10 的 dnf python bindings 只在 `/usr/libexec/platform-python` (3.6)；`ansible.builtin.dnf` 模組需要這個 binding | 兩段 `ansible.builtin.dnf` 改為 `ansible.builtin.shell` + `rpm -q` idempotent install（與 tidb-vm1.yml 同 pattern）| [`c88f7d4`](#) |
| 2 | ansible deploy | `Wait for YSQL port` timeout 240s | fresh VM 上 `yugabyted status` 即使「is not running」也回 **rc=0**，所以 `when: yb_status.rc != 0` 條件被 skip → `Start YugabyteDB RF=1` 永遠不會跑 | 條件改為 `'is not running' in (yb_status.stdout \| default(''))` ，rc!=0 作 backstop | [`e5ccc11`](#) |
| 3 | prepare DROP/CREATE | `ERROR: DROP DATABASE cannot run inside a transaction block` | `psql -c "DROP; CREATE"` 兩 stmt 在同一 implicit txn；YSQL/PG 禁 DROP DATABASE 在 txn 內 | 拆兩個 `-c` flag，各自獨立 txn | [`904c80c`](#) |
| 4 | go-tpc prepare | suite 卡在 `begin to check warehouse 1 at condition 3.3.2.x` 1h+ 不結束 | go-tpc 預設 prepare 完跑 inline consistency check；3.3.2.x 系列為跨表 aggregate，YB 2025.2 上會卡 30+ min | YBDB 加 `--no-check`；後續 `check-all` 步驟 YBDB 也跳過，改用 row-count 驗整性 | [`99cb5a3`](#) |
| 5 | prepare DROP DATABASE | `ERROR: database "tpcc" is being accessed by other users` | 前次 suite kill 後 go-tpc 連線在 YB 仍 lingering（YSQL session state 由 tserver 保留至 TCP 驅逐或顯式 terminate）| DROP 前 `pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='<db>' AND pid<>pg_backend_pid()`，多 `-c` 不在同 txn | [`fc76fe4`](#) |
| 6 | prepare schema+EXPLAIN dump | `ERROR: column c.relhasoids does not exist` ＋ psql rc=1 → `set -euo pipefail` 殺 suite | AlmaLinux 8.10 內建 psql（postgresql 套件，PG ≤11）的 `\d+` 查 `pg_class.relhasoids`，PG 12+ 已移除此 column，YB 2025.2 catalog 沒這欄 | YBDB schema/EXPLAIN dump 改用 yugabyte 隨附的 `ysqlsh`（catalog 同步）；其它 plain-SQL（DROP/CREATE/ANALYZE/row-count）保留 psql | [`8069ada`](#) |
| 7 | gate-isolation | （preemptive；本輪未觸發但邏輯缺口）原 `SHOW transaction_isolation` 通過不代表 effective 真為 RC | YB 雙閘要求：session 層 `transaction_isolation` ＋ tserver gflag `yb_enable_read_committed_isolation`；缺 gflag 時前者顯示 `read committed`，但 `yb_effective_transaction_isolation_level` 退回 `repeatable read`，跑出來的 RC 結果其實是 SI | YBDB DB-gate ＋ driver-gate 兩段都加 `SHOW yb_effective_transaction_isolation_level`；effective 必須等於 expected 否則 die，hint 指向 tserver gflag；JSON marker 多帶 `yb_effective_db` / `yb_effective_driver` | [`b9b3b43`](#) |

### 為什麼 tidb / crdb 沒踩這些坑

| 修法 | tidb | crdb |
|------|------|------|
| #1 `ansible.builtin.dnf` | tidb-vm1.yml / cockroach-vm1.yml 早已用 `shell` + `rpm -q` pattern（先前 cockroach deploy bug 修過）| 同 tidb |
| #2 status gate | TiDB 用 `tiup cluster display` 判斷集群狀態（有明確 exit code 語意）；CRDB 用 `start-single-node` 本身 idempotent | 同 tidb |
| #3 DROP/CREATE in txn | MySQL 與 CockroachDB SQL 都允許 DDL 在 implicit txn；`mysql -e "DROP;CREATE"` 與 `cockroach sql -e "DROP;CREATE"` 正常 | 同 tidb |
| #4 slow consistency check | TiDB / CRDB check-all 都在合理時間內（TiDB 52min prepare 內含、CRDB 43min 內含），可直接用 go-tpc 原生 check | 同 tidb |
| #5 lingering session | TiDB / CRDB 的 `DROP DATABASE` 不被現存連線 pin（TiDB 自動失效、CRDB 預設允許 force drop）| 同 tidb |

### YBDB-specific 影響項

- **整性驗證口徑**：YBDB 路徑改用 row-count 取代 go-tpc check-all；資料完整性 vs TiDB / CRDB 的 14-condition 嚴格度有差，但對 tpmC / latency 結果不影響（檢核僅在 prepare 結尾、run 前；run 用相同 go-tpc workload）
- **預期 row counts (W=128)**：warehouse 128 / district 1,280 / customer 3,840,000 / history 3,840,000 / item 100,000 / stock 12,800,000 / new_order 1,152,000 / orders 3,840,000 / order_line ~38.4M (5-15 lines per order, randomised)
- **Gate WARN（本輪不致命）**：
  - `DB-host THP != never` / `vm.swappiness > 5` / `ulimit -n < 65536` — yugabyte-vm1.yml 尚未含 OS tuning task（tidb-vm1.yml 有「OS tuning」段）；本輪先不卡 gate，下一輪 rr / strict 前要補
  - `client (.31) artifacts FS available 14GB < 30GB` — 累積跨家 artifacts；rr / strict 前要清

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

## K8s 段 — 已存檔於 archive/pipeline-log_old.md

> 2026-05-13 的 k8s-3node-unlimit / k8s-3node-limit 為 pre-v4.7 單次 10min wrapper 結果，已隨主檔清空動作存檔於 [`archive/pipeline-log_old.md`](./archive/pipeline-log_old.md)。待 K8s 環境以 v4.7 detached suite 重跑後，將回填正式段落。
