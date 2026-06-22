# Freeze / Unfreeze Scripts

在 timed benchmark rounds 前後凍結各 DB 的 rebalancer / scheduler，確保壓測期間 cluster 不因自動搬遷影響延遲穩定性。

---

## 目錄

```
freeze-tidb.sh      # 將 PD 5 個 schedule limit 設為 0
unfreeze-tidb.sh    # 從 dump 還原原始 limit 值
freeze-crdb.sh      # 關閉 CRDB load-based lease rebalancing + range split
unfreeze-crdb.sh    # 從 dump 還原原始 cluster settings
freeze-ybdb.sh      # 關閉 YBDB load balancer
unfreeze-ybdb.sh    # 重新啟用 YBDB load balancer
```

---

## 環境變數

| Script | 必填 env | 說明 |
|---|---|---|
| freeze/unfreeze-tidb | `PD_URL` | e.g. `http://10.x.x.x:2379` |
| freeze/unfreeze-tidb | `DUMP_DIR` | dump 存放目錄（自動建立） |
| freeze/unfreeze-crdb | `CRDB_HOST` | CockroachDB SQL 介面 IP |
| freeze/unfreeze-crdb | `DUMP_DIR` | dump 存放目錄 |
| freeze/unfreeze-ybdb | `YB_MASTER_ADDR` | e.g. `10.x.x.x:7100` |
| freeze/unfreeze-ybdb | `IDC_NODES_HEAD` | ssh jump node IP（已配 key-based auth） |
| freeze-ybdb | `DUMP_DIR` | universe config dump 目錄 |

---

## 用法範例

```bash
export DUMP_DIR=/tmp/freeze-$(date +%Y%m%d-%H%M)
mkdir -p "$DUMP_DIR"

# === Freeze ===
PD_URL=http://10.1.1.10:2379 DUMP_DIR=$DUMP_DIR ./freeze-tidb.sh
CRDB_HOST=10.1.1.20        DUMP_DIR=$DUMP_DIR ./freeze-crdb.sh
YB_MASTER_ADDR=10.1.1.30:7100 IDC_NODES_HEAD=10.1.1.30 DUMP_DIR=$DUMP_DIR ./freeze-ybdb.sh

# === 跑 benchmark ===
make phase-bench-...

# === Unfreeze ===
PD_URL=http://10.1.1.10:2379 DUMP_DIR=$DUMP_DIR ./unfreeze-tidb.sh
CRDB_HOST=10.1.1.20        DUMP_DIR=$DUMP_DIR ./unfreeze-crdb.sh
YB_MASTER_ADDR=10.1.1.30:7100 IDC_NODES_HEAD=10.1.1.30 ./unfreeze-ybdb.sh
```

---

## 還原邏輯

| DB | 方式 |
|---|---|
| TiDB | `pd-config-before.json` 用 `jq` 讀出原值，逐 key `config set` 還原 |
| CRDB | `crdb-*-before.txt` 用 `awk NR==2` 讀值，`SET CLUSTER SETTING` 還原（含原本就是 false 的情況）|
| YBDB | `set_load_balancer_enabled 1`（boolean 預設 1，不需 dump 還原） |

---

## Freeze 後絕對不可做的事

1. **DDL 操作**（ALTER TABLE / CREATE INDEX / DROP ...）：schedule limit 為 0 時 region rebalance 被禁，DDL 依賴 region 搬遷可能永久 pending
2. **增減節點**（scale-out / scale-in / replace）：新 peer replication 需要 replica-schedule-limit > 0，freeze 期間加節點會導致 peer 無法同步
3. **重 deploy / rolling restart**：節點重啟後 leader election 需要 scheduler 協助，freeze 狀態下可能造成 quorum 問題
4. **手動觸發 region merge / split**：bypass limit 但仍會打亂 benchmark 基準

---

## Freeze 失敗時的緊急 Unfreeze

### TiDB（手動）

```bash
# 若 script 中斷，直接用 curl 或 tiup ctl 還原（以預設值為保底）
tiup ctl:v8.5.2 pd -u $PD_URL config set schedule.leader-schedule-limit 4
tiup ctl:v8.5.2 pd -u $PD_URL config set schedule.region-schedule-limit 2048
tiup ctl:v8.5.2 pd -u $PD_URL config set schedule.replica-schedule-limit 64
tiup ctl:v8.5.2 pd -u $PD_URL config set schedule.hot-region-schedule-limit 4
tiup ctl:v8.5.2 pd -u $PD_URL config set schedule.merge-schedule-limit 8
# 若有 dump，改執行 unfreeze-tidb.sh 還原原值（優先）
```

### CRDB（手動）

```bash
cockroach sql --insecure --host=$CRDB_HOST \
  -e "SET CLUSTER SETTING kv.allocator.load_based_lease_rebalancing.enabled = true;"
cockroach sql --insecure --host=$CRDB_HOST \
  -e "SET CLUSTER SETTING kv.range_split.by_load_enabled = true;"
```

### YBDB（手動）

```bash
ssh -o ConnectTimeout=5 -o BatchMode=yes root@$IDC_NODES_HEAD \
  "/opt/yugabyte/bin/yb-admin --master_addresses=$YB_MASTER_ADDR set_load_balancer_enabled 1"
```

---

## 注意事項

- **idempotent**：所有 script 重跑不會崩潰（dump 覆蓋舊檔、set 值冪等）
- **ssh 認證**：YBDB script 使用 `BatchMode=yes`，須預先配好 key-based auth（`~/.ssh/config` 或 `ssh-copy-id`）
- **DUMP_DIR** 建議用帶時間戳的路徑（`/tmp/freeze-20260622-1400`），避免不同輪次 dump 互蓋
