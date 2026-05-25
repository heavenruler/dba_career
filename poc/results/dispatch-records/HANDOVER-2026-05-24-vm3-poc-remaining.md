# vm-3node PoC 12 cells 交接 prompt（貼到新 session）

工作目錄：/Users/wn.lin/vscode-git/dba_career/poc
分支：master
語言：繁中（台灣），結論先行 ≤30 字，可執行；密碼/secret 不得出現
Git：commit only，never push

---

## 全局進度（4 sub_topology × 3 DB = 12 cells）

| # | DB | sub_topology | RF | shards | 狀態 | TPCC_TS |
|---|----|--------------|----|--------|------|---------|
| 1 | ybdb | 1s1r | 1 | 1 | ✅ done + fetched | 20260524T032814+0800 |
| 2 | ybdb | 1s3r | 3 | 1 | ✅ done + fetched | 20260524T074754+0800 |
| 3 | ybdb | 3s1r | 1 | 3 | ⏳ running | 20260524T202219+0800 |
| 4 | ybdb | 3s3r | 3 | 3 | ⏳ pending | — |
| 5 | tidb | 1s1r | 1 | 1 | ⏳ pending | — |
| 6 | tidb | 1s3r | 3 | 1 | ⏳ pending | — |
| 7 | tidb | 3s1r | 1 | 3 | ⏳ pending | — |
| 8 | tidb | 3s3r | 3 | 3 | ⏳ pending | — |
| 9 | crdb | 1s1r | 1 | 1 | ⏳ pending | — |
| 10 | crdb | 1s3r | 3 | 1 | ⏳ pending | — |
| 11 | crdb | 3s1r | 1 | 3 | ⏳ pending | — |
| 12 | crdb | 3s3r | 3 | 3 | ⏳ pending | — |

執行順序（已議定）：**ybdb 4 cells → tidb 4 cells → crdb 4 cells**，每 cell ~3.5h，總剩餘 ~31.5h（9 cells）。

---

## 通用執行命令（所有 12 cells 同模板）

```bash
cd /Users/wn.lin/vscode-git/dba_career/poc
TS=$(date '+%Y%m%dT%H%M%S%z')
make vm3-<db>-<sub>-rc EXECUTE=1 TPCC_TS=$TS
# <db>  = ybdb | tidb | crdb
# <sub> = 1s1r | 1s3r | 3s1r | 3s3r
```
make 自動：destroy → bootstrap → deploy(<db>-<sub>) → dryrun gate → 若 gate pass 用 ssh 把 launch-vm1-suite.sh detach 到 .31。

## 監看與 fetch（所有 cells 同模板）
- runlock：`ssh root@172.24.40.31 ls /tmp/poc-tpcc/runlocks/<db>-vm-3node-<sub>-rc.lock`
- suite log：`ssh root@172.24.40.31 'tail -50 /tmp/poc-tpcc/logs/<db>-vm-3node-<sub>-rc-*.log'`
- artifact：`ssh root@172.24.40.31 ls /tmp/poc-tpcc/artifacts/`
- fetch：`make fetch-vm3-<db>-<sub>-rc TPCC_TS=<TS>`

## Mac 不可當工作終端
- detach 已 built-in（launch-vm1-suite.sh on .31）
- Mac 可隨時關螢幕、隨時 status check；不可直接跑 prepare/run（會被 SIGHUP）
- 用 Monitor tool persistent=true 監看 lock 消失 / fatal grep

---

## DB 特化注意事項

### YBDB（cells 1–4）
- 已 patch 完成 commits：`d654824` / `68189bc` / `29b5fc5`（fix master_addrs race + RF-aware gate + drop ineffective stabilize）
- RF-aware dry-run gate（tests/common/dry-run-confirm.sh）：
  - RF=1 cell：master raft = 1（只 .32 LEADER），全 tservers ALIVE
  - RF=3 cell：master raft = 3（.32 .33 .34 全 ALIVE）
  - 每 tserver cmdline 至少含 1 個 raft master endpoint
- ansible/playbooks/yugabyte-vm3.yml 含 `serial: 1` on Join workers
- prepare.sh 對 ybdb-vm3 一律 pre-create 9 tables + sed substitute SPLIT INTO $EXPECTED_SHARDS TABLETS
- **埋點**：cell 4（3s3r）首次曾 LookupByIdRpc/kResponseSent timeout；workload 階段仍可能踩到（27 tablets × RF=3 = 81 replicas heavy write load）。若再次踩到 → 看 yb-master.WARNING / tablet leader rebalance trace

### TiDB（cells 5–8）
- deploy target：`deploy-vm3-tidb-{1s1r,1s3r,3s1r,3s3r}`（Makefile L439–442）
- shard SPLIT：prepare.sh L124-132 — `SPLIT TABLE <T> INDEX \`PRIMARY\` BETWEEN (lo) AND (hi) REGIONS 3`（9 tables；只在 3s*r 觸發）
- 連線：port=4000，user=root，db=tpcc，TIDB_CONN_RC 預設 read-committed
- vm-1node TiDB 已通過 baseline；vm-3node 同 deploy 路徑，**未踩過 cluster 設定 bug**
- 規則：prepare 完整 128W 之後再 SPLIT（PoC-DESIGN §7.5.1）

### CRDB（cells 9–12）
- deploy target：`deploy-vm3-crdb-{1s1r,1s3r,3s1r,3s3r}`（Makefile L445–448）
- shard SPLIT：prepare.sh L137-145 — `ALTER TABLE <T> SPLIT AT VALUES (...)`（9 tables；只在 3s*r 觸發）
- 連線：port=26257，user=root，db=tpcc
- vm-1node CRDB 已通過 baseline；vm-3node 同 deploy 路徑，**未踩過 cluster 設定 bug**
- 規則：prepare 完整 128W 之後再 SPLIT（PoC-DESIGN §7.5.2）

---

## 共用 hard gate（PoC-DESIGN §7.5.4）
- prepare.sh 最後一段：9-table shard 數實測比對 EXPECTED_SHARDS（1 或 3），不符即 fail-closed
- gate 通過才會進 go-tpc prepare 載 128W；否則 abort 整個 suite

## 4 sub_topology 結構（同樣套在 3 DB）
- 1s1r: RF=1, shards=1
- 1s3r: RF=3, shards=1
- 3s1r: RF=1, shards=3
- 3s3r: RF=3, shards=3

## go-tpc 參數（所有 cells 共用）
- WAREHOUSES=128，THREADS_LIST='16 32 64 128'，ROUNDS=5
- WARMUP_SEC=1200（20 min），RUN_SEC=300（5 min/round），ROUND_SLEEP_SEC=60
- 每 cell 4 thread-count × 5 round = 20 round；每 round 含 mpstat/iostat/sar/vmstat

## expected-node-count 警語
- gate 顯示 actual=4（含 .31 inventory）但不 fail-close；cosmetic-only。所有 cells 都會看到，可忽略。

---

## 下一步順序（從 cell 3 之後）
1. 等 cell 3 done → `make fetch-vm3-ybdb-3s1r-rc TPCC_TS=20260524T202219+0800`
2. dispatch cell 4：`make vm3-ybdb-3s3r-rc EXECUTE=1 TPCC_TS=$(date '+%Y%m%dT%H%M%S%z')`
3. 等 cell 4 done → fetch → 寫 ybdb 4 cells 彙整 record
4. dispatch cell 5 (tidb 1s1r) → 依序到 cell 12
5. 全 12 cells 完 → 寫 vm-3node S-BASE 全表彙整 record

---

## Cell 1 已知 baseline（RF=1，1-shard，128 wh，僅 ybdb）

| threads | tpmC mean | NO_p99 ms | DB CPU idle% |
|---------|----------:|----------:|-------------:|
| 16 | 11,491 | 88 | 22 |
| 32 | **13,702** | 168 | 9（sweet spot） |
| 64 | 13,200 | 419 | 6 |
| 128 | 13,725 | 738 | 4 |

代表點：t=32 mean tpmC=13,702 / NO_p99=168ms（throughput-latency 平衡）。
其他 11 cells baseline 待完成後彙整。

## auto-memory
/Users/wn.lin/.claude/projects/-Users-wn-lin-vscode-git-dba-career/memory/ 已記：
- 密碼/secret 不得出現
