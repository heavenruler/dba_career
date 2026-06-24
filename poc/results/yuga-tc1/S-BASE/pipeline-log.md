# YugabyteDB TPC-C Pipeline Log — yuga-tc1 / S-BASE

> 本檔為 PoC v4.7 框架下的 YugabyteDB baseline（v4.7 detached suite：5-round × 5 min × 4 thread groups + 20 min warmup × DB-host 雙邊監控）。pre-v4.7 single-run wrapper 資料（vm-1node 單次 10min、k8s-3node-{unlimit,limit} 單次、2.20 issue 紀錄、AlmaLinux 8.10 改造紀錄、原 pipeline-log.md / archive/pipeline-log_old.md）整套已備份至 [`../../yuga-tc1-old/archive/`](../../yuga-tc1-old/archive/)，本檔不再保留 pre-v4.7 段落。

---

## TL;DR — vm-1node 三 isolation 矩陣完成（2026-05-20/21）

**核心結論**：YugabyteDB 2025.2.2 LTS 在 4 vCPU + single XFS 硬體下，**rc ＞ rr ＞ strict** — 與 CockroachDB「strict ＞ rc ＞ rr」**完全相反**。原因：YugabyteDB rc 本身 CPU-bound（無 IO headroom 可榨），SSI 額外的 read-refresh / serializable detector 直接吃 CPU，反而拖慢；對比 CockroachDB rc IO-bound（fsync ceiling），SSI 改走 CPU 路徑剛好避開 IO 瓶頸。

### tpmC 排行（5 round mean）

> 三家 YBDB iso 都在 **t32** 達 peak（與 TiDB / CRDB 的 t128 peak 不同）；rr / strict 在 t128 已掉約 8.8%/0.1%，反映 CPU-bound + N−1 retry pattern。完整 4 thread sweep 數字見各 iso §「Execute 結果」與 §「Saturation」。

| 排名 | iso | tpmC | 併發 | DB-host 瓶頸 | err count / round | error rate | N |
|---|---|---:|:---:|---|---:|---:|:---:|
| 🥇 | **rc** | **11,436** | t32 | CPU-bound（%user 74% + %sys 18% ≈ 92%）| **0** | 0.0% | 1 |
| 🥈 | rr | 1,879 | t32 | retry-bound（SI 線性 N−1 衝突）| 31 | 0.149% | 1 |
| 🥉 | strict | 1,130 | t32 | retry-bound（SSI ≈N−1，比 rr 略少 ~5%）| 31 | 0.248% | 1 |

### 三大發現

1. **rc 是真 RC、零 error**：tserver gflag `yb_enable_read_committed_isolation=true` + session iso 雙閘 + `yb_effective_transaction_isolation_level` gate 三層驗證，20 round / 53,721 NEW_ORDER 全成功；對比 CockroachDB rr 412 errors / 20 round。**不啟用 gflag 會 silent fallback 到 SI → 跑出來的「RC」其實是 RR**（=本 rr 表）。
2. **rr / strict 都撞 hot row + 都接近 N−1 error pattern**：YugabyteDB rr (SI) 與 strict (SSI) 兩個 isolation 都因 TPC-C district / warehouse hot row 觸發衝突；rr 精確 N−1、strict 略少（SSI 偶有 early-abort 或 read-refresh 救回）。**兩者 throughput 都 flat-line ~1,100-1,800**，與 CockroachDB rr 同病；TiDB rr 採 pessimistic lock-wait 不 retry，是同硬體下唯一能維持 13,874 tpmC 的 RR 實作。
3. **strict ＜ rr 反 CockroachDB pattern 的機制歸納**：
   - CockroachDB rc 為 IO-wait bound（%iowait 18%、%idle 5%、%user 68%）→ strict 走 CPU-heavy read-refresh 路徑剛好避開 IO 瓶頸，**strict 10,830 ＞ rc 9,134**
   - YugabyteDB rc 為 CPU-bound（%user 74% + %sys 18% ≈ 92% 利用率、%idle 1.9%、%iowait 0.25%）→ strict 的 serializable detector + read-refresh 直接搶 CPU，**strict 1,130 ＜ rc 11,436**（砍 90%）
   - **規律**：「強 iso 反而快」只在 baseline IO-bound 時成立；YugabyteDB / TiDB 等 CPU-bound 系統下，強 iso 直接拖慢
4. **strict p99 t128 = 54 ms < rr 1020 ms < rc 1000 ms** — strict 因 throughput 砍 10x、worker queue 短 → latency 反而最低；但這是 **「吞吐被閘住、queue 沒累積」的副作用**，非 strict 真的快

### 業務啟示

- YugabyteDB **保留預設 RC 是正確選擇**：rr / strict 都拿不到任何性能 / 一致性收益（rc 已是 per-statement snapshot RC、提供合理一致性保證）
- 跨家 strict 三家對比：**CockroachDB strict 10,830 ＞ YugabyteDB strict 1,130**（CockroachDB SSI 10x YugabyteDB SSI）。CockroachDB SSI 透過 read-refresh + interactive 衝突偵測在 IO-bound baseline 上反而快；YugabyteDB SSI 在 CPU-bound baseline 上把所有 isolation 都拖到同一個 ~1,100 ceiling
- 跨家 RR 三胞胎：**TiDB rr 13,874（pessimistic lock-wait）＞ CockroachDB rr 3,788（preview SI）＞ YugabyteDB rr 1,879（SI）**。三家 RR 名同實異，TiDB 是唯一可承受 hot row 的 RR
- 同硬體 9 組對標（5-round mean）：TiDB rr 13,874 ＞ TiDB rc 13,064 ＞ YugabyteDB rc 11,436 ＞ CockroachDB strict 10,830 ＞ CockroachDB rc 9,134 ＞ CockroachDB rr 3,788 ＞ YugabyteDB rr 1,879 ＞ **YugabyteDB strict 1,130** ←本輪新增

### 完整資料目錄

| iso | TPCC_TS | 5-round mean peak | err / 5min (mean per round) | 詳細段落 |
|-----|---------|--------------------|----------------------------|----------|
| rc | 20260520T134929+0800 | **11,436 @ t32** | 0 | [§ vm-1node-rc](#vm-1node-rc--2026-05-20poc-v47-baseline含-db-host-os-監控) |
| rr | 20260520T215216+0800 | 1,879 @ t32 | t16=15 → t128=127（線性 N−1） | [§ vm-1node-rr](#vm-1node-rr--2026-05-21poc-v47-snapshot-isolation--retry-storm) |
| strict | 20260521T091048+0800 | **1,130 @ t32** | t16=14.6 → t128=121.8（≈N−1，比 rr 少 ~5%）| [§ vm-1node-strict](#vm-1node-strict--2026-05-21poc-v47-serializable-isolation--ssi) |

### Execute 結果總覽（vm-1node 三 isolation）

> 口徑對齊 vm-3node 總覽：代表點採各 isolation 的 peak / 主要觀察併發；完整 per-round thread sweep 見各 iso 的 `Execute 結果` 表。p99 為 NEW_ORDER 5-round latency mean；err 為 all transaction error rate。

| iso | TPCC_TS | 代表併發 | tpmC mean | range/mean | NO p99 mean (ms) | err | N | 判讀 |
|---|---|---:|---:|---:|---:|---:|---:|---|
| [`rc`](#vm-1node-rc--2026-05-20poc-v47-baseline含-db-host-os-監控) | [`20260520T134929`](./vm-1node-rc/ybdb-vm-1node-rc-20260520T134929+0800/) | 32 | 11,436 | 4.2% | 216 | 0.000% | 1 | CPU-bound；零 error |
| [`rr`](#vm-1node-rr--2026-05-21poc-v47-snapshot-isolation--retry-storm) | [`20260520T215216`](./vm-1node-rr/ybdb-vm-1node-rr-20260520T215216+0800/) | 32 | 1,879 | 5.6% | 174 | 0.149% | 1 | SI hot row retry-bound |
| [`strict`](#vm-1node-strict--2026-05-21poc-v47-serializable-isolation--ssi) | [`20260521T091048`](./vm-1node-strict/ybdb-vm-1node-strict-20260521T091048+0800/) | 32 | 1,130 | 6.3% | 58 | 0.248% | 1 | SSI retry-bound；吞吐最低 |

vm-3node 5-cell（1s1r / 1s3r / 3s1r / 3s3r / haproxy-3s3r × RC）已於 2026-05-24 ~ 2026-05-25 完成（5-round mean、N=1；含 `d654824` / `68189bc` / `29b5fc5` 三筆 YugabyteDB vm3 ansible 修補與 RF-aware cluster gate）；詳見下方 `vm-3node 系列` + [4 cells 跨 cell 分析](../../dispatch-records/2026-05-25-vm-3node-ybdb-all4-rc-analysis.md) + [HAProxy vs direct 分析](../../dispatch-records/2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md)。

下一步：三家 `haproxy-3s3r` 補 N=3 → 升級為對外可引用 baseline；K8s 對照組待重跑；跨區規劃見 [`1_MeetingMinutes/0602.md §10`](../../../1_MeetingMinutes/0602.md)。

---

## 取數來源（Data trace）

所有 tpmC / latency / error rate / DB-host 飽和指標皆可從 artifact 目錄逐步重現，避免「pipeline-log 數字 vs 實際 stdout」漂移。

| 數據類型 | 來源檔案 | 取數工具 / 計算口徑 |
|---------|----------|---------------------|
| `tpmC mean` / `NO p50/p95/p99 mean` / `tpmTotal mean` / `efficiency mean` | `runs/threads-<N>/round-<R>/go-tpc-stdout.txt`（5 round per thread group）| [`tests/common/summary-from-stdout.py`](../../../tests/common/summary-from-stdout.py) 解析 `[Summary] NEW_ORDER` 與 `tpmC: ...` 行，輸出 `summary.json`；本檔取 `thread_results.<N>.{tpmC_mean, NEW_ORDER.p50_mean_ms, ...}` 為 5-round mean |
| `range/mean` 穩定度 | 同上 | `(max(tpmC_per_round) - min(tpmC_per_round)) / tpmC_mean × 100%` |
| `error rate (all_txn)` | 同上 `[Summary] *_ERR` 行（5 transaction types） | `Σ *_ERR count / Σ (* + *_ERR) count × 100%`（per F-001 audit 口徑）；落地至 `summary.json.thread_results.<N>.all_txn.error_rate_pct` |
| `NEW_ORDER_ERR / round` 統計 | 同上 | `summary.json.thread_results.<N>.NEW_ORDER.error_count / 5 round` |
| DB-host 飽和指標（%user / %sys / %iowait / %idle / disk %util）| `runs/threads-<N>/round-<R>/{mpstat-db.txt, iostat-1s-db.txt}` | round-3 mid-run 1s 取樣，跨 round 計算 `mean(line[%idle], %iowait)`；指令範例：`awk '$2=="all" {usr+=$3; ...} END{...}'` |
| isolation gate 雙閘證據 | `gate/isolation-db.txt` + `gate/isolation-driver-verify.txt` + `.gate-isolation.done`（JSON marker）| `psql -c "SHOW transaction_isolation" -c "SHOW yb_effective_transaction_isolation_level"` 各 dump 一行 |
| tserver gflag dump | `db-config/cluster-settings.txt` + `db-config/effective-config.txt` | collect 階段 `db-config-dump.sh` 從 `:9000/varz` 抓 |
| Round 結構完整性驗證 | `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.db-config.done` / `.suite.done` | 7 個 marker 全在 = phase chain 完整 |

重新計算 vm-1node-rc t32 5-round mean 範例：

```bash
jq '.thread_results."32".tpmC_mean,
    .thread_results."32".NEW_ORDER.p99_mean_ms,
    .thread_results."32".all_txn.error_rate_pct' \
  results/yuga-tc1/S-BASE/vm-1node-rc/ybdb-vm-1node-rc-20260520T134929+0800/summary.json
```

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

第一次 `make vm1-ybdb-rc` 啟動到 suite 完成共撞 8 個 YugabyteDB-specific 問題（tidb/crdb 路徑都不會觸發），全數修進 `poc/ansible/playbooks/yugabyte-vm1.yml`、`poc/tests/common/prepare.sh`、`poc/tests/common/gate-isolation.sh`、`poc/tests/common/db-config-dump.sh`、`poc/tests/common/collect.sh`。本段把 root cause / 修法 / commit SHA 留檔，避免下次 rr / strict / vm-3node 重跑時又踩同樣坑。

### 修法總覽

| # | 階段 | 錯誤訊息 | Root cause | 修法 | Commit |
|---|------|----------|-----------|------|--------|
| 1 | ansible deploy | `Could not import the dnf python module using /usr/bin/python3.12` | inventory 用 python3.12，但 AlmaLinux 8.10 的 dnf python bindings 只在 `/usr/libexec/platform-python` (3.6)；`ansible.builtin.dnf` 模組需要這個 binding | 兩段 `ansible.builtin.dnf` 改為 `ansible.builtin.shell` + `rpm -q` idempotent install（與 tidb-vm1.yml 同 pattern）| [`c88f7d4`](#) |
| 2 | ansible deploy | `Wait for YSQL port` timeout 240s | fresh VM 上 `yugabyted status` 即使「is not running」也回 **rc=0**，所以 `when: yb_status.rc != 0` 條件被 skip → `Start YugabyteDB RF=1` 永遠不會跑 | 條件改為 `'is not running' in (yb_status.stdout \| default(''))` ，rc!=0 作 backstop | [`e5ccc11`](#) |
| 3 | prepare DROP/CREATE | `ERROR: DROP DATABASE cannot run inside a transaction block` | `psql -c "DROP; CREATE"` 兩 stmt 在同一 implicit txn；YSQL/PG 禁 DROP DATABASE 在 txn 內 | 拆兩個 `-c` flag，各自獨立 txn | [`904c80c`](#) |
| 4 | go-tpc prepare | suite 卡在 `begin to check warehouse 1 at condition 3.3.2.x` 1h+ 不結束 | go-tpc 預設 prepare 完跑 inline consistency check；3.3.2.x 系列為跨表 aggregate，YB 2025.2 上會卡 30+ min | YugabyteDB 加 `--no-check`；後續 `check-all` 步驟 YugabyteDB 也跳過，改用 row-count 驗整性 | [`99cb5a3`](#) |
| 5 | prepare DROP DATABASE | `ERROR: database "tpcc" is being accessed by other users` | 前次 suite kill 後 go-tpc 連線在 YB 仍 lingering（YSQL session state 由 tserver 保留至 TCP 驅逐或顯式 terminate）| DROP 前 `pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='<db>' AND pid<>pg_backend_pid()`，多 `-c` 不在同 txn | [`fc76fe4`](#) |
| 6 | prepare schema+EXPLAIN dump | `ERROR: column c.relhasoids does not exist` ＋ psql rc=1 → `set -euo pipefail` 殺 suite | AlmaLinux 8.10 內建 psql（postgresql 套件，PG ≤11）的 `\d+` 查 `pg_class.relhasoids`，PG 12+ 已移除此 column，YB 2025.2 catalog 沒這欄 | YugabyteDB schema/EXPLAIN dump 改用 yugabyte 隨附的 `ysqlsh`（catalog 同步）；其它 plain-SQL（DROP/CREATE/ANALYZE/row-count）保留 psql | [`8069ada`](#) |
| 7 | gate-isolation | （preemptive；本輪 playbook 已設 gflag，gate 未踩；保留為 future-proof）原 `SHOW transaction_isolation` 通過不代表 effective 真為 RC | YB 雙閘要求：session 層 `transaction_isolation` ＋ tserver gflag `yb_enable_read_committed_isolation`；缺 gflag 時前者顯示 `read committed`，但 `yb_effective_transaction_isolation_level` 退回 `repeatable read`，跑出來的 RC 結果其實是 SI | YugabyteDB DB-gate ＋ driver-gate 兩段都加 `SHOW yb_effective_transaction_isolation_level`；effective 必須等於 expected 否則 die，hint 指向 tserver gflag；JSON marker 多帶 `yb_effective_db` / `yb_effective_driver` | [`b9b3b43`](#) |
| 8 | collect (`db-config-dump.sh` + collect.sh env / log tail) | suite rc=1 在 `[4/4] collect` 1 秒內爆 | `db-config-dump.sh` 用 `curl -s /varz \| head -200` — head close pipe 後 curl 收 SIGPIPE 退 **rc=23 (Write error)**，`set -o pipefail` 抓出來、`set -e` 殺 script；之後 collect.sh 的 env snapshot / DB log tail ssh 失敗也是 fatal | (a) db-config-dump.sh 拆 tmpfile two-step 避 SIGPIPE，加 `--max-time 30`、`ysql_default_transaction_isolation` / `yb_effective_transaction_isolation_level`；(b) collect.sh env snapshot + DB log tail 加 `\|\| warn`，optional metadata 不殺 suite | [`279697b`](#) |

### 為什麼 tidb / crdb 沒踩這些坑

| 修法 | tidb | crdb |
|------|------|------|
| #1 `ansible.builtin.dnf` | tidb-vm1.yml / cockroach-vm1.yml 早已用 `shell` + `rpm -q` pattern（先前 cockroach deploy bug 修過）| 同 tidb |
| #2 status gate | TiDB 用 `tiup cluster display` 判斷集群狀態（有明確 exit code 語意）；CockroachDB 用 `start-single-node` 本身 idempotent | 同 tidb |
| #3 DROP/CREATE in txn | MySQL 與 CockroachDB SQL 都允許 DDL 在 implicit txn；`mysql -e "DROP;CREATE"` 與 `cockroach sql -e "DROP;CREATE"` 正常 | 同 tidb |
| #4 slow consistency check | TiDB / CockroachDB check-all 都在合理時間內（TiDB 52min prepare 內含、CockroachDB 43min 內含），可直接用 go-tpc 原生 check | 同 tidb |
| #5 lingering session | TiDB / CockroachDB 的 `DROP DATABASE` 不被現存連線 pin（TiDB 自動失效、CockroachDB 預設允許 force drop）| 同 tidb |
| #6 psql `\d+` 與 PG catalog | TiDB 不用 psql；CockroachDB 接 PG protocol 但 schema dump 用 `cockroach sql -e "SHOW CREATE TABLE"`，不走 psql meta-command | 同 tidb |
| #7 雙閘 iso 驗證 | TiDB 用 `SHOW VARIABLES` + active txn 即可（沒有 effective vs session 落差）；CockroachDB 也只有 `SHOW transaction_isolation` 一層 | 同 tidb |
| #8 curl `\|head` SIGPIPE | TiDB 用 `mysql -e` + remote `tiup cluster show-config` 不 pipe curl；CockroachDB 用 `cockroach sql -e "SHOW ALL CLUSTER SETTINGS"` 直接 redirect | 同 tidb |

### YugabyteDB-specific 影響項

- **整性驗證口徑**：YugabyteDB 路徑改用 row-count 取代 go-tpc check-all；資料完整性 vs TiDB / CockroachDB 的 14-condition 嚴格度有差，但對 tpmC / latency 結果不影響（檢核僅在 prepare 結尾、run 前；run 用相同 go-tpc workload）
- **預期 row counts (W=128)**：warehouse 128 / district 1,280 / customer 3,840,000 / history 3,840,000 / item 100,000 / stock 12,800,000 / new_order 1,152,000 / orders 3,840,000 / order_line ~38.4M (5-15 lines per order, randomised) — 本輪實測 order_line = 38,410,536 ✓ 對齊
- **Gate WARN（本輪不致命）**：
  - `DB-host THP != never` / `vm.swappiness > 5` / `ulimit -n < 65536` — yugabyte-vm1.yml 尚未含 OS tuning task（tidb-vm1.yml 有「OS tuning」段）；本輪先不卡 gate，下一輪 rr / strict 前要補
  - `client (.31) artifacts FS available 14GB < 30GB` — 累積跨家 artifacts；rr / strict 前要清

---

## vm-1node-rc — 2026-05-20（PoC v4.7 baseline，含 DB-host OS 監控）

> **本段目的**：PoC v4.7 框架下的 YugabyteDB vm-1node RC 正式 baseline，配套：detached suite wrapper、多輪平均、isolation 雙閘（session + effective）、**client + DB-host 雙邊 OS 監控**。取代 yuga-tc1-old 內 2026-05-14 單次 10 min 結果，作為後續 rr/strict 與其他 DB 對標的可重現基線。

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

### Execute 結果（5 round mean；NEW_ORDER latency）

> tpmC / latency / error rate 皆取自 [`summary.json`](./vm-1node-rc/ybdb-vm-1node-rc-20260520T134929+0800/summary.json)；p50 / p95 / tpmTotal / efficiency 補充見 `summary.json`。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 10,610 | 10,567 | 10,587 | 10,635 | 10,864 | 10,653 | 2.8% | 104 | 0.0% |
| 32 | 11,643 | 11,451 | 11,468 | 11,457 | 11,163 | **11,436** | 4.2% | 216 | 0.0% |
| 64 | 11,283 | 11,373 | 11,289 | 11,123 | 11,133 | 11,240 | 2.2% | 440 | 0.0% |
| 128 | 11,224 | 10,786 | 10,869 | 10,694 | 10,851 | 10,885 | 4.9% | 1,000 | 0.0% |

> **零 error 全程**：20 round 內 `NEW_ORDER_ERR = 0`、`execute run failed = 0`、`Restart read required = 0`。RC + 雙閘 + tserver gflag 共同確保。

- **range/mean 2.2-4.9%**：比 TiDB rc（5.0-8.3%）、CockroachDB rc（4.7-9.1%）都更穩定；YugabyteDB 對 round 邊界 housekeeping 不敏感。
- r1 並未明顯偏離（t16 r1 10610 vs r5 10864、t128 r1 11224 vs r5 10851）；warmup 20min @ 64t 已把 DocDB tablet cache、PG plan cache、connection pool 全暖完。

### DB-host (.32) 飽和分析 ★

> **核心發現**：YugabyteDB vm-1node 在 4 vCPU 下是 **CPU-bound（%idle 接近 0）**，但 CPU 路徑與 TiDB / CockroachDB 不同 — **%sys 異常高（18-19%）**，磁碟 / IO 全程有大量餘裕。

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
| %sys 比例異常高 | ✓ | 18-19% 全 thread group；對比 TiDB 9-11%、CockroachDB 5-6%；推測 YSQL postgres → DocDB tserver 跨進程通訊 + DocDB 內部 RPC 多耗 syscall 與 context switch |
| IO 非瓶頸 | ✓ | %iowait t32+ < 2%、sda %util 全程 ≤ 50%；DocDB 的 RocksDB WAL 寫入批量化比 CockroachDB Raft+Pebble fsync 更積極 |
| t64+ 無收益 | ✓ tpmC + CPU 雙證 | tpmC 32→64 -1.7%、64→128 -3.2%；%idle 從 t32 3.29% 降到 t128 1.89%（CPU 一直滿）但 throughput 沒上升 |

### vs 同硬體對比 ★

#### vs TiDB rc / CockroachDB rc（5-round mean 同口徑）

| threads | TiDB rc | CockroachDB rc | YugabyteDB rc | YugabyteDB vs TiDB | YugabyteDB vs CockroachDB |
|---------|---------|---------|---------|--------------|--------------|
| 16  | 10,074 | 9,034 | **10,653** | +5.7% | +17.9% |
| 32  | 11,728 | 9,020 | **11,436** | -2.5% | +26.8% |
| 64  | 12,744 | 9,134 | 11,240 | -11.8% | +23.0% |
| 128 | **13,064** | 8,813 | 10,885 | -16.7% | +23.5% |

| threads | TiDB p99 (ms) | CockroachDB p99 (ms) | YugabyteDB p99 (ms) | YugabyteDB vs TiDB | YugabyteDB vs CockroachDB |
|---------|---------------|---------------|---------------|--------------|--------------|
| 16  | 94  | 113 | 104  | +11% | -8% |
| 32  | 163 | 223 | 216  | +33% | -3% |
| 64  | 305 | 440 | 440  | +44% | 0% |
| 128 | 597 | 926 | 1000 | +68% | +8% |

| DB-host | TiDB %idle | CockroachDB %idle | YugabyteDB %idle | TiDB %iowait | CockroachDB %iowait | YugabyteDB %iowait | TiDB %sys | CockroachDB %sys | YugabyteDB %sys |
|---------|-----------|-----------|-----------|--------------|--------------|--------------|-----------|-----------|-----------|
| t16  | 9.45% | 5.77% | 6.99% | 4.6% | 18.5% | 5.5%  | 11.0% | 5.6% | **19.1%** |
| t128 | 4.52% | 4.99% | **1.89%** | 3.1% | 18.8% | 0.25% | 9.0%  | 5.5% | **18.5%** |

**三家飽和成因不同**：
- **TiDB**：CPU-bound、%user dominant（80%）、%sys 中位（9%）、%iowait 低（3%）→ 加 thread 把 CPU 擠到 95%+ 就到天花板
- **CockroachDB**：IO-wait bound、%iowait 18-19% 立即觸頂、%idle 5% 全程 → 加 thread 只是 queue 長
- **YugabyteDB**：CPU-bound 但異常高 %sys 19%、%iowait 低（< 5%）、%idle 接近 0 → CPU 路徑被 syscall / IPC / DocDB internal RPC 拉走 1/5；DocDB WAL fsync 批量化比 CockroachDB 積極（YB 用 RocksDB block-based + DocDB row-cache，CockroachDB 用 Pebble + Raft log per-commit fsync）

#### vs pre-v4.7 single-run（yuga-tc1-old 內，2026-05-14, single 10min）

| threads | pre-v4.7 single-run | v4.7 5-round mean | Δ | 解讀 |
|---------|--------------------|--------------------|----|------|
| 16  | 10,844 | 10,653 | -1.8% | 5-round mean 略低，含 round-to-round variance |
| 32  | 10,341 | **11,436** | **+10.6%** | warmup 20min vs 5min 預熱差異；plan cache 完全暖 |
| 64  | 9,982  | 11,240 | +12.6% | 同上 |
| 128 | 8,906  | 10,885 | +22.2% | 高併發更受益於完整 warmup |

→ v4.7 把高併發水位的數字從 8,906 拉到 10,885（+22%），驗證 **warmup 從 5min 延長到 20min、warmup_threads=64** 確實對 YugabyteDB 像對 TiDB 一樣有效（PoC-DESIGN §8.2）。

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

**結論**：YugabyteDB vm-1node RC 的甜點在 **t32（11,436 tpmC、p99 216ms）**。t64 換 2x latency 只少 1.7% tpmC、t128 換 4.6x latency 還倒退 4.8%；**真正天花板是 4 vCPU 在 YSQL+DocDB 雙進程架構下的 CPU 預算**（19% 給 %sys，剩 75% 給 %user），磁碟有大量餘裕（%util ≤ 50%）。

### 觀察

- **t32 是甜點**：5 round mean 11,436 tpmC、p99 216ms，DB %idle 3.29% — 剛好榨出 CPU 又沒撞牆。
- **t128 已過飽和**：p99 突破 1s、tpmC 邊際 -4.8%；高併發放大連線管理 overhead。
- **零 error**：v4.7 雙閘 (`yb_effective_transaction_isolation_level = read committed`) 確保 RC 真生效，沒有 silent fallback 到 SI 造成 retry storm（對比 CockroachDB rr 412 errors / 20 round）。
- **%sys 19% 異常**：架構特異 — YSQL postgres 與 DocDB tserver 是**兩個獨立 process**（YSQL 把 SQL 解析 / plan 後透過 RPC 送給 DocDB tserver 執行），跨進程 RPC + 序列化 / 反序列化吃掉 1/5 CPU。TiDB（SQL 層 + storage TiKV 也是兩 process 但 SQL 是 TCP grpc 不是 syscall-heavy IPC）相對 9-11%、CockroachDB（SQL + storage 同 process）只 5-6%。
- **DocDB WAL 寫入比 CockroachDB 積極**：%iowait < 5% vs CockroachDB 17-19%；YB 預設 `durable_wal_write=true` + `interval_durable_wal_write_ms=1000` 把 fsync 批量化到 1s 區間，CockroachDB 預設 per-commit fsync。
- **`efficiency > 100%` 屬正常**：go-tpc 不打 keying/think time，是本 PoC 內部對標的相對指標，**不可與 TPC-C 官網數字直接比**。

### 結論

YugabyteDB v2025.2.2.2 vm-1node RC 在 PoC v4.7 框架下穩定可重現，**t32 為甜點（11,436 tpmC、p99 216ms），t128 已過飽和（-4.8% / 1s p99），硬天花板是 .32 的 4 vCPU 預算被 %sys (19%) 吃掉 1/5**。DB-host 端 OS 監控正式生效，雙閘 iso 確保 RC 真生效不會 silent fallback 到 SI。

本輪資料作為後續 `vm-1node-rr`、`vm-1node-strict`、以及 vm-3node 對標的 baseline。預期 vm-3node 將 DocDB tablet 分散到 3 台後可提升 tpmC，但 RF=3 引入 cross-zone Raft replication 應增加 latency；scale-out ratio 不應預設為線性。

---

## vm-1node-rr — 2026-05-21（PoC v4.7，snapshot isolation + retry storm）

> **本段目的**：在同硬體 / 同流程下取得 YugabyteDB vm-1node RR baseline（YB rr = snapshot isolation，**非** PG 標準 RR 語意），對照 rc 與 CockroachDB rr / TiDB rr 觀察 write conflict 處理差異。

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

→ session 與 effective 都對齊 `repeatable read`；YugabyteDB 的 rr 在底層 = snapshot isolation（per official [YugabyteDB Isolation Levels doc](https://docs.yugabyte.com/stable/architecture/transactions/isolation-levels/) 「YugabyteDB's REPEATABLE READ isolation level corresponds to PostgreSQL's REPEATABLE READ, and is implemented using Snapshot Isolation」）。

### Prepare
- 時間：47 min（DROP/CREATE + load + row-count + quiesce + ANALYZE，與 rc 一致）
- Load：`go-tpc tpcc prepare --no-check W=128`
- Row-count：9 表全對齊 W=128 預期（warehouse 128 / district 1280 / customer 3,840,000 / history 3,840,000 / item 100,000 / stock 12,800,000 / new_order 1,152,000 / orders 3,840,000 / order_line ~38.4M）

### Execute 結果（5 round mean；NEW_ORDER latency）

> tpmC / latency / error rate 皆取自 [`summary.json`](./vm-1node-rr/ybdb-vm-1node-rr-20260520T215216+0800/summary.json)；p50 / p95 / tpmTotal / efficiency 補充見 `summary.json`。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 1,874 | 1,692 | 1,909 | 1,830 | 1,926 | 1,846 | 12.7% | 61 | 0.046% |
| 32 | 1,848 | 1,870 | 1,952 | 1,854 | 1,872 | **1,879** | 5.6% | 174 | 0.139% |
| 64 | 1,837 | 1,933 | 1,860 | 1,804 | 1,802 | 1,847 | 7.1% | 240 | 0.244% |
| 128 | 2,014 | 1,812 | 1,774 | 1,797 | **1,173** | 1,714 | 49.1% ⚠️ | 1,020 | 0.513% ⚠️ |

> **t128 range/mean 49.1%**：r5 collapse 至 1173（r1-r4 為 2014/1812/1774/1797，r5 異常低）— SI hot row 衝突放大 round 邊界 housekeeping 影響。

### Error 分析 — **N-1 pattern** 與 CockroachDB rr 完全相同

| iso | thread | err / round | err 結構 |
|-----|--------|-------------|----------|
| YugabyteDB rr t16  | 15 | NEW_ORDER ~5 + PAYMENT ~10 + 偶爾 STOCK_LEVEL |
| YugabyteDB rr t32  | 31 | 多 PAYMENT (~17) + NEW_ORDER (~13) |
| YugabyteDB rr t64  | 63 | PAYMENT (~40) + NEW_ORDER (~23) |
| YugabyteDB rr t128 | 127 | PAYMENT (~83) + NEW_ORDER (~43) |
| **CockroachDB rr 對照** | 同 thread | 15/31/63/127（完全相同 N-1） | NEW_ORDER 為主 + 偶爾 PAYMENT |

**N-1 機制**（兩家共有 SI hot row）：
1. round 起始 N 個 worker 同時 BEGIN，每個取 snapshot ts 落在毫秒級窗口
2. 跑 NEW_ORDER → `UPDATE district SET d_next_o_id = ...`（hot row，district PK 空間僅 128W × 10D = 1280 row）
3. **first committer wins**：第一個 worker commit 成功，剩 N-1 個拿 `SerializationFailure` / `WriteTooOldError` abort
4. client retry 後再次撞，5min round 內 retry 次數累積 → 但 go-tpc 的 `[Summary] NEW_ORDER_ERR` 只算到 unique abort，故 = N-1

**差別**：YugabyteDB rr `[Summary] PAYMENT_ERR` 出現率高於 NEW_ORDER_ERR（t128 r5: PAYMENT 77 vs NEW_ORDER 49），CockroachDB rr 則 NEW_ORDER 為主。推測為兩家對 PAYMENT 的 `UPDATE warehouse SET w_ytd = ... WHERE w_id = ...` 衝突偵測時機不同。

### DB-host (.32) 飽和分析 ★（與 rc / 與 TiDB rr 完全不同）

| threads | %usr mean | %sys mean | %iowait mean | %idle mean | %idle min | sda %util |
|---------|-----------|-----------|--------------|------------|-----------|-----------|
| 16  | 12.6% | 5.2% | 13.17% | **67.51%** | 6.11% | 63.8% |
| 32  | 12.9% | 5.3% | 12.72% | **67.54%** | 2.25% | 63.6% |
| 64  | 13.1% | 5.3% | 12.06% | **67.87%** | 1.50% | 63.5% |
| 128 | 14.1% | 5.8% | 11.77% | **66.57%** | **0.50%** | 62.3% |

> **核心發現**：YugabyteDB rr 與 rc / TiDB rr 截然不同 — **DB 機器同時 idle 大量 CPU (66-67%) + 11-13% iowait + disk %util 62-64%**。瓶頸不在 DB host 資源層，而在 **transaction coordination layer（retry storm + abort 後 client 等待）**。

| 假設 | 驗證 | 證據 |
|------|------|------|
| 飽和是 CPU | ❌ | %user 12-14%、%idle mean **66-67%** |
| 飽和是 IO | ❌ | %iowait 11-13%、sda %util 62-64% 雖然比 rc 高，但 throughput 1/6 → 單位工作的 IO 開銷高，總 IO ceiling 仍未達 |
| 飽和是 **retry storm**（SI hot row + client retry loop） | ✓ | err TPM 線性 = thread−1；DB %idle 66-67% 表示 worker 大部分時間在等 retry 或 conflict abort 回 client |
| **rc 與 rr 飽和成因 mirror** | ✓ | rc CPU-bound + 高 %sys（IPC overhead）／ rr DB-idle + transaction-bound（retry overhead）— rr 把 rc 的「實際工作」換成「失敗 + retry」 |

### vs YugabyteDB rc 對比

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

→ **YugabyteDB 切 rc → rr 在本 workload 上沒有任何性能 / 一致性收益**，純損失 6x throughput；rr 真正用途為「需要 per-txn snapshot 但能接受 retry 成本」的查詢-重 OLTP 系統。

### vs CockroachDB rr / TiDB rr 對比（三家 RR 機制）

| threads | YugabyteDB rr | CockroachDB rr | TiDB rr (pessimistic) | YugabyteDB:CockroachDB | TiDB:YugabyteDB |
|---------|---------|---------|-----------------------|-----------|-----------|
| 16  | 1,846 | 3,229 | 11,196 | 0.57x | 6.1x |
| 32  | 1,879 | 3,577 | 12,831 | 0.53x | 6.8x |
| 64  | 1,847 | 3,594 | 13,743 | 0.51x | 7.4x |
| 128 | 1,714 | 3,788 | **13,874** | 0.45x | 8.1x |

| 機制 | YugabyteDB rr | CockroachDB rr (preview) | TiDB rr (pessimistic) |
|------|---------|------|-------|
| 預設 RR 實作 | snapshot isolation per official docs | snapshot isolation (preview feature; iso=Snapshot 在 artifact log) | snapshot isolation per official docs |
| Hot row write 衝突處理 | first committer wins → `SerializationFailure` → client retry | first committer wins → `WriteTooOldError` → client retry | **row lock 排隊**（後者 wait） |
| `SELECT FOR UPDATE` | 取 unreplicated lock，**不 advance read ts** | 取 unreplicated lock，**不 advance read ts** | 取 pessimistic lock，**advance for-update-ts** |
| Error pattern | 線性 N-1 / round | 線性 N-1 / round | 0 errors |
| 全域 pessimistic toggle | ❌ | ❌ | ✓ `tidb_txn_mode=pessimistic` |

**結論**：YugabyteDB 與 CockroachDB 兩家 RR 都是 optimistic SI，撞 hot row 表現相似（YugabyteDB 比 CockroachDB 更慢 -45-50% 推測為 DocDB / YSQL 雙進程的 IPC retry cost 高於 CockroachDB 單進程）；TiDB 是 7-8 倍 throughput 唯一可承受 hot-row contention 的 RR 實作。

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

**結論**：YugabyteDB rr 的 tpmC 天花板 ~1,850（4 vCPU 硬體下，所有 thread group 完全 flat），latency 在 t128 因 hot-row queue 累積爆炸到 1s。**真正瓶頸不在硬體，在 SI 寫衝突 + retry storm**。

### 觀察

- **rr ≠ RC「升級版」**：本次數據反證「越強 isolation 越慢」直覺中**rc → rr 砍 6x throughput 的代價**，因 YugabyteDB / CockroachDB rr 都用 optimistic SI（snapshot ts + first-committer-wins），與 PG 標準 RR（serial txn ordering via SS2PL）行為完全不同
- **N-1 error pattern 為 SI hot row 共通病**：本輪首次同時驗證 YugabyteDB rr 與 CockroachDB rr 都精確產生 N-1 errors/round，**確認 SI + TPC-C district hot row 是 deterministic 衝突源**
- **零 SerializationFailure 在 rc / N-1 SerializationFailure 在 rr**：本檔 [`修法 #7`](#修法總覽) 的 dual-gate 確保 rc 與 rr 各跑各的 iso，沒有 silent fallback；run-phase artifact 內 `[Summary] *_ERR` 反映實際 abort 數
- **PAYMENT_ERR 比 NEW_ORDER_ERR 多**：YugabyteDB rr 特有現象（CockroachDB rr NEW_ORDER 為主），推測 PAYMENT 的 `UPDATE warehouse SET w_ytd = ...` 在 DocDB SI 下衝突偵測較早 trigger（每 warehouse PK 才 128 行，比 district 1280 更熱）；需 trace 進一步佐證
- **DB-host disk %util 63% > rc 42%**：rr 雖 throughput 砍 6x，但 disk 反而比 rc 更忙 — 推測 SI version metadata 寫入 + retry 重讀放大 IO overhead

### 結論

YugabyteDB v2025.2.2.2 vm-1node RR 在 4 vCPU + single disk 硬體下：
- **吞吐天花板 ~1,850 tpmC**（比 rc 11,436 砍 84%、比 TiDB rr 13,874 少 87%）
- **err 線性 = thread − 1**（t16=15、t32=31、t64=63、t128=127）— 與 CockroachDB rr **完全相同** N-1 pattern，是 SI hot row 共通病
- **DB-host 大量 idle**（%idle 66-67%）+ **不飽和的 IO**（%iowait ~12%、disk %util 63%）— 瓶頸 = **transaction coordination layer (retry storm)**

**業務啟示**：
- YugabyteDB 預設 RC 是正確選擇；本 workload 切 rr 純損失 throughput 不換來任何收益
- 若 app 必須 per-txn snapshot 一致性語意，**首選 TiDB pessimistic rr**（同硬體 7-8x throughput）；YugabyteDB / CockroachDB rr 都不適合 hot-row 場景
- vm-3node 重跑時預期 YugabyteDB rr 受 cross-zone DocDB Raft replication 進一步惡化 — 寫 fan-out × retry overhead 雙重打擊

---

## vm-1node-strict — 2026-05-21（PoC v4.7，serializable isolation = SSI）

> **本段目的**：在同硬體 / 同流程下完成 YugabyteDB vm-1node 三 isolation 矩陣的最後一塊：原生 SERIALIZABLE（SSI）。對標 CockroachDB SSI 觀察「強 iso 反而快」是否在 YugabyteDB 成立。

### 環境
- 與 `vm-1node-rc` / `vm-1node-rr` 相同硬體 / YB v2025.2.2.2 build 11 / 同 ansible playbook / 同 tserver gflag，唯一差異：**iso=strict（serializable）**
- go-tpc conn-params：`sslmode=disable&options=-c default_transaction_isolation=serializable`
- TPCC_TS：`20260521T091048+0800`
- 結果目錄：`vm-1node-strict/ybdb-vm-1node-strict-20260521T091048+0800/`

### Suite 階段時序

| Phase | 起 | 訖 | 耗時 |
|-------|-----|------|------|
| gate | 09:14:53 | 09:14:54 | <1 min |
| prepare（DROP/CREATE + load 128W + row-count + quiesce 5m + ANALYZE + EXPLAIN dump via ysqlsh）| 09:14:54 | 10:06:55 | 52 min |
| gate-isolation（dual gate: session + effective）| 10:06:55 | 10:08:08 | 1 min |
| cold-reset | 10:06:55 | 10:08:08 | 1 min |
| warmup (20 min @ 64 threads) | 10:08:08 | 10:28:08 | 20 min |
| run (4 thread × 5 round × 5 min + 60s sleep) | 10:28:08 | 12:48:29 | 2h20 min |
| collect | 12:48:29 | 12:48:29 | <1 min |
| **total (suite)** | **09:14:53** | **12:48:29** | **3h33 min** |

### Gate 結果（active isolation dual-gate）

| 維度 | expected | DB-side actual | driver-side actual |
|------|----------|----------------|--------------------|
| `SHOW transaction_isolation` | `serializable` | `serializable` ✓ | `serializable` ✓ |
| `SHOW yb_effective_transaction_isolation_level` | `serializable` | `serializable` ✓ | `serializable` ✓ |

→ session 與 effective 都對齊 `serializable`，conn-params `default_transaction_isolation=serializable` URL-decode 正確 → tserver 與 YSQL 都認得。YugabyteDB SSI 全程啟用，無 silent fallback（不像 rc 需 tserver gflag `yb_enable_read_committed_isolation`）。

### Prepare
- 時間：52 min（DROP/CREATE + load 38 min + row-count + quiesce + ANALYZE，比 rc/rr 略長 ~5 min）
- Row-count：9 表全對齊 W=128 預期（warehouse 128 / district 1280 / customer 3,840,000 / history 3,840,000 / item 100,000 / stock 12,800,000 / new_order 1,152,000 / orders 3,840,000 / order_line ~38.4M）

### Execute 結果（5 round mean；NEW_ORDER latency）

> tpmC / latency / error rate 皆取自 [`summary.json`](./vm-1node-strict/ybdb-vm-1node-strict-20260521T091048+0800/summary.json)；p50 / p95 / tpmTotal / efficiency 補充見 `summary.json`。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 1,008 | 1,097 | 1,115 | 1,140 | 1,120 | 1,096 | 12.1% | 61 | 0.131% |
| 32 | 1,126 | 1,180 | 1,111 | 1,123 | 1,110 | **1,130** | 6.3% | 58 | 0.276% |
| 64 | 1,105 | 1,114 | 1,108 | 1,024 | 1,107 | 1,092 | 8.3% | 62 | 0.655% ⚠️ |
| 128 | 1,119 | 1,140 | 1,140 | 1,128 | 1,120 | 1,129 | **1.8%** | **54** | 1.204% ⚠️ |

> **t128 range/mean 1.8%**：strict 在 t128 高併發下反而最穩定（與 rr t128 的 49.1% 雷亂相反）— SSI flat-line throughput 隨機性低。

### Error 分析 — 接近 N-1 但比 rr 少 ~5%

| iso | t16 | t32 | t64 | t128 |
|-----|-----|-----|-----|------|
| rc | 0 | 0 | 0 | 0 |
| rr | 15 | 31 | 63 | 127（精確 N-1）|
| **strict** | 14.6 | 30.2 | 58.2 | 121.8（≈ N-1，但比 rr 少 ~4-7%）|

**機制推測**（待 DocDB internal metrics 佐證）：
- rr (SI) 採 first-committer-wins：N 個 worker 同時 BEGIN，1 個 commit 成功、N-1 個被拒
- strict (SSI) 多一道 serializable conflict detector：部分情況下衝突在 read time 即被偵測 → early-abort 或 read-refresh 救回，**少數失敗被「合併」**
- 仍維持 ~N-1 是因為 hot row 衝突的根本性質沒變（128W TPC-C 的 district 1280 row + warehouse 128 row 是 deterministic hot zone）

PAYMENT_ERR / NEW_ORDER_ERR 比例：
- rr t128：PAYMENT 89 + NEW_ORDER 37（PAYMENT 占 70%）
- strict t128：PAYMENT 53.8 + NEW_ORDER 68.0（PAYMENT 占 44%）
→ SSI 抓 NEW_ORDER 的 district hot row 比 SI 更敏感（serializable detector 提前發現），PAYMENT 反而被「少抓到」（讀寫衝突在 read-refresh 階段救回）

### DB-host (.32) 飽和分析 ★（idle 最極端的一組）

| threads | %usr mean | %sys mean | %iowait mean | %idle mean | %idle min | sda %util |
|---------|-----------|-----------|--------------|------------|-----------|-----------|
| 16  | 9.7%  | 4.5% | 13.04% | **71.44%** | 60.41% | 70.4% |
| 32  | 10.0% | 4.5% | 12.83% | **71.33%** | 38.75% | 70.6% |
| 64  | 10.5% | 4.9% | 12.49% | **70.56%** | 7.04%  | 68.6% |
| 128 | 10.9% | 5.1% | 12.46% | **70.02%** | **5.76%** | 68.6% |

> **核心發現**：strict 比 rr 還更 idle（rr 為 66-67%、strict 為 70-71%）— 三家三 iso 中 **DB-host 利用率最低的一組**，throughput 卻是 YugabyteDB 三 iso 最低。瓶頸 100% 在 transaction coordination layer（SSI serializable detector + read-refresh round-trip）。

| 維度 | rc t128 | rr t128 | strict t128 |
|------|---------|---------|-------------|
| tpmC | 10,885 | 1,714 | 1,129 |
| %user | 74.7% | 14.1% | **10.9%** |
| %sys | 18.5% | 5.8% | 5.1% |
| %iowait | 0.25% | 11.77% | 12.46% |
| %idle | 1.89% | 66.57% | **70.02%** |
| sda %util | 42.8% | 62.3% | **68.6%** |

→ strict disk %util 68.6% **比 rc 42.8% 高 60%**，但 throughput 砍 10x；**disk-per-txn 寫入放大**。推測為 SSI version metadata + read-refresh 過程的 DocDB tablet meta read/write 大量小 IO。

### vs YugabyteDB rc / rr 對比

| threads | rc tpmC | rr tpmC | strict tpmC | strict vs rc | strict vs rr |
|---------|---------|---------|-------------|--------------|--------------|
| 16  | 10,653 | 1,846 | 1,096 | -89.7% | -40.6% |
| 32  | 11,436 | 1,879 | **1,130** | -90.1% | -39.9% |
| 64  | 11,240 | 1,847 | 1,092 | -90.3% | -40.9% |
| 128 | 10,885 | 1,714 | 1,129 | -89.6% | -34.1% |

| threads | rc p99 (ms) | rr p99 (ms) | strict p99 (ms) |
|---------|-------------|-------------|-----------------|
| 16  | 104  | 61   | 61   |
| 32  | 216  | 174  | 58   |
| 64  | 440  | 240  | 62   |
| 128 | 1000 | 1020 | **54** ← 最低 |

→ **strict p99 t128 = 54 ms 全 iso 最低**（rr/rc 都接近 1000ms）— 但這是 **「throughput 被閘住、queue 沒累積」的副作用**，非 strict 本質快。完成的少數 NEW_ORDER 確實單筆延遲低；但 throughput 砍 10x 換來的低 p99，business 體感是「app 等資料庫等很久後拿到的單筆比 rc/rr 快一點」，不是 win。

### vs CockroachDB strict 對比 ★ — 反 pattern 機制歸納

| 維度 | CockroachDB strict | YugabyteDB strict |
|------|-------------|-------------|
| tpmC peak | 10,830 @ t64 | 1,130 @ t32 |
| vs 自家 rc | **+18.6%** @ t64（超越 RC）| **-90.1%** @ t32（遠不如 RC）|
| 自家 rc 飽和 | IO-wait bound（%iowait 18%、%idle 5%、%user 68%）| CPU-bound（%user 74% + %sys 18% ≈ 92%、%idle 1.9%、%iowait 0.25%）|
| strict 對 rc 的 CPU 增量影響 | rc 有 30% CPU headroom → strict 改走 CPU-heavy read-refresh **無感** | rc 已撞 CPU ceiling → strict 額外 CPU 工作**直接搶 CPU budget** |
| 結論 | 反直覺 strict ＞ rc | 順直覺 strict ＜ rc，**但反 CockroachDB pattern** |

**規律歸納**：「**強 isolation 反而快**」這個直覺反例只在 **baseline RC 為 IO-bound** 時成立（CockroachDB 用 per-commit fsync 撞 IO wall）。當 baseline 為 CPU-bound（YugabyteDB、TiDB），SSI / SS2PL 的額外 CPU 工作直接拖慢，無法翻盤。

### Saturation 分析

```
threads:    16 ──── 32 ──── 64 ──── 128
tpmC:     1,096  1,130  1,092  1,129
                  +3.1%  -3.4%  +3.4%       ← 完全 flat-line ~1,100

p99 (ms):    61    58    62    54
                  -4.9%  +6.9%  -12.9%      ← latency 不隨 thread 上升

DB %idle: 71.44% 71.33% 70.56% 70.02%       ← DB 大量 idle (70%+ 全程)
DB %iowait: 13.04% 12.83% 12.49% 12.46%     ← IO wait 中位
sda %util: 70.4%  70.6%  68.6%  68.6%       ← disk 利用率反而高（!）
err / round: 14.6  30.2  58.2  121.8        ← ≈ N-1
```

**結論**：YugabyteDB strict throughput 的天花板 ~1,130（4 vCPU 硬體下），所有 thread 完全 flat、無 scale-out 跡象。瓶頸在 SSI serializable detector + read-refresh 的單線程化 coordination 層；DB-host CPU 大量閒置 + disk %util 70% 反差，可能是 read-refresh 階段大量小 IO 但無法 batch。

### 觀察

- **strict 是三 iso 中最慢、但 latency 最穩**（range/mean t128 = 1.8% 為三 iso 最低）；strict 的「穩定的慢」勝過 rr 的「波動的慢」（rr t128 r5 collapse 至 1173），對 SLA 一致性敏感的 app 反而適合
- **strict ≈ N-1 errors 但 NEW_ORDER 占比比 PAYMENT 高**（與 rr 相反）— SSI serializable detector 對 district hot row 的偵測比 SI 早 trigger；PAYMENT 的 warehouse 衝突在 read-refresh 階段救回
- **strict disk %util 70% 異常高**（rc 43% / rr 62%）— 推測為 SSI version metadata + read-refresh 的 DocDB tablet meta read/write 放大 IO；待 DocDB `tablet/transactions` 指標進一步驗證
- **反 CockroachDB pattern**：CockroachDB strict ＞ rc 因 CockroachDB rc 為 IO-bound，SSI 改走 CPU 路徑剛好避瓶頸；YugabyteDB rc 為 CPU-bound 已無 headroom，strict 不可能翻盤

### 結論

YugabyteDB v2025.2.2.2 vm-1node strict (SERIALIZABLE / SSI) 在 4 vCPU + single disk 硬體下：
- **吞吐天花板 ~1,130 tpmC**（比 rc 11,436 砍 90%、比 rr 1,879 還少 40%、比 CockroachDB strict 10,830 少 90%）
- **err ≈ N-1**（t16=14.6、t32=30.2、t64=58.2、t128=121.8）— 與 rr 同 pattern 但略少 ~5%（SSI 早期偵測 + read-refresh 救回部分衝突）
- **DB-host 70%+ idle、disk %util 70%** — coordination-layer bound + 小 IO 放大

**業務啟示**：
- YugabyteDB strict 在本 workload **不是 CockroachDB-style「反直覺最快」的選項**；rc 仍最快
- 若 app 需要嚴格 serializable 一致性，YugabyteDB strict 是正確選項，但 throughput 預期會砍 10x；應提早做 capacity planning
- 跨家 strict 比較：CockroachDB SSI 10x YugabyteDB SSI tpmC，因 CockroachDB SSI 善用 IO headroom；YugabyteDB SSI 在 CPU-bound baseline 上把吞吐拖到底

---

## vm-3node 系列（4 sub-topology × RC，PoC-DESIGN §6.3.2）

> 本段為 YugabyteDB 2025.2 在 vm-3node 拓樸 / `READ COMMITTED` 隔離級下的 4 個 sub-topology baseline。**2026-05-24/25 全 4 cells 完成**（post-patch，0 fatal）；haproxy-3s3r 同 2026-05-25 完成為第 5 cell（詳見下方 [vm-3node-haproxy-3s3r-rc](#vm-3node-haproxy-3s3r-rc3-shards--rf3--haproxy)）。詳細跨 cell 比較見 [results/dispatch-records/2026-05-25-vm-3node-ybdb-all4-rc-analysis.md](../../dispatch-records/2026-05-25-vm-3node-ybdb-all4-rc-analysis.md)；5-cell 完整摘要見 [`SUMMARY-ybdb-vm3.md`](../../dispatch-records/SUMMARY-ybdb-vm3.md)。

### 共同元件分配（3 顆 VM）

```
            client (.31)
              │  go-tpc → :5433 (YSQL)
              ▼
   ┌──────────┴──────────┐
   │     172.24.40.32    │  ← client 入口 / cluster bootstrap node
   │  yb-master + 7100   │
   │  yb-tserver + 5433  │
   └─────────┬───────────┘
             │ Raft (master quorum, tserver tablet Raft)
   ┌─────────┴────────────────────────┐
   │                                  │
┌──┴──────────────────┐    ┌──────────┴───────────┐
│  172.24.40.33       │    │  172.24.40.34        │
│  master + tserver   │    │  master + tserver    │
└─────────────────────┘    └──────────────────────┘
```

yb-master×3 滿足 Raft quorum；yb-tserver×3 滿足 RF=3 placement；client 統一 .32:5433 進入。

### Execute 結果總覽（vm-3node 5 cells）

> 口徑對齊 TiDB / CockroachDB vm-3node 段：代表點採各 sub-topology 的主要觀察併發；完整 per-round thread sweep 見各 cell 的 `Execute 結果` 表。p99 為 NEW_ORDER 5-round latency mean；err 為 all transaction error rate。前 4 cells 為 direct 連線，第 5 cell 為 HAProxy 連線分散變體。

| sub-topology | shard / RF | TPCC_TS | 代表併發 | tpmC mean | range/mean | NO p99 mean (ms) | err | N | 判讀 |
|---|---:|---|---:|---:|---:|---:|---:|---:|---|
| [`1s1r`](#vm-3node-1s1r-rc) | 1 / 1 | [`20260524T032814`](./vm-3node-1s1r-rc/ybdb-vm-3node-1s1r-rc-20260524T032814+0800/) | 32 | 13,702 | 10.9% | 205 | 0.00% | 1 | RF=1 / 1 shard 最小 cluster baseline |
| [`1s3r`](#vm-3node-1s3r-rc) | 1 / 3 | [`20260524T074754`](./vm-3node-1s3r-rc/ybdb-vm-3node-1s3r-rc-20260524T074754+0800/) | 128 | 10,228 | 1.9% | 1,034 | 0.00% | 1 | 固定 1 shard，量化 RF=3 quorum 成本 |
| [`3s1r`](#vm-3node-3s1r-rc) | 3 / 1 | [`20260524T202219`](./vm-3node-3s1r-rc/ybdb-vm-3node-3s1r-rc-20260524T202219+0800/) | 32 | 11,967 | 3.0% | 203 | 0.00% | 1 | 固定 RF=1，量化 sharding 成本 |
| [`3s3r`](#vm-3node-3s3r-rc) | 3 / 3 | [`20260525T031918`](./vm-3node-3s3r-rc/ybdb-vm-3node-3s3r-rc-20260525T031918+0800/) | 128 | 8,729 | 62.3% | 1,114 | 0.00% | 1 | shard + replica 疊加；高變異 |
| [`haproxy-3s3r`](#vm-3node-haproxy-3s3r-rc3-shards--rf3--haproxy) | 3 / 3 | [`20260525T193740`](./vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/) | 128 | 15,632 | 7.1% | 705 | 0.00% | 1 | HAProxy roundrobin；對 direct 3s3r +79.1% tpmC |

### vm-3node-1s1r-rc

> 1 shard × 1 replica：3-tserver cluster 但 RF=1、每表 1 tablet。對照 vm-1node-rc 量化「cluster framework + remote coord」純成本。

#### 拓樸示意

```
yb-master quorum (3)
.32 master ⇄ .33 master ⇄ .34 master  (RF=1)
                  ▲ tablet placement / leader election
yb-tserver
.32 [t.tablet-leader]    .33 (no replica)    .34 (no replica)
                       └─ RF=1 只在 1 tserver
client → .32:5433 (YSQL gateway 路由 to tablet leader)
```

#### 關鍵 DB 設定

| 維度 | 設定 | 來源 |
|---|---|---|
| `yugabyted start --rf` | `1` | `yugabyte-vm3.yml` (`yb_rf`) |
| tserver `yb_enable_read_committed_isolation` | `true` | RC 必要前提 |
| tserver `enable_automatic_tablet_splitting` | `false` | controlled experiment（§7.5.3）|
| tserver `ysql_num_shards_per_tserver` | `1` | 控 default tablet 數 |
| tserver `durable_wal_write` / `require_durable_wal_write` | `true` / `true` | fsync-on-commit |
| Pre-create schema | 9 張表 `SPLIT INTO 1 TABLETS` | prepare 階段（避 3 tserver × 1 預設成 3 tablets）|
| conn-params (RC) | `options=-c default_transaction_isolation=read committed` | §7.3 |

#### Dry-run 預期

- `cluster-topology.txt` ≥ 3 tserver Alive（`yb-admin list_all_tablet_servers`）
- `replication-factor.txt`（`yb-admin get_universe_config`）`num_replicas = 1`
- `iso-preset.txt`：`transaction_isolation = read committed`、`yb_effective_transaction_isolation_level = read committed`（雙閘檢驗，避 silent SI fallback）
- `cluster-health.txt` = `SELECT 1` 回 1

#### Execute 結果（2026-05-24，TS=20260524T032814+0800）

> per-round tpmC + 5-round mean（W=128、RC、N=1）。p99 為 NEW_ORDER 5-round latency mean；err 為 all transaction `error_rate_pct`。補充指標見 [`summary.json`](./vm-3node-1s1r-rc/ybdb-vm-3node-1s1r-rc-20260524T032814+0800/summary.json)。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 11,595 | 11,556 | 11,360 | 11,551 | 11,396 | 11,491 | 2.0% | 90 | 0.00% |
| 32 | 14,118 | 13,988 | 12,627 | 13,860 | 13,915 | 13,702 | 10.9% | 205 | 0.00% |
| 64 | 14,112 | 12,337 | 12,389 | 12,931 | 14,233 | 13,200 | 14.4% | 396 | 0.00% |
| 128 | 13,868 | 13,741 | 13,716 | 13,836 | 13,462 | 13,725 | 3.0% | 758 | 0.00% |

#### 代表點

**t=32 / 13,702 tpmC / NO p99 = 205 ms**。對照 vm-1node-rc 11,436 → +20% throughput（cluster framework 不僅無 overhead 反而吃糖，待跨日重採確認是否 host I/O 雜訊影響）。詳見 [results/dispatch-records/2026-05-25-vm-3node-ybdb-all4-rc-analysis.md](../../dispatch-records/2026-05-25-vm-3node-ybdb-all4-rc-analysis.md)。

### vm-3node-1s3r-rc

> 1 shard × 3 replica：3 tserver 各持 1 tablet replica，leader + 2 follower。對照 1s1r 量化「Raft 3-replica 寫入成本」。

#### 拓樸示意

```
yb-master quorum (3)
.32 master ⇄ .33 master ⇄ .34 master  (RF=3)
yb-tserver
.32 [t.tablet-leader]
.33 [t.tablet-follower] ←─┐ Raft majority commit
.34 [t.tablet-follower] ←─┘
client → .32:5433
```

#### 關鍵 DB 設定

| 維度 | 設定 |
|---|---|
| `yugabyted start --rf` | `3` |
| Pre-create schema | 9 張表 `SPLIT INTO 1 TABLETS` |
| 其餘 | 同 1s1r |

#### Dry-run 預期

- `replication-factor.txt`：`num_replicas = 3`
- 其餘同 1s1r。

#### Execute 結果（2026-05-24，TS=20260524T074754+0800）

> per-round tpmC + 5-round mean（W=128、RC、N=1）。p99 為 NEW_ORDER 5-round latency mean；err 為 all transaction `error_rate_pct`。補充指標見 [`summary.json`](./vm-3node-1s3r-rc/ybdb-vm-3node-1s3r-rc-20260524T074754+0800/summary.json)。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 7,697 | 7,674 | 4,355 | 7,520 | 7,602 | 6,970 | 47.9% | 144 | 0.00% |
| 32 | 9,305 | 9,440 | 9,936 | 9,203 | 9,084 | 9,394 | 9.1% | 245 | 0.00% |
| 64 | 9,996 | 10,116 | 10,002 | 10,196 | 10,031 | 10,068 | 2.0% | 476 | 0.00% |
| 128 | 10,268 | 10,130 | 10,320 | 10,228 | 10,193 | 10,228 | 1.9% | 1,034 | 0.00% |

#### 代表點

**t=128 / 10,228 tpmC / NO p99 = 1,034 ms**。對照 vm-3node-1s1r（同 1-shard、RF=1）→ **−25.5% throughput / +36% NO p99**，量化 Raft 3-replica 寫入成本。t=16 range/mean 47.9%（warmup 過渡期），t=64-128 range/mean ≤2.0% 極穩。詳見 analysis report。

### vm-3node-3s1r-rc

> 3 shard × 1 replica：每表 3 tablet 自然分散到 3 tserver（3 × 1 = 3）。對照 1s1r 量化「sharding 對 OLTP 效應」。

#### 拓樸示意

```
yb-master quorum (3, RF=1)
yb-tserver
.32 [t.tablet-A-leader]  .33 [t.tablet-B-leader]  .34 [t.tablet-C-leader]
     └ RF=1                └ RF=1                  └ RF=1
client → .32:5433
```

#### 關鍵 DB 設定

| 維度 | 設定 |
|---|---|
| `yugabyted start --rf` | `1` |
| Pre-create schema | **需要** `SPLIT INTO 3 TABLETS` ★ |
| Hard gate | `yb-admin list_tablets ysql.tpcc <table>` 9 表 = 3 tablets |
| 其餘 | 同 1s1r |

> ⚠️ **2026-05-23 實測修正**：原以為「RF=1 + 3 tservers × ysql_num_shards_per_tserver=1 = 3 tablets 自然」，**錯**。`yugabyted configure data_placement --rf=1` 之後 placement 只覆蓋 1 個 tserver，table 預設 tablets = 1 × 1 = **1**。修法在 prepare.sh 用 sed 把 schema file 的 `SPLIT INTO 1 TABLETS` 替換為 `SPLIT INTO 3 TABLETS`（covers 1s/3s 兩種 case），詳見 PoC-DESIGN §7.5.3。

#### Dry-run 預期

- 同 1s1r（shard hard gate 由 prepare 執行；不符即 fail-closed）。

#### Execute 結果（2026-05-24，TS=20260524T202219+0800）

> per-round tpmC + 5-round mean（W=128、RC、N=1）。p99 為 NEW_ORDER 5-round latency mean；err 為 all transaction `error_rate_pct`。補充指標見 [`summary.json`](./vm-3node-3s1r-rc/ybdb-vm-3node-3s1r-rc-20260524T202219+0800/summary.json)。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 11,276 | 11,248 | 11,322 | 11,024 | 11,031 | 11,180 | 2.7% | 94 | 0.00% |
| 32 | 11,986 | 11,951 | 11,961 | 12,148 | 11,789 | 11,967 | 3.0% | 203 | 0.00% |
| 64 | 11,728 | 11,753 | 11,769 | 11,770 | 11,724 | 11,749 | 0.4% | 436 | 0.00% |
| 128 | 11,796 | 11,650 | 11,612 | 11,769 | 11,628 | 11,691 | 1.6% | 1,007 | 0.00% |

#### 代表點

**t=32 / 11,967 tpmC / NO p99 = 203 ms**。對照 1s1r（同 RF=1、1-shard）→ **−12.7% throughput**，量化 sharding 純成本（cross-tablet coordination）。所有 thread groups range/mean ≤3.0%，是 direct 4 cells 中最穩。詳見 analysis report。

### vm-3node-3s3r-rc

> 3 shard × 3 replica：完整 sharded + replicated cluster。對照 1s3r 量化「sharding 在 RF=3 下的攤平效益」；與 3s1r 比 → replication overhead in sharded cluster。

#### 拓樸示意

```
yb-master quorum (3, RF=3)
yb-tserver（每 tserver 持有所有 tablet 的某 replica）
.32 [A-leader / B-follower / C-follower]
.33 [A-follower / B-leader / C-follower]
.34 [A-follower / B-follower / C-leader]
client → .32:5433
```

#### 關鍵 DB 設定

| 維度 | 設定 |
|---|---|
| `yugabyted start --rf` | `3` |
| Pre-create schema | **需要** `SPLIT INTO 3 TABLETS`（同 3s1r 修法）|
| 其餘 | 同 3s1r |

#### Dry-run 預期

- `replication-factor.txt`：`num_replicas = 3`
- master raft alive = 3（RF=3 cluster：.32 .33 .34 三 master 全 ALIVE）
- 其餘同 1s1r。

#### Execute 結果（2026-05-25，TS=20260525T031918+0800）

> ⚠️ **2026-05-23 首次 dispatch 踩 LookupByIdRpc / kResponseSent timeout cascade**（root cause = parallel `yugabyted --join=primary` 造成 tserver_master_addrs 不一致 + cell 4 81-replicas 高負載觸發 leader rebalance）。
>
> 修法（已 commit `d654824` / `68189bc` / `29b5fc5`）：
> - `ansible/playbooks/yugabyte-vm3.yml` 加 `serial: 1` on Join workers
> - `tests/common/dry-run-confirm.sh` 改 RF-aware cluster health gate（master raft alive = expected_rf；3 tservers ALIVE heartbeating；每 tserver cmdline ≥1 raft master endpoint）

> per-round tpmC + 5-round mean（W=128、RC、N=1；post-patch，0 fatal）。p99 為 NEW_ORDER 5-round latency mean；err 為 all transaction `error_rate_pct`。補充指標見 [`summary.json`](./vm-3node-3s3r-rc/ybdb-vm-3node-3s3r-rc-20260525T031918+0800/summary.json)。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 4,552 | 1,517 | 3,035 | 7,325 | 7,453 | 4,776 | 124.3% | 153 | 0.00% |
| 32 | 5,654 | 8,458 | 8,666 | 5,161 | 5,152 | 6,618 | 53.1% | 272 | 0.00% |
| 64 | 9,097 | 8,763 | 8,682 | 8,728 | 5,703 | 8,195 | 41.4% | 567 | 0.00% |
| 128 | 4,409 | 9,734 | 9,821 | 9,830 | 9,852 | 8,729 | 62.3% | 1,114 | 0.00% |

#### 代表點

**t=128 / 8,729 tpmC / NO p99 = 1,114 ms**。對照 1s1r 疊加 RF + shard 雙成本 → **−36.4% throughput / +47% NO p99**。

#### Caveat

3s3r 在 t=32 / t=64 CPU idle 高達 24-42% 但 throughput 反而 drop，workload 卡 tablet/raft 協調而非 CPU；所有 thread groups range/mean ≥41.4%，t=16 round-to-round 振幅 4.9×（min=1,517 / max=7,453）。**本 hardware 4 vCPU 不適合 3s3r 生產配置**，要穩定需 vCPU ≥ 8 或降 tablet 數。詳見 analysis report。

### vm-3node-haproxy-3s3r-rc（3 shards × RF=3 + HAProxy）

> 本段為 YugabyteDB 2025.2 在 `vm-3node-3s3r-rc` 基準上加入 HAProxy 連線分散的 N=1 結果。HAProxy 位於 `.20:5433`，以 roundrobin 分散到 `.32/.33/.34:5433` 三個 tserver/YSQL entry point；cluster 本身仍為 RF=3、每表 3 tablets、`READ COMMITTED`。

#### 拓樸示意

```
                     client (.31)
                       │  go-tpc → 172.24.47.20:5433
                       ▼
            ┌──────────────────────┐
            │  HAProxy on .20:5433  │
            │  balance roundrobin   │
            │  mode tcp             │
            └─────┬────┬────┬───────┘
                  │    │    │
        .32:5433  │    │    │  .34:5433
         tserver  │    │    │   tserver
                  │ .33:5433│
                  │ tserver │
   底層 cluster：3-master / 3-tserver，RF=3，每表 SPLIT INTO 3 TABLETS
```

#### 關鍵 DB 設定（與 3s3r 完全相同；唯一變因是 SQL frontend）

| 維度 | 設定 |
|---|---|
| `yugabyted start --rf` | `3` |
| Pre-create schema | 9 張表 `SPLIT INTO 3 TABLETS`（同 3s3r 修法） |
| HAProxy 主機 | `172.24.47.20:5433` |
| HAProxy timeout | `timeout connect 10s` / `timeout client 1h` / `timeout server 1h` |
| HAProxy keepalive | `option clitcpka` / `option srvtcpka` |
| HAProxy balance | `roundrobin` / `mode tcp` |
| HAProxy stats socket | `/var/lib/haproxy/stats` |
| client `--db-host` | `172.24.47.20:5433`（HAProxy frontend） |

#### Dry-run 預期

- `actual-rf` 同 3s3r = 3（master raft alive = 3）
- `replication-factor.txt`：`num_replicas = 3`
- HAProxy backend health：3 個 server check OK（cfg 中 `check inter 2s`）
- 首次 dispatch TS `20260525T155542+0800` 因 `coldreset-ybdb.sh` 漏 patch 中斷 → **不採用**；正式 TS `20260525T193740+0800` PASS

#### Artifact 與取數口徑

| 項目 | 值 |
|---|---|
| TPCC_TS | `20260525T193740+0800` |
| 來源目錄 | [`./vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/`](./vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/) |
| 完整 marker | 7 completed：gate / gate-isolation / prepare / run / collect / db-config / suite |
| go-tpc stdout | 20 files（4 thread groups × 5 rounds） |
| summary.json | 已由 [`tests/common/summary-from-stdout.py`](../../../tests/common/summary-from-stdout.py) 從 raw stdout 補產 |
| DB-host metrics | 檔案存在但內容為 `command not found`（`mpstat` / `iostat`），不可作 DB-host 飽和判讀 |
| 詳細分析 | [HAProxy vs direct 3s3r analysis](../../dispatch-records/2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md) |

#### Execute 結果（2026-05-25，TS=20260525T193740+0800）

> per-round tpmC + 5-round mean（W=128、RC、N=1）。p99 為 NEW_ORDER 5-round latency mean；err 為 all transaction `error_rate_pct`。補充指標見 [`summary.json`](./vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/summary.json)。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 7,987 | 7,766 | 8,211 | 7,896 | 8,127 | 7,997 | 5.6% | 135 | 0.00% |
| 32 | 10,461 | 10,930 | 10,400 | 11,221 | 10,309 | 10,664 | 8.6% | 220 | 0.00% |
| 64 | 13,063 | 13,196 | 13,680 | 12,978 | 13,764 | 13,336 | 5.9% | 386 | 0.00% |
| 128 | 15,688 | 15,018 | 15,569 | 15,764 | 16,122 | 15,632 | 7.1% | 705 | 0.00% |

#### 代表點

**t=128 / 15,632 tpmC / NO p99 = 705 ms**。對照 direct `vm-3node-3s3r-rc` 代表點 **8,729 tpmC / NO p99 = 1,114 ms**，HAProxy 增加 **+79.1% tpmC**，NO p99 降低約 **-36.7%**。

#### Caveat

- 本組為 N=1；N=3 待後續時程空檔再確認。
- direct 3s3r baseline 本身高變異，HAProxy delta 可能受 direct outlier 放大。
- DB-host metrics missing：`mpstat-db.txt` / `iostat-1s-db.txt` 等檔案內容為 `command not found`，本輪 DB-side 飽和分析不可作直接量測結論。
- `summary.json` 已於 2026-05-26 由 raw stdout 補產；DB-host metrics caveat 仍保留。

---

## Kubernetes 段 — 已存檔於 yuga-tc1-old/archive

> 2026-05-13 的 k8s-3node-unlimit / k8s-3node-limit 為 pre-v4.7 單次 10min wrapper 結果，已隨主檔清空動作備份於 [`../../yuga-tc1-old/archive/`](../../yuga-tc1-old/archive/) ＋ [`archive/pipeline-log_old.md`](../../yuga-tc1-old/archive/pipeline-log_old.md)（pre-v4.7 narrative）。待 Kubernetes 環境以 v4.7 detached suite 重跑後，將回填正式段落。
