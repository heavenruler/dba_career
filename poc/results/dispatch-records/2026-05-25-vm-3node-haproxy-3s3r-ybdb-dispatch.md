# YugabyteDB vm-3node-haproxy-3s3r-rc dispatch 記錄

**日期**：2026-05-25  
**正式採用 TPCC_TS**：`20260525T193740+0800`  
**狀態**：✅ suite done + fetched（`20260525T155542+0800` 首次 dispatch cold-reset failure，不採用）  
**Goal hook**：完成 YugabyteDB vm-3node-3s3r-rc + haproxy 的 dry-run, prepare, run, fetch 程序

---

## 拓樸

```
client (.31) ──→ HAProxy (.20:5433) ──roundrobin──→ .32:5433 / .33:5433 / .34:5433
                                                         RF=3, 3 shards/table
                                                         9 tables × 3 tablets × 3 RF = 81 replicas
```

對標 vm-3node-3s3r-rc direct（TS=20260525T031918+0800）— 同 cluster setup，差異只在 **連線層 HAProxy roundrobin vs 直連 .32**。

## 基礎設施部署

### HAProxy on 172.24.47.20（l-monitor-labroom-1）

直接 SSH 部署（ansible 因 .20 Python 3.6 不支援 `from __future__ import annotations`）：

```bash
ssh root@172.24.47.20 'dnf install -y haproxy'
ssh root@172.24.47.20 'cat > /etc/haproxy/haproxy.cfg <<EOF
global
  daemon
  stats socket /var/lib/haproxy/stats mode 660 level admin
  stats timeout 30s

defaults
  mode tcp
  timeout connect 10s
  timeout client  1h
  timeout server  1h
  option clitcpka
  option srvtcpka

frontend ybdb
  bind *:5433
  default_backend db_nodes

backend db_nodes
  balance roundrobin
  server node1 172.24.40.32:5433 check inter 2s
  server node2 172.24.40.33:5433 check inter 2s
  server node3 172.24.40.34:5433 check inter 2s
EOF
systemctl enable haproxy --now'
```

### Timeout 設計

| 參數 | 值 | 為什麼 |
|------|---:|--------|
| `timeout connect` | 10s | TCP 握手；本 LAN <1s，10s 含緩衝 |
| `timeout client` | 1h | TPC-C 連線長存活；30s 預設會在 prepare 階段批次 INSERT 期間誤切 |
| `timeout server` | 1h | 同上 |
| `option clitcpka/srvtcpka` | on | TCP keepalive 防 NAT idle 切連線 |

### 連通驗證

`.31 → .20:5433 → .32/.33/.34:5433` 6 次 round-robin probe：

```
172.24.40.32
172.24.40.33
172.24.40.34
172.24.40.32
172.24.40.33
172.24.40.34
```

完美輪轉 ✓。

## Scripts 變更（commit 紀錄）

**Commit `feat(vm-3node-haproxy): add haproxy-3s3r sub-topology support across 5 phase scripts`** — 5 個 phase scripts 加 `case "$TOPO" in *haproxy-*) CLUSTER_HOST=.32 ;; *) CLUSTER_HOST=$DB_HOST ;; esac` 模式：

| 檔案 | 影響 |
|------|------|
| `dry-run-confirm.sh` | SUB whitelist 加 `haproxy-3s3r`；EXPECTED_RF=3；`remote()` 改用 CLUSTER_HOST |
| `gate.sh` | OS preflight ssh 改用 CLUSTER_HOST |
| `prepare.sh` | TOPO 加 `vm-3node-haproxy-3s3r=EXPECTED_SHARDS=3`；shard hard gate yb-admin ssh 改用 YB_ADMIN_HOST |
| `collect.sh` | db-host env snapshot + DB log tail ssh 改用 CLUSTER_HOST |
| `db-config-dump.sh` | `remote()` 改用 CLUSTER_HOST |

**Commit `feat(vm-3node-haproxy): add status-vm3-<db>-haproxy-3s3r-rc target`** — Makefile 加 3 個 status target（ybdb/tidb/crdb）。dispatch / dry-run / deploy 不走 Makefile（手動 SSH）。

## Dispatch 手動命令（記錄供重現）

```bash
# 0. cluster fresh deploy（haproxy 留在 .20 不動）
cd /Users/wn.lin/vscode-git/dba_career/poc
make destroy-vm3-all
make bootstrap-tpcc-client
make deploy-vm3-ybdb-3s3r

# 1. sync patched scripts
rsync -q tests/common/dry-run-confirm.sh tests/common/gate.sh \
        tests/common/prepare.sh tests/common/collect.sh \
        tests/common/db-config-dump.sh root@172.24.40.31:/tmp/poc-tpcc/scripts/

# 2. dry-run
TS=$(date '+%Y%m%dT%H%M%S%z')
ssh root@172.24.40.31 "TPCC_BASE=/tmp/poc-tpcc TPCC_ARTIFACTS=/tmp/poc-tpcc/artifacts \
  WAREHOUSES=128 THREADS_LIST='16 32 64 128' ROUNDS=5 WARMUP_SEC=1200 \
  RUN_SEC=300 ROUND_SLEEP_SEC=60 YBDB_PORT=5433 YBDB_USER=yugabyte YBDB_DB=tpcc \
  bash /tmp/poc-tpcc/scripts/dry-run-confirm.sh \
    --db ybdb --sub-topology haproxy-3s3r --iso rc \
    --db-host 172.24.47.20 --ts $TS"

# 3. launch suite detached（dry-run pass 後）
ssh root@172.24.40.31 "TPCC_BASE=/tmp/poc-tpcc TPCC_ARTIFACTS=/tmp/poc-tpcc/artifacts \
  WAREHOUSES=128 THREADS_LIST='16 32 64 128' ROUNDS=5 WARMUP_SEC=1200 \
  RUN_SEC=300 ROUND_SLEEP_SEC=60 YBDB_PORT=5433 YBDB_USER=yugabyte YBDB_DB=tpcc \
  bash /tmp/poc-tpcc/scripts/launch-vm1-suite.sh \
    --db ybdb --iso rc --topology vm-3node-haproxy-3s3r \
    --db-host 172.24.47.20 --ts $TS"

# 4. status check
make status-vm3-ybdb-haproxy-3s3r-rc

# 5. fetch（suite done 後）
# 沒 Makefile fetch target，手動 rsync：
rsync -av root@172.24.40.31:/tmp/poc-tpcc/artifacts/ybdb-vm-3node-haproxy-3s3r-rc-${TS}/ \
       results/yuga-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-${TS}/
```

## Dry-run 結果（pre-suite）

```
[15:55:17] INFO  dry-run-confirm root: /tmp/poc-tpcc/artifacts/ybdb-vm-3node-haproxy-3s3r-rc-20260525T155542+0800
  (sub=haproxy-3s3r rf=3 iso=rc db-host=172.24.47.20 cluster-host=172.24.40.32)
[15:55:18] INFO  dry-run-confirm PASSED  (sub=haproxy-3s3r rf=3 iso=read committed)
```

預期：
- ybdb-cluster-healthy = true（3 master raft ALIVE + 3 tserver ALIVE）
- ybdb-master-addrs-consistent = true
- shard hard gate（prepare 階段執行）= 9 表 × 3 tablets

## 完成狀態（suite done 後）

- 首次 dispatch：`20260525T155542+0800`，run phase cold-reset failure，不採用。
- 正式採用：`20260525T193740+0800`，suite done + fetched。
- 來源目錄：[`../yuga-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/`](../yuga-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/)
- 4 thread × 5 round = 20 個 `go-tpc-stdout.txt` 已 fetch。
- t=128 代表點：15,632 tpmC / NEW_ORDER p99 705ms。
- 對 direct `vm-3node-3s3r-rc`（TS=`20260525T031918+0800`）：+79.1% tpmC / -36.7% NEW_ORDER p99。
- DB-host metrics caveat：`mpstat-db.txt` / `iostat-1s-db.txt` 等檔案存在，但內容為 `command not found`，不可作 DB-host 飽和判讀。
- summary.json 已於 2026-05-26 由 [`tests/common/summary-from-stdout.py`](../../tests/common/summary-from-stdout.py) 從 raw stdout 補產。
- 詳細分析：[2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md](./2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md)
