# TiDB Intro for DBA #5-4

## 如何測試 RTO / RPO 數據

### Scenario
- **RTO（Recovery Time Objective）**
  - SQL 層：Tiproxy 重新路由 + 連線重建需 < 30 秒
  - TiKV 層：Raft leader 轉移 + Region 補足需 < 90 秒
  - Re-Sharding：調度過程不得中斷 SQL 服務（RTO = 0）
- **RPO（Recovery Point Objective）**
  - 交易寫入以 Raft 多副本為前提 → 期望 0 秒
  - TiKV Re-Sharding 調度期間允許 < 5 秒追平時間，超過需通報
- **SQL Layer 不可用**：模擬 2/6 TiDB server 故障，觀察 Tiproxy 監控、連線重試、Session 粘滯行為
- **TiKV Layer 不可用**：下架單一或多個 store，觀察 Region leader 補位、txn retry、TiKV GC
- **TiKV Layer Re-Sharding**：Scale-out 再 scale-in，強迫 Region re-balance，觀察 PD 調度併發量

### 測試矩陣
| Scenario | 注入工具 | 基準流量 | 觀測指標 | RTO Gate | RPO Gate |
| --- | --- | --- | --- | --- | --- |
| SQL 層故障 | `tiup cluster stop ... tidb`、Tiproxy admin `drain` | `tmp/benchmark_#2/conn_bench.sh` mysqlslap 10~500 threads | Tiproxy upstream healthy、`tidb_qps`、App 成功率 | < 30s | 0 |
| TiKV store 故障 | `chaosd network drop` / `tiup cluster stop ... tikv` | 同上並加 `sysbench oltp_write_only` | `kv_region_status`、`resolve_lock_duration`、App latency | < 90s | 0 |
| TiKV Re-Sharding | `tiup cluster scale-out/in`、`pd-ctl store limit` | Heartbeat 100 tps + 10k read qps | `scheduler_pending_bytes`、`raftstore_apply_duration` | 0 | < 5s |

### 驗證流程
1. **基準流量**：在 Jump Host 執行 `conn_bench.sh`，保留 `bench_result.csv` 作基線。  
2. **Heartbeat 表**：建立 `tidb_ops.heartbeat(ts TIMESTAMP)`，以 `INSERT ... VALUES (NOW(6)) ON DUPLICATE KEY UPDATE` 每秒寫入；RPO = `NOW - MAX(ts)`。  
3. **事件時間軸**：注入前後記錄 `date -Ins`；App 端第一筆成功請求時間 - 失敗時間 = RTO。  
4. **觀測面板**：Grafana（TiDB / PD / TiKV）、`tiup ctl:v8.5.3 pd store -d`、Tiproxy `admin metrics upstream`。  
5. **復原與回報**：收集 `tidb.log`、`tikv_stderr.log`、App log 中 `error`, `panic`, `unavailable` 關鍵字，形成 incident timeline。

### SQL Layer 不可用
**Failure Model**
- 以 `tiup cluster stop tidb-demo -N 10.160.152.21:4000,10.160.152.22:4000` 模擬雙實體同時離線。
- 可改用 Tiproxy `admin api /api/v1/upstreams/{uid}/drain` 逐台下線，觀察連線耗盡時間。

**量測步驟**
1. 維持 100、250、500 threads 連續查詢 (`SELECT 1`)。  
2. `Tfailure` 由停機前 `date -Ins` 記錄。  
3. 觀察 Tiproxy log：`backend unhealthy` → `backend healthy` 的時間差即為中介層感知時間（預估 ~5s）。  
4. App log 第一筆成功重連時間 = `Trecover`；RTO = `Trecover - Tfailure`。  
5. Heartbeat 表 `NOW(6) - MAX(ts)` 應維持 0；若出現延遲，檢查 `SHOW PROCESSLIST` 中阻塞事務。

**結果要點**
- Tiproxy 預設健康檢查 2s，允許 2 次失敗 → SQL 層 RTO 目標 6~10s，含 client retry 不應超過 30s。  
- 事件僅影響 SQL 層；Raft 未受影響，RPO 強制為 0。  
- 若 RTO > 30s，檢查 App retry/backoff 與 Tiproxy `backendEvictionDuration`。

### TiKV Layer 不可用
**Failure Model**
- `chaosd network drop --interface eth0 --direction to` 讓 store 失聯，或 `tiup cluster stop ... tikv` 直接下線。  
- 優先測跨區節點（例：`172.24.40.20:20160`）以驗證專線品質。

**量測步驟**
1. 產生混合 workload：`sysbench oltp_write_only` + `conn_bench.sh`。  
2. `pd-ctl store <id>` 記錄 `last_heartbeat_ts` 做為失聯起點。  
3. 觀察 `grafana -> kv -> Region health`：`pending peer`、`empty region count`。  
4. `pd-ctl operator show` 確認 `balance-region` 生效；必要時 `pd-ctl config set max-pending-peer-count 64`。  
5. RTO：App 層成功請求恢復時間 - 失敗時間，目標 ≤ 90s。  
6. RPO：Heartbeat 表差值應為 0；若非 0，dump `txn commit ts` 驗證是否超出 `raftstore.sync-log` 允許範圍。

**結果要點**
- PD leader 應在健康區，必要時 `pd-ctl member leader transfer`。  
- 大量 `resolve-lock` 代表長事務，可 `KILL TIDB <conn>`。  
- store 無法自動 offline 時執行 `tiup cluster scale-in --force`，並記錄 region 遷移起訖時間。

### TiKV Layer Re-Sharding
**Failure Model**
- `tiup cluster scale-out tidb-demo -N <new hosts>` 新增 TiKV，再以 `tiup cluster scale-in` 下線舊節點，迫使 Region shuffle。  
- 配合 `pd-ctl store limit` / `store remove-limit` 控制調度速度。

**量測步驟**
1. re-shard 前後維持固定負載與 Heartbeat 寫入。  
2. 監看 `pd-ctl hot region`、`pd-ctl region scatter` 確認分佈。  
3. RTO：操作須在線，若 App timeout 需記錄 `raftstore_apply_duration`.  
4. RPO：Heartbeat 與 `cdc cli changefeed query` 的 `checkpoint-ts` 差值需 < 5s。  
5. 以 `tiup cluster display` / `pd-ctl store` 截圖記錄均衡時間。

**結果要點**
- 調度過快會讓 `scheduler_pending_bytes` 飆高；以 `pd-ctl store limit tikv 10` 限速。  
- 需要人工干預時用 `pd-ctl operator add transfer-region <region> <store>` 指定目標。

## 環境交代
```
[root@l-k8s-labroom-1 ~]# make display
date ; tiup cluster display tidb-demo
Wed Nov 19 11:07:35 CST 2025
Cluster type:       tidb
Cluster name:       tidb-demo
Cluster version:    v8.5.3
Deploy user:        root
SSH type:           builtin
Dashboard URL:      http://10.160.152.21:2379/dashboard
Dashboard URLs:     http://10.160.152.21:2379/dashboard
Grafana URL:        http://172.24.40.20:3000
ID                   Role        Host           Ports                 OS/Arch       Status   Data Dir                         Deploy Dir
--                   ----        ----           -----                 -------       ------   --------                         ----------
172.24.40.20:3000    grafana     172.24.40.20   3000                  linux/x86_64  Up       -                                /data/tidb-deploy/grafana-3000
10.160.152.21:2379   pd          10.160.152.21  2379/2380             linux/x86_64  Up|L|UI  /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
10.160.152.22:2379   pd          10.160.152.22  2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
10.160.152.23:2379   pd          10.160.152.23  2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.17:2379    pd          172.24.40.17   2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.18:2379    pd          172.24.40.18   2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.19:2379    pd          172.24.40.19   2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.20:9090    prometheus  172.24.40.20   9090/9115/9100/12020  linux/x86_64  Up       /data/tidb-data/prometheus-9090  /data/tidb-deploy/prometheus-9090
10.160.152.21:4000   tidb        10.160.152.21  4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
10.160.152.22:4000   tidb        10.160.152.22  4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
10.160.152.23:4000   tidb        10.160.152.23  4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
172.24.40.17:4000    tidb        172.24.40.17   4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
172.24.40.18:4000    tidb        172.24.40.18   4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
172.24.40.19:4000    tidb        172.24.40.19   4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
10.160.152.24:20160  tikv        10.160.152.24  20160/20180           linux/x86_64  Up       /data/tidb-data/tikv-20160       /data/tidb-deploy/tikv-20160
172.24.40.20:20160   tikv        172.24.40.20   20160/20180           linux/x86_64  Up       /data/tidb-data/tikv-20160       /data/tidb-deploy/tikv-20160
10.160.152.21:6000   tiproxy     10.160.152.21  6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
10.160.152.22:6000   tiproxy     10.160.152.22  6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
10.160.152.23:6000   tiproxy     10.160.152.23  6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
172.24.40.17:6000    tiproxy     172.24.40.17   6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
172.24.40.18:6000    tiproxy     172.24.40.18   6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
172.24.40.19:6000    tiproxy     172.24.40.19   6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
Total nodes: 22
```

- **視覺化**：Grafana + Prometheus；必要時用 `tiup diag collect` 製作期間報告。  
- **流量產生**：`tmp/benchmark_#2/conn_bench.sh`（RPS / CPU）、`sysbench`（OLTP）。  
- **故障注入**：`tiup cluster`、Tiproxy Admin API、`chaosd`。  
- **資料驗證**：Heartbeat 表、TiCDC `checkpoint-ts`、App 指標（成功率、p99 latency）。
