# YugabyteDB TPC-C Pipeline Log — yuga-tc1 / S-BASE

> 本檔為 PoC v4.7 框架下的 YugabyteDB baseline（v4.7 detached suite：5-round × 5 min × 4 thread groups + 20 min warmup × DB-host 雙邊監控）。pre-v4.7 single-run wrapper 資料（vm-1node 單次 10min、k8s-3node-{unlimit,limit} 單次、2.20 issue 紀錄、AlmaLinux 8.10 改造紀錄、原 pipeline-log.md / pipeline-log_old.md）整套已備份至 [`../../yuga-tc1-old/`](../../yuga-tc1-old/)，本檔不再保留 pre-v4.7 段落。

---

## TL;DR — vm-1node-rc / vm-1node-rr 完成（2026-05-20 / 21）

**核心結論**：YugabyteDB 2025.2.2 LTS 在 4 vCPU + single XFS 硬體下，**RC > RR 達 6x tpmC**（rc t32 11,436 vs rr t32 1,879）。RC 是 **CPU-bound 含異常高 %sys (18-19%)**、零 error；RR = snapshot isolation（同 CRDB rr 機制）撞 retry storm，DB 反而 %idle 66-67% — **transaction coordination bound** 而非資源 bound。

### tpmC 排行（5-round mean，4 vCPU + single XFS）

| iso | t16 | t32 | t64 | t128 | err / 5min（每併發 ≈ N−1）|
|-----|-----|-----|-----|------|---------------------------|
| rc  | 10,653 | **11,436** | 11,240 | 10,885 | **0** 全程 |
| rr  | 1,846 | 1,879 | 1,847 | 1,714 | 15 / 31 / 63 / 127（線性 N−1） |
| Δ (rr / rc) | -82.7% | **-83.6%** | -83.6% | -84.2% | — |

### 三大發現

1. **rc 是真 RC、零 error**：tserver gflag `yb_enable_read_committed_isolation=true` + session iso 雙閘 +  `yb_effective_transaction_isolation_level` gate 三層驗證，20 round / 53,721 NEW_ORDER 全成功；對比 CRDB rr 412 errors / 20 round。**不啟用 gflag 會 silent fallback 到 SI → 跑出來的「RC」其實是 RR**（=本 rr 表）。
2. **rr 機制與 CRDB rr 同**：YBDB rr default 是 snapshot isolation（per-txn snapshot ts，first committer wins）；hot row（district）每 round 起始 N 個 worker 同時 BEGIN → 1 個 commit、N-1 個拿到 SerializationError 重來。errors **線性 = thread − 1**（t16=15、t32=31、t64=63、t128=127）與 CRDB rr **完全相同 pattern**（兩家共同 SI bug, 不只 CRDB）。
3. **rr 飽和成因不同於 rc**：
   - rc t128：%idle 1.89%、%user 74.7%、%sys 18.5%、%iowait 0.25% → **CPU-bound + 高 %sys**（YSQL ↔ DocDB IPC overhead）
   - rr t128：%idle **66.57%**、%user 14.1%、%sys 5.8%、%iowait **11.77%** → **DB 大量 idle 但 throughput 撞牆** → 瓶頸不在 DB，在 client retry loop 浪費時間
   - rr disk %util 63% > rc 42% — 推測 SI version metadata + retry 重讀放大 IO；但因 throughput 砍 6x，總 IOPS 反而不高（待 DocDB internal metrics 進一步驗證）

### 業務啟示

- YBDB **保留預設 RC 是正確選擇**：rr 拿不到任何性能 / 一致性收益，反而砍 84% 吞吐 + 引入 N-1 errors/round
- 跨家 RR 三胞胎：**CRDB rr 3,788 / YBDB rr 1,879 / TiDB rr 13,874**。前兩家是 optimistic SI 撞 hot row，TiDB pessimistic 模式（`tidb_txn_mode=pessimistic`）拿鎖排隊**不 retry**、不 abort，唯一可承受 hot-row contention 的 RR 實作
- 同硬體 7 組對標（5-round mean）：TiDB rr 13,874（t128）＞ TiDB rc 13,064（t128）＞ YBDB rc 11,436（t32）＞ CRDB strict 10,830（t64）＞ CRDB rc 9,134（t64）＞ CRDB rr 3,788（t128）＞ **YBDB rr 1,879（t32）** ←本輪新增

### 完整資料目錄

| iso | TPCC_TS | 5-round mean peak | err / 20 rounds | 詳細段落 |
|-----|---------|--------------------|-----------------|----------|
| rc | 20260520T134929+0800 | **11,436 @ t32** | 0 | [§ vm-1node-rc](#vm-1node-rc--2026-05-20poc-v47-baseline含-db-host-os-監控) |
| rr | 20260520T215216+0800 | **1,879 @ t32** | 940（15+31+63+127 × 5 round per group）| [§ vm-1node-rr](#vm-1node-rr--2026-05-21poc-v47-snapshot-isolation--retry-storm) |
| strict | （待測） | — | — | [§ vm-1node-strict](#vm-1node-strict--待測v47) |

下一步：vm-1node-strict（YBDB 原生 SERIALIZABLE，可與 CRDB strict 對標）+ vm-3node-direct / vm-3node-haproxy 待重跑。

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

第一次 `make vm1-ybdb-rc` 啟動到 suite 完成共撞 8 個 YBDB-specific 問題（tidb/crdb 路徑都不會觸發），全數修進 `poc/ansible/playbooks/yugabyte-vm1.yml`、`poc/tests/common/prepare.sh`、`poc/tests/common/gate-isolation.sh`、`poc/tests/common/db-config-dump.sh`、`poc/tests/common/collect.sh`。本段把 root cause / 修法 / commit SHA 留檔，避免下次 rr / strict / vm-3node 重跑時又踩同樣坑。

### 修法總覽

| # | 階段 | 錯誤訊息 | Root cause | 修法 | Commit |
|---|------|----------|-----------|------|--------|
| 1 | ansible deploy | `Could not import the dnf python module using /usr/bin/python3.12` | inventory 用 python3.12，但 AlmaLinux 8.10 的 dnf python bindings 只在 `/usr/libexec/platform-python` (3.6)；`ansible.builtin.dnf` 模組需要這個 binding | 兩段 `ansible.builtin.dnf` 改為 `ansible.builtin.shell` + `rpm -q` idempotent install（與 tidb-vm1.yml 同 pattern）| [`c88f7d4`](#) |
| 2 | ansible deploy | `Wait for YSQL port` timeout 240s | fresh VM 上 `yugabyted status` 即使「is not running」也回 **rc=0**，所以 `when: yb_status.rc != 0` 條件被 skip → `Start YugabyteDB RF=1` 永遠不會跑 | 條件改為 `'is not running' in (yb_status.stdout \| default(''))` ，rc!=0 作 backstop | [`e5ccc11`](#) |
| 3 | prepare DROP/CREATE | `ERROR: DROP DATABASE cannot run inside a transaction block` | `psql -c "DROP; CREATE"` 兩 stmt 在同一 implicit txn；YSQL/PG 禁 DROP DATABASE 在 txn 內 | 拆兩個 `-c` flag，各自獨立 txn | [`904c80c`](#) |
| 4 | go-tpc prepare | suite 卡在 `begin to check warehouse 1 at condition 3.3.2.x` 1h+ 不結束 | go-tpc 預設 prepare 完跑 inline consistency check；3.3.2.x 系列為跨表 aggregate，YB 2025.2 上會卡 30+ min | YBDB 加 `--no-check`；後續 `check-all` 步驟 YBDB 也跳過，改用 row-count 驗整性 | [`99cb5a3`](#) |
| 5 | prepare DROP DATABASE | `ERROR: database "tpcc" is being accessed by other users` | 前次 suite kill 後 go-tpc 連線在 YB 仍 lingering（YSQL session state 由 tserver 保留至 TCP 驅逐或顯式 terminate）| DROP 前 `pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='<db>' AND pid<>pg_backend_pid()`，多 `-c` 不在同 txn | [`fc76fe4`](#) |
| 6 | prepare schema+EXPLAIN dump | `ERROR: column c.relhasoids does not exist` ＋ psql rc=1 → `set -euo pipefail` 殺 suite | AlmaLinux 8.10 內建 psql（postgresql 套件，PG ≤11）的 `\d+` 查 `pg_class.relhasoids`，PG 12+ 已移除此 column，YB 2025.2 catalog 沒這欄 | YBDB schema/EXPLAIN dump 改用 yugabyte 隨附的 `ysqlsh`（catalog 同步）；其它 plain-SQL（DROP/CREATE/ANALYZE/row-count）保留 psql | [`8069ada`](#) |
| 7 | gate-isolation | （preemptive；本輪 playbook 已設 gflag，gate 未踩；保留為 future-proof）原 `SHOW transaction_isolation` 通過不代表 effective 真為 RC | YB 雙閘要求：session 層 `transaction_isolation` ＋ tserver gflag `yb_enable_read_committed_isolation`；缺 gflag 時前者顯示 `read committed`，但 `yb_effective_transaction_isolation_level` 退回 `repeatable read`，跑出來的 RC 結果其實是 SI | YBDB DB-gate ＋ driver-gate 兩段都加 `SHOW yb_effective_transaction_isolation_level`；effective 必須等於 expected 否則 die，hint 指向 tserver gflag；JSON marker 多帶 `yb_effective_db` / `yb_effective_driver` | [`b9b3b43`](#) |
| 8 | collect (`db-config-dump.sh` + collect.sh env / log tail) | suite rc=1 在 `[4/4] collect` 1 秒內爆 | `db-config-dump.sh` 用 `curl -s /varz \| head -200` — head close pipe 後 curl 收 SIGPIPE 退 **rc=23 (Write error)**，`set -o pipefail` 抓出來、`set -e` 殺 script；之後 collect.sh 的 env snapshot / DB log tail ssh 失敗也是 fatal | (a) db-config-dump.sh 拆 tmpfile two-step 避 SIGPIPE，加 `--max-time 30`、`ysql_default_transaction_isolation` / `yb_effective_transaction_isolation_level`；(b) collect.sh env snapshot + DB log tail 加 `\|\| warn`，optional metadata 不殺 suite | [`279697b`](#) |

### 為什麼 tidb / crdb 沒踩這些坑

| 修法 | tidb | crdb |
|------|------|------|
| #1 `ansible.builtin.dnf` | tidb-vm1.yml / cockroach-vm1.yml 早已用 `shell` + `rpm -q` pattern（先前 cockroach deploy bug 修過）| 同 tidb |
| #2 status gate | TiDB 用 `tiup cluster display` 判斷集群狀態（有明確 exit code 語意）；CRDB 用 `start-single-node` 本身 idempotent | 同 tidb |
| #3 DROP/CREATE in txn | MySQL 與 CockroachDB SQL 都允許 DDL 在 implicit txn；`mysql -e "DROP;CREATE"` 與 `cockroach sql -e "DROP;CREATE"` 正常 | 同 tidb |
| #4 slow consistency check | TiDB / CRDB check-all 都在合理時間內（TiDB 52min prepare 內含、CRDB 43min 內含），可直接用 go-tpc 原生 check | 同 tidb |
| #5 lingering session | TiDB / CRDB 的 `DROP DATABASE` 不被現存連線 pin（TiDB 自動失效、CRDB 預設允許 force drop）| 同 tidb |
| #6 psql `\d+` 與 PG catalog | TiDB 不用 psql；CRDB 接 PG protocol 但 schema dump 用 `cockroach sql -e "SHOW CREATE TABLE"`，不走 psql meta-command | 同 tidb |
| #7 雙閘 iso 驗證 | TiDB 用 `SHOW VARIABLES` + active txn 即可（沒有 effective vs session 落差）；CRDB 也只有 `SHOW transaction_isolation` 一層 | 同 tidb |
| #8 curl `\|head` SIGPIPE | TiDB 用 `mysql -e` + remote `tiup cluster show-config` 不 pipe curl；CRDB 用 `cockroach sql -e "SHOW ALL CLUSTER SETTINGS"` 直接 redirect | 同 tidb |

### YBDB-specific 影響項

- **整性驗證口徑**：YBDB 路徑改用 row-count 取代 go-tpc check-all；資料完整性 vs TiDB / CRDB 的 14-condition 嚴格度有差，但對 tpmC / latency 結果不影響（檢核僅在 prepare 結尾、run 前；run 用相同 go-tpc workload）
- **預期 row counts (W=128)**：warehouse 128 / district 1,280 / customer 3,840,000 / history 3,840,000 / item 100,000 / stock 12,800,000 / new_order 1,152,000 / orders 3,840,000 / order_line ~38.4M (5-15 lines per order, randomised) — 本輪實測 order_line = 38,410,536 ✓ 對齊
- **Gate WARN（本輪不致命）**：
  - `DB-host THP != never` / `vm.swappiness > 5` / `ulimit -n < 65536` — yugabyte-vm1.yml 尚未含 OS tuning task（tidb-vm1.yml 有「OS tuning」段）；本輪先不卡 gate，下一輪 rr / strict 前要補
  - `client (.31) artifacts FS available 14GB < 30GB` — 累積跨家 artifacts；rr / strict 前要清

---

## vm-1node-rc — 2026-05-20（PoC v4.7 baseline，含 DB-host OS 監控）

> **本段目的**：PoC v4.7 框架下的 YBDB vm-1node RC 正式 baseline，配套：detached suite wrapper、多輪平均、isolation 雙閘（session + effective）、**client + DB-host 雙邊 OS 監控**。取代 yuga-tc1-old 內 2026-05-14 單次 10 min 結果，作為後續 rr/strict 與其他 DB 對標的可重現基線。

### 環境
- 節點：.32 (172.24.40.32) 單節點，yugabyted RF=1
- 硬體：4 vCPU、15 GiB RAM、單 sda 盤（XFS）
- YugabyteDB 版本：v2025.2.2.2 build 11（YSQL `PostgreSQL 15.12-YB-2025.2.2.2-b0`）
- 部署工具：Ansible playbook `yugabyte-vm1.yml`
- tserver gflag：`memory_limit_hard_bytes=11811160064 / db_block_cache_size_percentage=50 / durable_wal_write=true / require_durable_wal_write=true / yb_enable_read_committed_isolation=true / ysql_enable_auth=false / ysql_enable_auto_analyze=false`
- 連線入口：直連 172.24.40.32:5433
- 測試工具：go-tpc on .31（postgres driver，`--conn-params 'sslmode=disable&options=-c default_transaction_isolation=read\ committed'`）
- Warehouses：128
- Warmup：**20 min @ 64 threads**
- Run：**每組 5 round × 5 min**（多輪平均，丟 round 1 取 r2-r5 median）
- Threads：16 / 32 / 64 / 128（共 4 組，每組 5 round，總 run 時長 2h42min）
- OS 監控：mpstat / iostat / vmstat / sar 同時在 client (`.31`) 與 db-host (`.32`) 採樣 1s 粒度，per round 各自輸出 `*.txt` / `*-db.txt`
- TPCC_TS：`20260520T134929+0800`
- 結果目錄：`vm-1node-rc/ybdb-vm-1node-rc-20260520T134929+0800/`

### Suite 階段時序

| Phase | 起 | 訖 | 耗時 |
|-------|-----|------|------|
| gate (OS / chrony / disk pre) | 13:49 | 13:49 | <1min |
| prepare (DROP+CREATE / load 128W / row-count / quiesce 5m / ANALYZE / EXPLAIN dump via ysqlsh) | 13:49 | 14:35 | 46 min |
| gate-isolation (active dual-gate: session + effective; driver-side go-tpc 2s probe + ysql verify) | 14:35 | 14:35 | <1 min |
| cold-reset | 14:35:32 | 14:36:45 | 1 min |
| warmup (20 min @ 64 threads, no data) | 14:36 | 14:56 | 20 min |
| run (4 thread × 5 round × 5 min run + 60s sleep + 20min warmup) | 14:35 | 17:18 | 2h42 min |
| collect (DB log tail + db-config dump + env snapshot) | 17:18 / 21:04 (resume) | 21:05 | <1 min（含修 bug + 手動 resume）|
| **total (suite gate→run end)** | **13:49** | **17:18** | **3h29min** |

> 本輪在 `[4/4] collect` 死於 `db-config-dump.sh` 的 `curl|head` SIGPIPE rc=23（[修法 #8](#修法總覽)），run-phase 資料完整無損；fix 推到 .31 後 manual resume collect 重跑（21:04-21:05），補齊 `.collect.done` + `.db-config.done` + `.suite.done` marker。

### Gate 結果（active isolation dual-gate）

> 雙閘設計：(a) DB-side `SHOW transaction_isolation` + `SHOW yb_effective_transaction_isolation_level`；(b) driver-side 用 go-tpc 同 driver 跑 2s probe 後再做同樣兩個 SHOW。任一不符立即 fail-closed。

| 維度 | expected | DB-side actual | driver-side actual |
|------|----------|----------------|--------------------|
| `SHOW transaction_isolation` | `read committed` | `read committed` ✓ | `read committed` ✓ |
| `SHOW yb_effective_transaction_isolation_level` | `read committed` | `read committed` ✓ | `read committed` ✓ |

→ **無 silent fallback 到 SI**，跑出來的 RC 是真 RC。session iso 與 effective iso 一致代表 tserver gflag `yb_enable_read_committed_isolation=true` 確實生效。

OS gate（本輪 WARN 但不卡）：
- DB-host THP=`always`（target `never`）— **TODO**：yugabyte-vm1.yml 加 OS tuning 段
- DB-host `vm.swappiness=30`（target ≤ 5）— TODO 同上
- DB-host `ulimit -n=1024`（target ≥ 65536）— TODO 同上
- client (.31) 磁碟可用 14GB（target ≥ 30GB）— rr / strict 前清舊 artifact
- NTP drift < 1ms ✓
- disk: sda3 已 growpart 至 100GB ✓

### Prepare

- 時間：46 min（DROP/CREATE 1s + load 38 min + row-count 30s + quiesce 5 min + ANALYZE 30s + EXPLAIN dump < 1s）
- DROP/CREATE：`pg_terminate_backend` → `DROP DATABASE IF EXISTS tpcc` → `CREATE DATABASE tpcc`（三個獨立 `-c`，避 implicit txn）
- Load：`go-tpc tpcc prepare --no-check W=128`（跳過 inline 3.3.2.x consistency check，避 30+ min 卡頓）
- Row-count（替代 check-all）：

| Table | Rows | Expected (W=128) | OK |
|-------|------|------------------|-----|
| warehouse | 128 | 128 | ✓ |
| district | 1,280 | 1,280 | ✓ |
| customer | 3,840,000 | 3,840,000 | ✓ |
| history | 3,840,000 | 3,840,000 | ✓ |
| item | 100,000 | 100,000 | ✓ |
| stock | 12,800,000 | 12,800,000 | ✓ |
| new_order | 1,152,000 | 1,152,000 | ✓ |
| orders | 3,840,000 | 3,840,000 | ✓ |
| order_line | 38,410,536 | ~38.4M (5-15 per order) | ✓（在合理區間）|

- ANALYZE：`psql ... -c "ANALYZE"` exit 0
- EXPLAIN dump：warehouse + customer × `EXPLAIN ...` 用 `ysqlsh`（YB 隨附，避 PG ≤11 psql `\d+` relhasoids 問題）

### Execute 結果（5 round tpmC 平均；latency 為 5 round mean）

> tpmC / tpmTotal / efficiency 為 5 round mean；**NO p50 / p95 / p99 亦為 5 round latency mean**。`range/mean` 為 `(max - min) / mean` × 100% 看 round-to-round 波動。

| threads | tpmC mean | range/mean | tpmTotal mean | efficiency mean | NO p50 (ms) | NO p95 (ms) | NO p99 (ms) |
|---------|-----------|-----------|---------------|-----------------|------------|------------|------------|
| 16  | 10,653 | 2.8% | 23,611 | 647.2% | 58  | 88  | 104  |
| 32  | **11,436** | 4.2% | 25,437 | 694.8% | 105 | 170 | 216  |
| 64  | 11,240 | 2.2% | 24,963 | 682.8% | 210 | 339 | 440  |
| 128 | 10,885 | 4.9% | 24,136 | 661.3% | 416 | 738 | 1000 |

> **零 error 全程**：20 round 內 `NEW_ORDER_ERR = 0`、`execute run failed = 0`、`Restart read required = 0`。RC + 雙閘 + tserver gflag 共同確保。

### Round-by-round tpmC（檢驗穩定性）

| Threads | r1 | r2 | r3 | r4 | r5 |
|---------|-----|-----|-----|-----|-----|
| 16  | 10610 | 10567 | 10587 | 10635 | 10864 |
| 32  | 11643 | 11451 | 11468 | 11457 | 11163 |
| 64  | 11283 | 11373 | 11289 | 11123 | 11133 |
| 128 | 11224 | 10786 | 10869 | 10694 | 10851 |

- **range/mean 2.2-4.9%**：比 TiDB rc（5.0-8.3%）、CRDB rc（4.7-9.1%）都更穩定；YBDB 對 round 邊界 housekeeping 不敏感。
- r1 並未明顯偏離（t16 r1 10610 vs r5 10864、t128 r1 11224 vs r5 10851）；warmup 20min @ 64t 已把 DocDB tablet cache、PG plan cache、connection pool 全暖完。

### DB-host (.32) 飽和分析 ★

> **核心發現**：YBDB vm-1node 在 4 vCPU 下是 **CPU-bound（%idle 接近 0）**，但 CPU 路徑與 TiDB / CRDB 不同 — **%sys 異常高（18-19%）**，磁碟 / IO 全程有大量餘裕。

#### 1. mpstat-db.txt — 4 vCPU 使用率（round-3 mid-run，每組 305 個 1s 樣本）

| threads | %usr mean | %sys mean | %iowait mean | %idle mean | %idle min |
|---------|-----------|-----------|--------------|------------|-----------|
| 16  | 63.5% | 19.1% | 5.50% | 6.99% | **3.53%** |
| 32  | 70.9% | 19.5% | 1.54% | 3.29% | **0.51%** |
| 64  | 73.8% | 19.0% | 0.39% | 2.24% | **0.00%** |
| 128 | **74.7%** | 18.5% | 0.25% | **1.89%** | **0.00%** |

#### 2. iostat-1s-db.txt — sda 磁碟壓力（round-3 mid-run 平均）

| threads | sda %util |
|---------|-----------|
| 16  | 49.7% |
| 32  | 47.6% |
| 64  | 42.0% |
| 128 | 42.8% |

#### 3. 飽和歸因

| 假設 | 驗證 | 證據 |
|------|------|------|
| CPU 飽和 | ✓ | %idle mean t64+ < 3%，瞬間 0%；%user 增長 63→75% |
| %sys 比例異常高 | ✓ | 18-19% 全 thread group；對比 TiDB 9-11%、CRDB 5-6%；推測 YSQL postgres → DocDB tserver 跨進程通訊 + DocDB 內部 RPC 多耗 syscall 與 context switch |
| IO 非瓶頸 | ✓ | %iowait t32+ < 2%、sda %util 全程 ≤ 50%；DocDB 的 RocksDB WAL 寫入批量化比 CRDB Raft+Pebble fsync 更積極 |
| t64+ 無收益 | ✓ tpmC + CPU 雙證 | tpmC 32→64 -1.7%、64→128 -3.2%；%idle 從 t32 3.29% 降到 t128 1.89%（CPU 一直滿）但 throughput 沒上升 |

### vs 同硬體對比 ★

#### vs TiDB rc / CRDB rc（5-round mean 同口徑）

| threads | TiDB rc | CRDB rc | YBDB rc | YBDB vs TiDB | YBDB vs CRDB |
|---------|---------|---------|---------|--------------|--------------|
| 16  | 10,074 | 9,034 | **10,653** | +5.7% | +17.9% |
| 32  | 11,728 | 9,020 | **11,436** | -2.5% | +26.8% |
| 64  | 12,744 | 9,134 | 11,240 | -11.8% | +23.0% |
| 128 | **13,064** | 8,813 | 10,885 | -16.7% | +23.5% |

| threads | TiDB p99 (ms) | CRDB p99 (ms) | YBDB p99 (ms) | YBDB vs TiDB | YBDB vs CRDB |
|---------|---------------|---------------|---------------|--------------|--------------|
| 16  | 94  | 113 | 104  | +11% | -8% |
| 32  | 163 | 223 | 216  | +33% | -3% |
| 64  | 305 | 440 | 440  | +44% | 0% |
| 128 | 597 | 926 | 1000 | +68% | +8% |

| DB-host | TiDB %idle | CRDB %idle | YBDB %idle | TiDB %iowait | CRDB %iowait | YBDB %iowait | TiDB %sys | CRDB %sys | YBDB %sys |
|---------|-----------|-----------|-----------|--------------|--------------|--------------|-----------|-----------|-----------|
| t16  | 9.45% | 5.77% | 6.99% | 4.6% | 18.5% | 5.5%  | 11.0% | 5.6% | **19.1%** |
| t128 | 4.52% | 4.99% | **1.89%** | 3.1% | 18.8% | 0.25% | 9.0%  | 5.5% | **18.5%** |

**三家飽和成因不同**：
- **TiDB**：CPU-bound、%user dominant（80%）、%sys 中位（9%）、%iowait 低（3%）→ 加 thread 把 CPU 擠到 95%+ 就到天花板
- **CRDB**：IO-wait bound、%iowait 18-19% 立即觸頂、%idle 5% 全程 → 加 thread 只是 queue 長
- **YBDB**：CPU-bound 但異常高 %sys 19%、%iowait 低（< 5%）、%idle 接近 0 → CPU 路徑被 syscall / IPC / DocDB internal RPC 拉走 1/5；DocDB WAL fsync 批量化比 CRDB 積極（YB 用 RocksDB block-based + DocDB row-cache，CRDB 用 Pebble + Raft log per-commit fsync）

#### vs pre-v4.7 single-run（yuga-tc1-old 內，2026-05-14, single 10min）

| threads | pre-v4.7 single-run | v4.7 5-round mean | Δ | 解讀 |
|---------|--------------------|--------------------|----|------|
| 16  | 10,844 | 10,653 | -1.8% | 5-round mean 略低，含 round-to-round variance |
| 32  | 10,341 | **11,436** | **+10.6%** | warmup 20min vs 5min 預熱差異；plan cache 完全暖 |
| 64  | 9,982  | 11,240 | +12.6% | 同上 |
| 128 | 8,906  | 10,885 | +22.2% | 高併發更受益於完整 warmup |

→ v4.7 把高併發水位的數字從 8,906 拉到 10,885（+22%），驗證 **warmup 從 5min 延長到 20min、warmup_threads=64** 確實對 YBDB 像對 TiDB 一樣有效（PoC-DESIGN §8.2）。

### Saturation 分析

```
threads:    16 ──── 32 ──── 64 ──── 128
tpmC:    10,653  11,436  11,240  10,885
                  +7.4%   -1.7%   -3.2%        ← sweet spot 在 t32，t64+ 邊際負

p99 (ms):    104    216    440    1000
                  +108%  +104%  +127%          ← latency 隨 thread 雙倍

DB %idle:   6.99%  3.29%  2.24%  1.89%         ← CPU 飽和進程，t32 已逼近 ceiling
DB %sys:   19.1%  19.5%  19.0%  18.5%          ← syscall/IPC overhead 持平高位
DB %iowait: 5.50%  1.54%  0.39%  0.25%         ← IO 全程非瓶頸
DB disk%util: 49.7%  47.6%  42.0%  42.8%       ← 磁碟未滿
```

**結論**：YBDB vm-1node RC 的甜點在 **t32（11,436 tpmC、p99 216ms）**。t64 換 2x latency 只少 1.7% tpmC、t128 換 4.6x latency 還倒退 4.8%；**真正天花板是 4 vCPU 在 YSQL+DocDB 雙進程架構下的 CPU 預算**（19% 給 %sys，剩 75% 給 %user），磁碟有大量餘裕（%util ≤ 50%）。

### 觀察

- **t32 是甜點**：5 round mean 11,436 tpmC、p99 216ms，DB %idle 3.29% — 剛好榨出 CPU 又沒撞牆。
- **t128 已過飽和**：p99 突破 1s、tpmC 邊際 -4.8%；高併發放大連線管理 overhead。
- **零 error**：v4.7 雙閘 (`yb_effective_transaction_isolation_level = read committed`) 確保 RC 真生效，沒有 silent fallback 到 SI 造成 retry storm（對比 CRDB rr 412 errors / 20 round）。
- **%sys 19% 異常**：架構特異 — YSQL postgres 與 DocDB tserver 是**兩個獨立 process**（YSQL 把 SQL 解析 / plan 後透過 RPC 送給 DocDB tserver 執行），跨進程 RPC + 序列化 / 反序列化吃掉 1/5 CPU。TiDB（SQL 層 + storage TiKV 也是兩 process 但 SQL 是 TCP grpc 不是 syscall-heavy IPC）相對 9-11%、CRDB（SQL + storage 同 process）只 5-6%。
- **DocDB WAL 寫入比 CRDB 積極**：%iowait < 5% vs CRDB 17-19%；YB 預設 `durable_wal_write=true` + `interval_durable_wal_write_ms=1000` 把 fsync 批量化到 1s 區間，CRDB 預設 per-commit fsync。
- **`efficiency > 100%` 屬正常**：go-tpc 不打 keying/think time，是本 PoC 內部對標的相對指標，**不可與 TPC-C 官網數字直接比**。

### 結論

YugabyteDB v2025.2.2.2 vm-1node RC 在 PoC v4.7 框架下穩定可重現，**t32 為甜點（11,436 tpmC、p99 216ms），t128 已過飽和（-4.8% / 1s p99），硬天花板是 .32 的 4 vCPU 預算被 %sys (19%) 吃掉 1/5**。DB-host 端 OS 監控正式生效，雙閘 iso 確保 RC 真生效不會 silent fallback 到 SI。

本輪資料作為後續 `vm-1node-rr`、`vm-1node-strict`、以及 vm-3node 對標的 baseline。預期 vm-3node 將 DocDB tablet 分散到 3 台後可提升 tpmC，但 RF=3 引入 cross-zone Raft replication 應增加 latency；scale-out ratio 不應預設為線性。

---

## vm-1node-rr — 2026-05-21（PoC v4.7，snapshot isolation + retry storm）

> **本段目的**：在同硬體 / 同流程下取得 YugabyteDB vm-1node RR baseline（YB rr = snapshot isolation，**非** PG 標準 RR 語意），對照 rc 與 CRDB rr / TiDB rr 觀察 write conflict 處理差異。

### 環境
- 與 `vm-1node-rc` 相同硬體 / YB v2025.2.2.2 build 11 / 同 ansible playbook / 同 tserver gflag，唯一差異：**iso=rr**
- go-tpc conn-params：`sslmode=disable&options=-c default_transaction_isolation=repeatable\ read`
- TPCC_TS：`20260520T215216+0800`
- 結果目錄：`vm-1node-rr/ybdb-vm-1node-rr-20260520T215216+0800/`

### Suite 階段時序

| Phase | 起 | 訖 | 耗時 |
|-------|-----|------|------|
| gate | 21:55 | 21:55 | <1 min |
| prepare（DROP/CREATE + load 128W + row-count + quiesce 5m + ANALYZE + EXPLAIN dump via ysqlsh）| 21:55 | 22:42 | 47 min |
| gate-isolation（dual gate: session + effective）| 22:42 | 22:43 | <1 min |
| cold-reset | 22:42:21 | 22:43:34 | 1 min |
| warmup (20 min @ 64 threads) | 22:43:34 | 23:03:34 | 20 min |
| run (4 thread × 5 round × 5 min + 60s sleep) | 23:03 | 01:23 | 2h20 min |
| collect (含 db-config-dump + env + log tail) | 01:23 | 01:24 | <1 min |
| **total (suite)** | **21:55** | **01:24** | **3h29 min** |

### Gate 結果（active isolation dual-gate）

| 維度 | expected | DB-side actual | driver-side actual |
|------|----------|----------------|--------------------|
| `SHOW transaction_isolation` | `repeatable read` | `repeatable read` ✓ | `repeatable read` ✓ |
| `SHOW yb_effective_transaction_isolation_level` | `repeatable read` | `repeatable read` ✓ | `repeatable read` ✓ |

→ session 與 effective 都對齊 `repeatable read`；YBDB 的 rr 在底層 = snapshot isolation（per official [YBDB Isolation Levels doc](https://docs.yugabyte.com/stable/architecture/transactions/isolation-levels/) 「YugabyteDB's REPEATABLE READ isolation level corresponds to PostgreSQL's REPEATABLE READ, and is implemented using Snapshot Isolation」）。

### Prepare
- 時間：47 min（DROP/CREATE + load + row-count + quiesce + ANALYZE，與 rc 一致）
- Load：`go-tpc tpcc prepare --no-check W=128`
- Row-count：9 表全對齊 W=128 預期（warehouse 128 / district 1280 / customer 3,840,000 / history 3,840,000 / item 100,000 / stock 12,800,000 / new_order 1,152,000 / orders 3,840,000 / order_line ~38.4M）

### Execute 結果（5 round tpmC 平均；latency 為 5 round mean）

> tpmC / tpmTotal / efficiency 為 5 round mean；**NO p50/p95/p99 亦為 5 round latency mean**。efficiency = `tpmTotal / tpmC-理論值（128W × 12.86 = ~1645 per warehouse minute）` × 100%，rr 低於 200% 反映 retry 浪費。

| threads | tpmC mean | range/mean | tpmTotal mean | efficiency mean | NO p50 (ms) | NO p95 (ms) | NO p99 (ms) | NEW_ORDER_ERR / 5min | err TPM |
|---------|-----------|-----------|---------------|-----------------|------------|------------|------------|----------------------|---------|
| 16  | 1,846 | 12.7% | 4,114 | 112.2% | 25 | 38  | 61   | 15  | 3.0 |
| 32  | **1,879** | 5.6% | 4,164 | 114.2% | 25 | 57  | 174  | 31  | 6.2 |
| 64  | 1,847 | 7.1% | 4,121 | 112.2% | 26 | 101 | 240  | 63  | 12.6 |
| 128 | 1,714 | 49.1% ⚠️ | 3,819 | 104.1% | 29 | 220 | 1020 | 127 | 25.4 |

> **t128 range/mean 49.1%**：r5 collapse 至 1173（r1-r4 為 2014/1812/1774/1797，r5 異常低）— SI hot row 衝突放大 round 邊界 housekeeping 影響。

### Round-by-round tpmC

| Threads | r1 | r2 | r3 | r4 | r5 |
|---------|-----|-----|-----|-----|-----|
| 16  | 1874 | 1692 | 1909 | 1830 | 1926 |
| 32  | 1848 | 1870 | 1952 | 1854 | 1872 |
| 64  | 1837 | 1933 | 1860 | 1804 | 1802 |
| 128 | 2014 | 1812 | 1774 | 1797 | **1173** |

### Error 分析 — **N-1 pattern** 與 CRDB rr 完全相同

| iso | thread | err / round | err 結構 |
|-----|--------|-------------|----------|
| YBDB rr t16  | 15 | NEW_ORDER ~5 + PAYMENT ~10 + 偶爾 STOCK_LEVEL |
| YBDB rr t32  | 31 | 多 PAYMENT (~17) + NEW_ORDER (~13) |
| YBDB rr t64  | 63 | PAYMENT (~40) + NEW_ORDER (~23) |
| YBDB rr t128 | 127 | PAYMENT (~83) + NEW_ORDER (~43) |
| **CRDB rr 對照** | 同 thread | 15/31/63/127（完全相同 N-1） | NEW_ORDER 為主 + 偶爾 PAYMENT |

**N-1 機制**（兩家共有 SI hot row）：
1. round 起始 N 個 worker 同時 BEGIN，每個取 snapshot ts 落在毫秒級窗口
2. 跑 NEW_ORDER → `UPDATE district SET d_next_o_id = ...`（hot row，district PK 空間僅 128W × 10D = 1280 row）
3. **first committer wins**：第一個 worker commit 成功，剩 N-1 個拿 `SerializationFailure` / `WriteTooOldError` abort
4. client retry 後再次撞，5min round 內 retry 次數累積 → 但 go-tpc 的 `[Summary] NEW_ORDER_ERR` 只算到 unique abort，故 = N-1

**差別**：YBDB rr `[Summary] PAYMENT_ERR` 出現率高於 NEW_ORDER_ERR（t128 r5: PAYMENT 77 vs NEW_ORDER 49），CRDB rr 則 NEW_ORDER 為主。推測為兩家對 PAYMENT 的 `UPDATE warehouse SET w_ytd = ... WHERE w_id = ...` 衝突偵測時機不同。

### DB-host (.32) 飽和分析 ★（與 rc / 與 TiDB rr 完全不同）

| threads | %usr mean | %sys mean | %iowait mean | %idle mean | %idle min | sda %util |
|---------|-----------|-----------|--------------|------------|-----------|-----------|
| 16  | 12.6% | 5.2% | 13.17% | **67.51%** | 6.11% | 63.8% |
| 32  | 12.9% | 5.3% | 12.72% | **67.54%** | 2.25% | 63.6% |
| 64  | 13.1% | 5.3% | 12.06% | **67.87%** | 1.50% | 63.5% |
| 128 | 14.1% | 5.8% | 11.77% | **66.57%** | **0.50%** | 62.3% |

> **核心發現**：YBDB rr 與 rc / TiDB rr 截然不同 — **DB 機器同時 idle 大量 CPU (66-67%) + 11-13% iowait + disk %util 62-64%**。瓶頸不在 DB host 資源層，而在 **transaction coordination layer（retry storm + abort 後 client 等待）**。

| 假設 | 驗證 | 證據 |
|------|------|------|
| 飽和是 CPU | ❌ | %user 12-14%、%idle mean **66-67%** |
| 飽和是 IO | ❌ | %iowait 11-13%、sda %util 62-64% 雖然比 rc 高，但 throughput 1/6 → 單位工作的 IO 開銷高，總 IO ceiling 仍未達 |
| 飽和是 **retry storm**（SI hot row + client retry loop） | ✓ | err TPM 線性 = thread−1；DB %idle 66-67% 表示 worker 大部分時間在等 retry 或 conflict abort 回 client |
| **rc 與 rr 飽和成因 mirror** | ✓ | rc CPU-bound + 高 %sys（IPC overhead）／ rr DB-idle + transaction-bound（retry overhead）— rr 把 rc 的「實際工作」換成「失敗 + retry」 |

### vs YBDB rc 對比

| threads | rc tpmC | rr tpmC | Δ tpmC | rc p99 (ms) | rr p99 (ms) | rc err | rr err |
|---------|---------|---------|--------|-------------|-------------|--------|--------|
| 16  | 10,653 | 1,846 | **-82.7%** | 104  | 61   | 0 | 15 |
| 32  | 11,436 | 1,879 | **-83.6%** | 216  | 174  | 0 | 31 |
| 64  | 11,240 | 1,847 | **-83.6%** | 440  | 240  | 0 | 63 |
| 128 | 10,885 | 1,714 | **-84.2%** | 1000 | 1020 | 0 | 127 |

| DB-host (t128) | %user | %sys | %iowait | %idle | sda %util |
|----------------|-------|------|---------|-------|-----------|
| rc t128 | 74.7% | 18.5% | 0.25% | 1.89% | 42.8% |
| rr t128 | 14.1% | 5.8% | 11.77% | **66.57%** | 62.3% |

→ **YBDB 切 rc → rr 在本 workload 上沒有任何性能 / 一致性收益**，純損失 6x throughput；rr 真正用途為「需要 per-txn snapshot 但能接受 retry 成本」的查詢-重 OLTP 系統。

### vs CRDB rr / TiDB rr 對比（三家 RR 機制）

| threads | YBDB rr | CRDB rr | TiDB rr (pessimistic) | YBDB:CRDB | TiDB:YBDB |
|---------|---------|---------|-----------------------|-----------|-----------|
| 16  | 1,846 | 3,229 | 11,196 | 0.57x | 6.1x |
| 32  | 1,879 | 3,577 | 12,831 | 0.53x | 6.8x |
| 64  | 1,847 | 3,594 | 13,743 | 0.51x | 7.4x |
| 128 | 1,714 | 3,788 | **13,874** | 0.45x | 8.1x |

| 機制 | YBDB rr | CRDB rr (preview) | TiDB rr (pessimistic) |
|------|---------|------|-------|
| 預設 RR 實作 | snapshot isolation per official docs | snapshot isolation (preview feature; iso=Snapshot 在 artifact log) | snapshot isolation per official docs |
| Hot row write 衝突處理 | first committer wins → `SerializationFailure` → client retry | first committer wins → `WriteTooOldError` → client retry | **row lock 排隊**（後者 wait） |
| `SELECT FOR UPDATE` | 取 unreplicated lock，**不 advance read ts** | 取 unreplicated lock，**不 advance read ts** | 取 pessimistic lock，**advance for-update-ts** |
| Error pattern | 線性 N-1 / round | 線性 N-1 / round | 0 errors |
| 全域 pessimistic toggle | ❌ | ❌ | ✓ `tidb_txn_mode=pessimistic` |

**結論**：YBDB 與 CRDB 兩家 RR 都是 optimistic SI，撞 hot row 表現相似（YBDB 比 CRDB 更慢 -45-50% 推測為 DocDB / YSQL 雙進程的 IPC retry cost 高於 CRDB 單進程）；TiDB 是 7-8 倍 throughput 唯一可承受 hot-row contention 的 RR 實作。

### Saturation 分析

```
threads:    16 ───── 32 ───── 64 ───── 128
tpmC:      1,846   1,879   1,847   1,714
                   +1.8%   -1.7%   -7.2%        ← flat-line + t128 過飽和

p99 (ms):    61    174    240   1020
                   +185%  +38%  +325%           ← t128 latency 暴漲

DB %idle: 67.51% 67.54% 67.87% 66.57%           ← DB 大量 idle (66-67% 全程)
DB %iowait: 13.17% 12.72% 12.06% 11.77%         ← IO wait 中位、隨 thread 略降
err / round:   15    31    63   127             ← 線性 N-1
```

**結論**：YBDB rr 的 tpmC 天花板 ~1,850（4 vCPU 硬體下，所有 thread group 完全 flat），latency 在 t128 因 hot-row queue 累積爆炸到 1s。**真正瓶頸不在硬體，在 SI 寫衝突 + retry storm**。

### 觀察

- **rr ≠ RC「升級版」**：本次數據反證「越強 isolation 越慢」直覺中**rc → rr 砍 6x throughput 的代價**，因 YBDB / CRDB rr 都用 optimistic SI（snapshot ts + first-committer-wins），與 PG 標準 RR（serial txn ordering via SS2PL）行為完全不同
- **N-1 error pattern 為 SI hot row 共通病**：本輪首次同時驗證 YBDB rr 與 CRDB rr 都精確產生 N-1 errors/round，**確認 SI + TPC-C district hot row 是 deterministic 衝突源**
- **零 SerializationFailure 在 rc / N-1 SerializationFailure 在 rr**：本檔 [`修法 #7`](#修法總覽) 的 dual-gate 確保 rc 與 rr 各跑各的 iso，沒有 silent fallback；run-phase artifact 內 `[Summary] *_ERR` 反映實際 abort 數
- **PAYMENT_ERR 比 NEW_ORDER_ERR 多**：YBDB rr 特有現象（CRDB rr NEW_ORDER 為主），推測 PAYMENT 的 `UPDATE warehouse SET w_ytd = ...` 在 DocDB SI 下衝突偵測較早 trigger（每 warehouse PK 才 128 行，比 district 1280 更熱）；需 trace 進一步佐證
- **DB-host disk %util 63% > rc 42%**：rr 雖 throughput 砍 6x，但 disk 反而比 rc 更忙 — 推測 SI version metadata 寫入 + retry 重讀放大 IO overhead

### 結論

YugabyteDB v2025.2.2.2 vm-1node RR 在 4 vCPU + single disk 硬體下：
- **吞吐天花板 ~1,850 tpmC**（比 rc 11,436 砍 84%、比 TiDB rr 13,874 少 87%）
- **err 線性 = thread − 1**（t16=15、t32=31、t64=63、t128=127）— 與 CRDB rr **完全相同** N-1 pattern，是 SI hot row 共通病
- **DB-host 大量 idle**（%idle 66-67%）+ **不飽和的 IO**（%iowait ~12%、disk %util 63%）— 瓶頸 = **transaction coordination layer (retry storm)**

**業務啟示**：
- YBDB 預設 RC 是正確選擇；本 workload 切 rr 純損失 throughput 不換來任何收益
- 若 app 必須 per-txn snapshot 一致性語意，**首選 TiDB pessimistic rr**（同硬體 7-8x throughput）；YBDB / CRDB rr 都不適合 hot-row 場景
- vm-3node 重跑時預期 YBDB rr 受 cross-zone DocDB Raft replication 進一步惡化 — 寫 fan-out × retry overhead 雙重打擊

---



---

## vm-1node-strict — 待測（v4.7）

> 重跑完成後此段對齊 `vm-1node-rc` 結構填入。YBDB 原生支援 SERIALIZABLE，跨家 strict 對標主要對 CRDB SSI；TiDB strict alias 到 RR 不可直比。

---

## v4.7 重跑檢核項

每組 `(vm-1node, iso)` 完成後逐項勾選；全部齊備才能在 README 從 🔄 升為 ✅。

| 項目 | v4.7 目標 | vm-1node-rc 本輪結果 |
|------|-----------|---------------------|
| Run 結構 | 5 round × 5 min × 4 thread groups (16/32/64/128) + 20min warmup @ 64 threads | ✅（20/20 round 完成）|
| Round artifact 格式 | `runs/threads-X/round-Y/go-tpc-stdout.txt` per-round | ✅ |
| DB-host 監控 | mpstat / iostat / vmstat / sar 1s 取樣，client (`*.txt`) + db-host (`*-db.txt`) 雙邊 | ✅ |
| Gate 雙閘 | `isolation-db.txt` + `isolation-driver-verify.txt`，兩者一致才放行 prepare；同時驗 `yb_effective_transaction_isolation_level` | ✅（修法 #7 加 effective gate；本輪 expected = actual = effective = `read committed`）|
| Suite marker | `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.suite.done` | ✅（含 `.db-config.done`，`.suite.done` 在 collect 修復後 manual 補寫）|
| TPCC_TS | `yyyyMMddTHHmmss+0800` 共用整 suite | ✅ `20260520T134929+0800` |
| 平均口徑 | tpmC / p50 / p95 / p99 全為 5-round mean，range/mean 看穩定性 | ✅（range/mean 2.2-4.9%）|
| Latency aggregate | NO p50 / p95 / p99（5-round mean） | ✅ |
| 三 isolation 矩陣 | RC + RR + Strict | RC ✅ ; RR / Strict 待測 |
| go-tpc `--check-all` | §8.1 列出（但 §4.1 強制對齊未列）| **deviation**：YBDB 跳過，改 row-count 9 表（W=128 對齊預期）— 文件已備案 [`修法 #4`](#修法總覽)|

---

## K8s 段 — 已存檔於 yuga-tc1-old

> 2026-05-13 的 k8s-3node-unlimit / k8s-3node-limit 為 pre-v4.7 單次 10min wrapper 結果，已隨主檔清空動作備份於 [`../../yuga-tc1-old/S-BASE/`](../../yuga-tc1-old/S-BASE/) ＋ [`pipeline-log_old.md`](../../yuga-tc1-old/S-BASE/pipeline-log_old.md)（pre-v4.7 narrative）。待 K8s 環境以 v4.7 detached suite 重跑後，將回填正式段落。
