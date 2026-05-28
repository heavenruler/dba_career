# 2026-05-22 vm-3node-rc pre-check dispatch record

- **Scope**: 12 cells × dry-run anchor（依 PoC-DESIGN §6.3.2.3 / §6.3.2.4）
- **Status**: ✅ 全綠 — 全部 12 cells `.dry-run.done` `all_pass=true`
- **對應 commits**: `242d9df` → `0409b76`（git log 摘要見下方 §3）

---

## 1. Shard / Replica 概念說明

分散式資料庫通常同時用 **shard** 分散流量，用 **replica** 提供容錯。

```text
Shard（分片）+ Replica（複本 / RF）：先把資料切開，再把每個 shard 複製到多個節點

  data
   ├─ shard 1
   │   ├─ replica 1 ── IDC node-1
   │   ├─ replica 2 ── IDC node-2
   │   └─ replica 3 ── GCP node-1
   ├─ shard 2
   │   ├─ replica 1 ── IDC node-2
   │   ├─ replica 2 ── GCP node-1
   │   └─ replica 3 ── GCP node-2
   └─ shard 3
       ├─ replica 1 ── GCP node-1
       ├─ replica 2 ── GCP node-2
       └─ replica 3 ── IDC node-1
```

本 PoC 用 4 組 cell 拆解 shard / replica 成本：

| cell | 觀察重點 |
|---|---|
| `1s1r` | 最小基準：1 shard、RF=1 |
| `1s3r` | 固定 1 shard，只觀察 replica / RF 成本 |
| `3s1r` | 固定 RF=1，只觀察 shard 成本 |
| `3s3r` | production-like 代表點；同時觀察 3 shards 的資料 / 流量分散成本，以及 RF=3 的三副本同步與 quorum commit 成本 |

### 各 DB 如何體現 shard / replica

| DB | deploy guardrail | prepare shard 控制點 | Replica / RF 體現方式 | 驗證點 |
|---|---|---|---|---|
| TiDB | 設大 `coprocessor.region-split-size`，避免 size split 干擾 | 1 shard 不手動 split；3 shards 在 go-tpc prepare 後用 `SPLIT TABLE ... REGIONS 3` 鎖定 9 張表 Region 數 | PD `replication.max-replicas=N` | dry-run 驗 RF；shard actual 驗 `prepare/shard-count.txt` |
| CockroachDB | 關 `kv.range_split.by_load_enabled`，避免 load-based split 干擾 | 1 shard 不手動 split；3 shards 在 go-tpc prepare 後用 `ALTER TABLE ... SPLIT AT` 鎖定 9 張表 Range 數 | zone config `num_replicas=N` | dry-run 驗 RF；shard actual 驗 `prepare/shard-count.txt` |
| YugabyteDB | 設 [`--ysql_num_shards_per_tserver`](https://docs.yugabyte.com/stable/reference/configuration/yb-tserver/#ysql-num-shards-per-tserver)=1 與 [`--enable_automatic_tablet_splitting`](https://docs.yugabyte.com/stable/reference/configuration/yb-tserver/#enable-automatic-tablet-splitting)=false，避免預設 tablet / 自動 split 干擾 | go-tpc prepare 前 pre-create 9 張 TPC-C tables，依 cell 套 `SPLIT INTO 1 TABLETS` 或 `SPLIT INTO 3 TABLETS` | 透過 [`yugabyted configure data_placement`](https://docs.yugabyte.com/stable/reference/configuration/yugabyted/) 設定 `--rf=N`；實際 universe placement 可由 [`yb-admin get_universe_config`](https://docs.yugabyte.com/stable/admin/yb-admin/#get-universe-config) 觀察 | dry-run 驗 RF；shard actual 驗 `prepare/shard-count.txt` |

> 本 pre-check 是 deploy-time gate：確認 cluster、RF、isolation 已對齊。Shard actual 不在 dry-run artifact 內，不能把 `Shard planned` 解讀成已驗證結果。

Shard 控制點補充：

- TiDB / CockroachDB
  - deploy 階段先關掉自動分裂干擾
  - prepare 後對既有 TPC-C tables 手動 split
  - 最後用 `prepare/shard-count.txt` 驗 actual

- YugabyteDB
  - deploy 參數只是 guardrail
  - 正式 shard 數在 prepare 前靠 schema pre-create 的 `SPLIT INTO N TABLETS` 鎖定
  - `--ysql_num_shards_per_tserver` 只定義預設 tablet 行為
  - `--enable_automatic_tablet_splitting` 只負責關掉背景 split
  - 因 go-tpc schema 使用 `CREATE TABLE IF NOT EXISTS`，後續 prepare 不會覆寫已 pre-create 的 tables

- 補充判讀
  - 不能只用 `ysql_num_shards_per_tserver × tserver 數` 推論 shard 數
  - 2026-05-23 已確認 RF=1 placement 會讓 3 tservers 推論失效
  - 所以 3s*r 也必須明確 `SPLIT INTO 3 TABLETS`
  - 理論上可改用 cluster default、自動 tablet splitting 或 prepare 後 split
  - 但這些作法會讓 tablet 數變成背景行為或額外流程推論
  - 本 PoC 不採用；`SPLIT INTO N TABLETS` 是本輪唯一正式 shard 控制點

### 各 DB 如何體現 isolation

三家資料庫的 READ COMMITTED 不是同一組內部機制，所以 gate 不能只看 benchmark 參數。

| DB | 需要看的 variable / status | artifact 對照 |
|---|---|---|
| TiDB | [`@@transaction_isolation`](https://docs.pingcap.com/tidb/stable/system-variables/#transaction_isolation)、[`@@tidb_txn_mode`](https://docs.pingcap.com/tidb/stable/system-variables/#tidb_txn_mode) | [`iso-preset.txt`](../tidb-tc1/S-BASE/vm-3node-1s1r-rc/tidb-vm-3node-1s1r-rc-20260522T095010+0800/dry-run/iso-preset.txt)、[`expected-vs-actual.txt`](../tidb-tc1/S-BASE/vm-3node-1s1r-rc/tidb-vm-3node-1s1r-rc-20260522T095010+0800/dry-run/expected-vs-actual.txt) |
| CockroachDB | [`SHOW transaction_isolation`](https://www.cockroachlabs.com/docs/v26.2/session-variables.html)、[`SHOW default_transaction_isolation`](https://www.cockroachlabs.com/docs/v26.2/session-variables.html) | [`iso-preset.txt`](../crdb-tc1/S-BASE/vm-3node-1s1r-rc/crdb-vm-3node-1s1r-rc-20260522T111834+0800/dry-run/iso-preset.txt)、[`expected-vs-actual.txt`](../crdb-tc1/S-BASE/vm-3node-1s1r-rc/crdb-vm-3node-1s1r-rc-20260522T111834+0800/dry-run/expected-vs-actual.txt) |
| YugabyteDB | [`--ysql_default_transaction_isolation`](https://docs.yugabyte.com/stable/reference/configuration/yb-tserver/#ysql-default-transaction-isolation)、[`--yb_enable_read_committed_isolation`](https://docs.yugabyte.com/stable/reference/configuration/yb-tserver/#yb-enable-read-committed-isolation)、[`SHOW TRANSACTION ISOLATION LEVEL`](https://docs.yugabyte.com/stable/api/ysql/the-sql-language/statements/txn_show/)、`SELECT yb_get_effective_transaction_isolation_level()` | [`iso-preset.txt`](../yuga-tc1/S-BASE/vm-3node-1s1r-rc/ybdb-vm-3node-1s1r-rc-20260522T125647+0800/dry-run/iso-preset.txt)、[`expected-vs-actual.txt`](../yuga-tc1/S-BASE/vm-3node-1s1r-rc/ybdb-vm-3node-1s1r-rc-20260522T125647+0800/dry-run/expected-vs-actual.txt) |

判讀重點：

- TiDB：`READ-COMMITTED` 與 `pessimistic` 同時成立，才視為 RC gate 通過。
- CockroachDB：session active isolation 顯示 `read committed`，才視為 RC gate 通過。
- YugabyteDB：採 **YB triple gate**，避免看似 RC、實際落回 snapshot isolation。

YB triple gate 需同時通過：

1. default gate：`--ysql_default_transaction_isolation='read committed'`
2. enable gate：`--yb_enable_read_committed_isolation=true`
3. active / effective gate：`SHOW TRANSACTION ISOLATION LEVEL` 與 `yb_get_effective_transaction_isolation_level()` 都回報 `read committed`

> 注意：2026-05-22 dry-run artifact 仍使用 `SHOW yb_effective_transaction_isolation_level` 與 `.dry-run.done` 的 `yb_effective_iso`；[該 variable 已 deprecated](https://yugabytedb.tips/view-yb-run-time-parameters-values-and-descriptions/)。後續 dry-run script 應改用 `SELECT yb_get_effective_transaction_isolation_level()`。

---

## 2. 12 cells 結果矩陣

> cell 命名規則：`<db>-<shards>s<replicas>r`。例如 `ybdb-3s1r` 表示 YugabyteDB、3 shards、RF=1；`tidb-1s3r` 表示 TiDB、1 shard、RF=3。

| cell | TPCC_TS (recommended) | Shard planned | RF expected/actual | ISO expected/actual | Checked |
|---|---|---:|---:|---|:---:|
| `tidb-1s1r` | [20260522T095010](../tidb-tc1/S-BASE/vm-3node-1s1r-rc/tidb-vm-3node-1s1r-rc-20260522T095010+0800/) | 1 | [1 / **1**](../tidb-tc1/S-BASE/vm-3node-1s1r-rc/tidb-vm-3node-1s1r-rc-20260522T095010+0800/dry-run/expected-vs-actual.txt) | READ-COMMITTED / **READ-COMMITTED** | ✅ |
| `tidb-1s3r` | [20260522T132627](../tidb-tc1/S-BASE/vm-3node-1s3r-rc/tidb-vm-3node-1s3r-rc-20260522T132627+0800/) | 1 | [3 / **3**](../tidb-tc1/S-BASE/vm-3node-1s3r-rc/tidb-vm-3node-1s3r-rc-20260522T132627+0800/dry-run/expected-vs-actual.txt) | READ-COMMITTED / **READ-COMMITTED** | ✅ |
| `tidb-3s1r` | [20260522T135613](../tidb-tc1/S-BASE/vm-3node-3s1r-rc/tidb-vm-3node-3s1r-rc-20260522T135613+0800/) | 3 | [1 / **1**](../tidb-tc1/S-BASE/vm-3node-3s1r-rc/tidb-vm-3node-3s1r-rc-20260522T135613+0800/dry-run/expected-vs-actual.txt) | READ-COMMITTED / **READ-COMMITTED** | ✅ |
| `tidb-3s3r` | [20260522T135725](../tidb-tc1/S-BASE/vm-3node-3s3r-rc/tidb-vm-3node-3s3r-rc-20260522T135725+0800/) | 3 | [3 / **3**](../tidb-tc1/S-BASE/vm-3node-3s3r-rc/tidb-vm-3node-3s3r-rc-20260522T135725+0800/dry-run/expected-vs-actual.txt) | READ-COMMITTED / **READ-COMMITTED** | ✅ |
| `crdb-1s1r` | [20260522T111834](../crdb-tc1/S-BASE/vm-3node-1s1r-rc/crdb-vm-3node-1s1r-rc-20260522T111834+0800/) | 1 | [1 / **1**](../crdb-tc1/S-BASE/vm-3node-1s1r-rc/crdb-vm-3node-1s1r-rc-20260522T111834+0800/dry-run/expected-vs-actual.txt) | read committed / **read committed** | ✅ |
| `crdb-1s3r` | [20260522T132804](../crdb-tc1/S-BASE/vm-3node-1s3r-rc/crdb-vm-3node-1s3r-rc-20260522T132804+0800/) | 1 | [3 / **3**](../crdb-tc1/S-BASE/vm-3node-1s3r-rc/crdb-vm-3node-1s3r-rc-20260522T132804+0800/dry-run/expected-vs-actual.txt) | read committed / **read committed** | ✅ |
| `crdb-3s1r` | [20260522T135956](../crdb-tc1/S-BASE/vm-3node-3s1r-rc/crdb-vm-3node-3s1r-rc-20260522T135956+0800/) | 3 | [1 / **1**](../crdb-tc1/S-BASE/vm-3node-3s1r-rc/crdb-vm-3node-3s1r-rc-20260522T135956+0800/dry-run/expected-vs-actual.txt) | read committed / **read committed** | ✅ |
| `crdb-3s3r` | [20260522T141321](../crdb-tc1/S-BASE/vm-3node-3s3r-rc/crdb-vm-3node-3s3r-rc-20260522T141321+0800/) | 3 | [3 / **3**](../crdb-tc1/S-BASE/vm-3node-3s3r-rc/crdb-vm-3node-3s3r-rc-20260522T141321+0800/dry-run/expected-vs-actual.txt) | read committed / **read committed** | ✅ |
| `ybdb-1s1r` | [20260522T125647](../yuga-tc1/S-BASE/vm-3node-1s1r-rc/ybdb-vm-3node-1s1r-rc-20260522T125647+0800/) | 1 | [1 / **1**](../yuga-tc1/S-BASE/vm-3node-1s1r-rc/ybdb-vm-3node-1s1r-rc-20260522T125647+0800/dry-run/expected-vs-actual.txt) | read committed / **read committed** | ✅ |
| `ybdb-1s3r` | [20260522T130930](../yuga-tc1/S-BASE/vm-3node-1s3r-rc/ybdb-vm-3node-1s3r-rc-20260522T130930+0800/) | 1 | [3 / **3**](../yuga-tc1/S-BASE/vm-3node-1s3r-rc/ybdb-vm-3node-1s3r-rc-20260522T130930+0800/dry-run/expected-vs-actual.txt) | read committed / **read committed** | ✅ |
| `ybdb-3s1r` | [20260522T135840](../yuga-tc1/S-BASE/vm-3node-3s1r-rc/ybdb-vm-3node-3s1r-rc-20260522T135840+0800/) | 3 | [1 / **1**](../yuga-tc1/S-BASE/vm-3node-3s1r-rc/ybdb-vm-3node-3s1r-rc-20260522T135840+0800/dry-run/expected-vs-actual.txt) | read committed / **read committed** | ✅ |
| `ybdb-3s3r` | [20260522T135921](../yuga-tc1/S-BASE/vm-3node-3s3r-rc/ybdb-vm-3node-3s3r-rc-20260522T135921+0800/) | 3 | [3 / **3**](../yuga-tc1/S-BASE/vm-3node-3s3r-rc/ybdb-vm-3node-3s3r-rc-20260522T135921+0800/dry-run/expected-vs-actual.txt) | read committed / **read committed** | ✅ |

---

## 3. Artifact 位置（Mac 上落地）

每 cell 的 artifact 路徑（含 `.dry-run.done` + 5 個 dump txt）：

```
results/tidb-tc1/S-BASE/vm-3node-{1s1r,1s3r,3s1r,3s3r}-rc/tidb-vm-3node-<sub>-rc-<ts>/
results/crdb-tc1/S-BASE/vm-3node-{1s1r,1s3r,3s1r,3s3r}-rc/crdb-vm-3node-<sub>-rc-<ts>/
results/yuga-tc1/S-BASE/vm-3node-{1s1r,1s3r,3s1r,3s3r}-rc/ybdb-vm-3node-<sub>-rc-<ts>/
```

每 cell dir 內容：

```
<cell-ts>/.dry-run.done             — phase gate JSON (all_pass=true)
<cell-ts>/.lock-dry-run             — phase lock marker (empty file)
<cell-ts>/dry-run/cluster-topology.txt
<cell-ts>/dry-run/replication-factor.txt
<cell-ts>/dry-run/cluster-health.txt
<cell-ts>/dry-run/iso-preset.txt
<cell-ts>/dry-run/expected-vs-actual.txt
```

### 一鍵摘要命令（重驗用）

```bash
cd poc
# 1. 看全 12 cells .dry-run.done
for f in $(find results -name ".dry-run.done" -path "*/vm-3node-*-rc/*"); do
  echo "=== $f ==="
  jq '{cell: .topology, rf_actual, iso_actual, yb_effective_iso, all_pass}' "$f"
done

# 2. 跨 DB 並列（rf 必須 = expected_rf；iso 必須 = expected_iso）
find results -name "expected-vs-actual.txt" -path "*/vm-3node-*-rc/*" \
  -exec sh -c 'echo "=== ${1#results/} ==="; cat "$1"' _ {} \;
```

---

## 4. 過程踩到 4 個 deploy-time 坑 + 1 個 destroy race（commit 連發）

| commit | 修了什麼 | 觸發 cell |
|---|---|---|
| `caf9a12` | **systemd `no_proxy` CIDR**：IDC IT default 用 `172.16.0.0/12` CIDR，grpc-rust / yb-master / yb-tserver 不認 CIDR，跨 host RPC 一律走 sproxy 被攔 403 | tidb-1s1r 首發（TiKV `.33/.34` 連 `.32` PD 2 min timeout） |
| `de97435` | **CRDB cluster default num_replicas 在 deploy 階段就要設**：原 playbook 把 RF 配置延後到 prepare 階段（`ALTER DATABASE`），但 dry-run gate 在 prepare 前 probe，永遠看到 default RF=3，1s1r/3s1r 必 fail | crdb-1s1r |
| `b47adca` | **dry-run-confirm.sh YB camelCase + grep tripwire**：YB universe config JSON 是 `"numReplicas":N` (camelCase)，script regex 寫 `num_replicas` (snake_case)；加上 `set -euo pipefail` 下 `var=$(grep ... | head -1)` 沒 match 觸發 set -e → script 提前死 | ybdb-1s1r |
| `9c2bb60` | **yugabyted RF 設定用 `configure data_placement --rf=N`**：`yugabyted start --rf` 不認（unrecognized arguments），原 playbook 用 `yb-admin modify_universe_replication_info` 沒 verify 失效 | ybdb-1s3r |
| `0409b76` | **CRDB destroy race + 串進 chain**：`cockroach start --background` daemonize 後 systemctl loses track；不等 process 真死就 `rm /data/crdb` → 下次 deploy 帶舊 cluster ID join → `client cluster ID X doesn't match server Y` 死循環 | crdb-3s3r 連 2 次 transient fail |

git log:

```bash
git log --oneline poc/ -- ansible/ tests/ Makefile results/PoC-DESIGN.md | \
  grep -E "vm-3node|cockroach-vm3|yugabyte-vm3|no_proxy|dry-run-confirm|destroy-vm3"
```

---

## 5. 重跑單一 cell 的 reproducer

### 4.1 標準流程（destroy-all → deploy → dry-run anchor）

```bash
cd poc

# 換 sub_topology / 換 DB / 或單純想重跑某 cell：
make vm3-<db>-<sub>-rc TPCC_TS=$(date '+%Y%m%dT%H%M%S%z')
#   會自動 destroy-vm3-all → bootstrap-tpcc-client → deploy → dry-run-confirm
#   停在 .dry-run.done anchor；通過後再加 EXECUTE=1 才接 prepare/run/collect
```

### 4.2 只想再驗一次 dry-run-confirm（cluster 已 ready）

```bash
TS=20260522T095010+0800   # 用對應 cell 的 recommended TS
make dryrun-vm3-tidb-1s1r-rc TPCC_TS=$TS
# 結果寫 /tmp/poc-tpcc/artifacts/tidb-vm-3node-1s1r-rc-$TS/.dry-run.done
```

### 4.3 清 .31 上的 retry artifact dirs（6 個，PASS 但非 recommended TS）

```bash
ssh root@172.24.40.31 'ls /tmp/poc-tpcc/artifacts | sort'
# 12 個 recommended 已 fetch 走（rsync --remove-source-files 已清）；
# 剩 6 個是 retry 過程留下的 PASS dir，要清就：
ssh root@172.24.40.31 'rm -rf /tmp/poc-tpcc/artifacts/{crdb-vm-3node-3s1r-rc-20260522T135203+0800,crdb-vm-3node-3s3r-rc-20260522T134617+0800,tidb-vm-3node-3s1r-rc-20260522T134717+0800,tidb-vm-3node-3s3r-rc-20260522T134830+0800,ybdb-vm-3node-3s1r-rc-20260522T134944+0800,ybdb-vm-3node-3s3r-rc-20260522T135025+0800}'
```

---

## 6. dispatch log（過程留底）

| 來源 | 路徑 | 用途 |
|---|---|---|
| per-cell dispatch log | `/tmp/dispatch-logs/<cell>.log` | 該次 make 從 destroy → bootstrap → deploy → dryrun 全 stdout/err |
| per-cell TPCC_TS | `/tmp/dispatch-logs/<cell>-ts.txt` | 該次 dispatch 用的 timestamp |
| 6-cells batch log | `/tmp/dispatch-logs/h-loop.log` | 3s1r/3s3r batch 連跑摘要 |
| 6-cells batch script | `/tmp/dispatch-logs/h-batch.sh` | 跑 batch 用的 bash（含 destroy_all 邏輯實作版） |
| fetch summary | `/tmp/dispatch-logs/fetch-12-cells.log` | 12 cells 從 .31 → Mac 的 rsync 紀錄 |
| rtk tee log | `~/Library/Application Support/rtk/tee/*make_vm3-*_TPCC_TS_*.log` | rtk hook 完整 make output（含 ansible PLAY trace） |

> 注意：`/tmp/dispatch-logs/` 是 Mac 暫存，重開機會清。重要紀錄已在 git commit + Mac results/ 落地。

---

## 7. 還未做但已 spec 的後續

| 項目 | 卡在哪 | PoC-DESIGN 對應節 |
|---|---|---|
| EXECUTE=1 進 prepare（128W go-tpc + 9 表 SPLIT + hard gate） | `prepare.sh:80-82,192-193` 9 表 SPLIT SQL + region/range/tablet count gate 未實作 | §7.5.4 shard hard gate |
| haproxy-3s3r dispatch | dispatch chain 已可（playbook 沒寫 haproxy variant，需 patch） | §6.4.1 Phase F |
| EXECUTE=1 全 12 cells benchmark (~36 hr) | shard hard gate 上線後才能跑 | §6.4.2/3 |
