# YugabyteDB 3s3r leader balance — first-hand verification (D10)

**Scope**：YugabyteDB v2025.x（與 `yuga-tc1` baseline 同 binary）；vm-3node 拓樸下 RF=3
**Date**：2026-05-31（驗證執行夜間，分析寫成 2026-06-01 清晨）
**TS**：`20260531T233859+0800`
**Goal**：把 audit-watch-prompt D10 中 YugabyteDB 段「default `enable_load_balancing=true` → master 自動均衡，不踩同坑」從 doc-level 升級為 first-hand artifact 證據。
**Scope 對照**：TiDB vm-3node-3s3r-rc 同 cluster 拓樸，量測 leader 集中 27/0/0（baseline）→ 4/15/10（D10 修法後）。

## Method（Option B — minimum dynamic check）

1. Destroy 殘留 vm-3node cluster → 全新 deploy ybdb 3s3r RF=3（`yugabyted` cluster；3 yb-master + 3 yb-tserver，跨 .32/.33/.34）。
2. Snapshot 1 — pre-CREATE：`yb-admin get_load_balancer_state` 看 cluster default。
3. `CREATE DATABASE tpcc`；pre-create 9 TPC-C tables with `SPLIT INTO 3 TABLETS`（對齊 production 3s*r 拓樸的 tablet 數）；`go-tpc tpcc prepare --warehouses=1` 載入最小資料以觸發 tablet 物化。
4. Snapshot 2 — post-CREATE：再次 `get_load_balancer_state`；`yb-admin list_tablets ysql.tpcc <tbl>` × 9 表，逐 tablet 收 Leader-IP。

> 不跑 TPCC run（不需要 throughput 數字）；目的只是確認 ybdb 把 leader 均勻配給 3 tservers。

## 結果

### 1. Cluster identity（baseline）

```
yb-admin list_all_masters
  2f0321ec...  172.24.40.32:7100  ALIVE  LEADER
  e00e7269...  172.24.40.33:7100  ALIVE  FOLLOWER
  09f29135...  172.24.40.34:7100  ALIVE  FOLLOWER

yb-admin list_all_tablet_servers
  3de5490b...  172.24.40.33:9100  ALIVE
  4575e9bb...  172.24.40.34:9100  ALIVE
  5e439a0c...  172.24.40.32:9100  ALIVE
```

### 2. Load balancer state — ENABLED at every master

| Master | RPC | Role | Load Balancer State |
|---|---|---|---|
| 2f0321ec... | 172.24.40.32:7100 | LEADER | **ENABLED** |
| e00e7269... | 172.24.40.33:7100 | FOLLOWER | **ENABLED** |
| 09f29135... | 172.24.40.34:7100 | FOLLOWER | **ENABLED** |

> 直接證實 `enable_load_balancing` 在 master 啟動時為 `true`、且 master leader 持續執行 load balancer 線程；playbook `yb_master_flags` 只覆寫 `enable_automatic_tablet_splitting=false`，未碰 `enable_load_balancing` → 走預設 true。

### 3. Tablet leader 分佈 — 9 / 9 / 9（perfect balance）

9 TPCC tables × `SPLIT INTO 3 TABLETS` = **27 tablet leaders**，每張表三個 tablet 的 leader 各落在一個 tserver。

| Table | tablets | leader on .32 | leader on .33 | leader on .34 |
|---|---|---|---|---|
| warehouse  | 3 | 1 | 1 | 1 |
| district   | 3 | 1 | 1 | 1 |
| customer   | 3 | 1 | 1 | 1 |
| new_order  | 3 | 1 | 1 | 1 |
| orders     | 3 | 1 | 1 | 1 |
| order_line | 3 | 1 | 1 | 1 |
| stock      | 3 | 1 | 1 | 1 |
| item       | 3 | 1 | 1 | 1 |
| history    | 3 | 1 | 1 | 1 |
| **Total**  | **27** | **9** | **9** | **9** |

Ideal per tserver = 27/3 = 9；±20% 容差 = [7.2, 10.8]；**實際每 tserver 恰好 9**，零偏差。

### 4. 與 TiDB vm-3node-3s3r-rc 對照

| db / 拓樸 | RF=3 leaders（store / tserver count） | 偏差 vs 理想（27/3=9） |
|---|---|---|
| ybdb 3s3r（**本檔**，default） | **9 / 9 / 9** | 0% — perfect |
| TiDB 3s3r `pd-sched-l0r0`（baseline） | 27 / 0 / 0 | +200% / −100% / −100% |
| TiDB 3s3r `pd-sched-l4r4`（Fix #11 + D10） | 4 / 15 / 10 | −56% / +67% / +11% |

> ybdb 在 tablet 創建瞬間就完成均勻分配；TiDB 即使套用 `leader-schedule-limit=4` 仍需要時間收斂，本 PoC 5h 工作負載不足以讓 PD 把 leader 拉回 ±20% 內。

## 結論

| 項目 | 狀態 |
|---|---|
| audit-watch-prompt D10 YugabyteDB 段（doc-level → first-hand） | ✅ 可升級為 first-hand verified |
| 預設 `enable_load_balancing=true` | ✅ runtime 證實 ENABLED |
| 27 個 tablet leader 是否均衡 | ✅ 9/9/9 完美分佈，D10 hard gate PASS |
| 對外結論 | ybdb 在「tablet 創建瞬間」就把 leader 均勻配置，無需額外 cluster config |

## Caveat

1. **Idle 狀態**：本驗證僅在 `go-tpc prepare --warehouses=1` 完成後立即量測，未經 long-running workload。production 工作負載下若有 leader skew 形成（例如 hot key），ybdb 是否會 rebalance 留待後續 verification 補強。
2. **N=1**：只跑 1 次 deploy；對 reproducibility，建議在後續 ybdb 重跑 cell 4 (3s3r) 時 prepare 階段重複此驗證流程，落地為 audit gate（類似 TiDB `dry-run §1c actual-rf-peer-min/max` 模式）。
3. **未測 1s3r、1s1r、3s1r**：本檔只驗 3s3r；1s3r 是 1 SQL 入口 + RF=3，理論上 master 也會均衡 leader（因 ybdb 是對稱式：YSQL 與 tserver 同節點），但未量測。
4. **未測動態 fault**：未模擬 tserver 故障後的 leader failover；如要驗 D10 對「rebalance 過程」的承諾，需追加 chaos test。

## Reproducibility

| 項 | 值 |
|---|---|
| TS | `20260531T233859+0800` |
| 部署 host | 172.24.40.31（poc batch controller） |
| Cluster | 172.24.40.32 (primary) + .33 / .34 (workers) |
| Ansible | `playbooks/yugabyte-vm3.yml` `-e yb_sub_topology=3s3r` |
| Schema 來源 | `tests/common/lib/ybdb-tpcc-schema-1tablet.sql`（sed 換 SPLIT INTO 3 TABLETS） |
| 資料 | `go-tpc tpcc prepare --warehouses=1 --conn-params sslmode=disable --no-check` |
| 驗證指令 | `yb-admin --master_addresses=... get_load_balancer_state` + `yb-admin list_tablets ysql.tpcc <tbl>` × 9 |
| Artifacts | `poc/results/dispatch-records/2026-05-31-ybdb-leader-balance-check/` |

Artifacts manifest：

| 檔案 | 內容 |
|---|---|
| `run.log` | 主流程 log（含 ansible deploy + manual fallback） |
| `01-list_all_masters.txt` | 3 master 列表（leader 在 .32） |
| `01-list_all_tservers.txt` | 3 tserver 列表（UUID → IP/port） |
| `01-load-balancer-state-pre.txt` | snapshot 1：build cluster 後立即量；ENABLED × 3 |
| `02-createdb.log` | `DROP/CREATE DATABASE tpcc` log |
| `02b-precreate-3tablets.log` | 9 表 `SPLIT INTO 3 TABLETS` CREATE TABLE 結果 |
| `03-go-tpc-prepare.log` | go-tpc W=1 載入 log |
| `04-load-balancer-state-post.txt` | snapshot 2：CREATE 完仍 ENABLED × 3 |
| `05-tablet-leaders-raw.tsv` | 27 個 tablet 的 Leader-IP / Leader-UUID 完整 dump（per table） |

## 相關 commit / 文件

- audit-watch-prompt D10：[`results/audit-watch-prompt.md`](../audit-watch-prompt.md)
- TiDB schedule-limit 0→4 對照：[`2026-05-31-tidb-schedule-limit-0-vs-4.md`](./2026-05-31-tidb-schedule-limit-0-vs-4.md)
- ybdb 過往 3s3r tpmC 結果：[`yuga-tc1/S-BASE/vm-3node-3s3r-rc/`](../yuga-tc1/S-BASE/vm-3node-3s3r-rc/)
