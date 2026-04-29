# YugabyteDB TPC-C Pipeline 作業紀錄

**日期**: 2026-04-28 / 2026-04-29  
**拓撲**: yuga-tc1（3 VM，RF=3，fault_tolerance=zone）  
**節點**: poc-1 (.32 bootstrap), poc-2 (.33 join), poc-3 (.34 join)  
**Universe UUID**: 82163233  
**Port**: YSQL 5433，HAProxy 15433

---

## 除錯紀錄

| # | 問題 | 根因 | 解法 |
|---|------|------|------|
| 1 | HAProxy port 15433 被佔用 | yugabyted-ui 預設綁 15433 | `yugabyted start --ui=false` |
| 2 | `psql: command not found` | 未安裝 PostgreSQL client | `dnf install -y postgresql` |
| 3 | `java: command not found` | 未安裝 JDK | `dnf install -y java-11-openjdk-headless` |
| 4 | `ClassNotFoundException ExecJDBC` | BenchmarkSQL 5.0 出廠為 source，需先編譯 | `ant -q -f build.xml` 加入 `_ensure_bsl()` |
| 5 | `NullPointerException` (password) | `YUGA_PASS=""` 時 props file 缺 `password=` 行 | 固定寫 `password=${YUGA_PASS}`（空值也寫） |
| 6 | `database benchmarksql does not exist` | CREATE DATABASE 判斷邏輯用 `grep -q 1` 誤中 header row | 改為 `\| grep -v "already exists" \|\| true` |
| 7 | .33 自成獨立叢集（不同 UUID） | destroy 未清 `/home/yugabyte/var/conf/yugabyted.conf`，舊 `current_masters` 殘留 | 全節點停止，刪 `/opt/yugabyte/data` + `/home/yugabyte/var/conf/`，重建 bootstrap → join |
| 8 | cleanup 卡住「database being accessed」 | Ctrl+C 未殺 Java worker process | `pkill -9 -f java`；`cmd_cleanup` 加入 `pg_terminate_backend` |
| 9 | `kSnapshotTooOld` delta ~39s（bmsql_customer） | `yb_disable_transactional_writes=true` 繞過 Raft coordinator，移除 in-flight transaction MVCC 保護；RocksDB compaction 清除 read point | 移除 `yb_disable_transactional_writes`；JDBC URL 加 `reWriteBatchedInserts=true` 縮短 transaction 持續時間 |
| 10 | `kSnapshotTooOld` delta 220–344s，所有 worker 同一 timestamp | CPU 飽和（load 6.3/4vCPU）→ Raft heartbeat timeout → 4 tablet 同時 leader re-election → HLC 大幅跳進 → 所有 in-flight snapshot 失效 | `loadWorkers` 16→8；`timestamp_history_retention_interval_sec` 900→7200；改用 HAProxy 入口 |
| 11 | `loadWorkers` 改成參數後仍顯示 16 | `_write_props` heredoc 內硬寫 `loadWorkers=16`，第 4 個參數未傳入 | 新增 `load_workers=${4:-8}` 參數，heredoc 改為 `loadWorkers=${load_workers}` |
| 12 | `multiple primary keys` / 資料重複載入 | 未 cleanup 就跑第二次 prepare，兩次 prepare 跑在同一 DB | 每次 prepare 前必須執行 cleanup，確認 DB 不存在後再 prepare |

### 叢集重建指令（問題 7 處理）

```bash
# 全節點執行（.32/.33/.34）
/opt/yugabyte/bin/yugabyted stop
sudo rm -rf /opt/yugabyte/data /home/yugabyte/var/conf

# .32 bootstrap
sudo -u yugabyte /opt/yugabyte/bin/yugabyted start \
  --advertise_address=<.32_IP> \
  --cloud_location=gcp.asia-east1.asia-east1-a \
  --fault_tolerance=zone --data_dir=/opt/yugabyte/data \
  --log_dir=/opt/yugabyte/logs --ui=false --daemon=true

# .33/.34 join
sudo -u yugabyte /opt/yugabyte/bin/yugabyted start \
  --advertise_address=<nodeIP> \
  --cloud_location=gcp.asia-east1.asia-east1-<zone> \
  --fault_tolerance=zone --join=<.32_IP> \
  --data_dir=/opt/yugabyte/data \
  --log_dir=/opt/yugabyte/logs --ui=false --daemon=true
```

---

## 效能加速措施（tpcc-prepare）

### 最終確認組態（2026-04-29）

| 措施 | 值 | 說明 |
|------|-----|------|
| `loadWorkers` | **8**（從 16 降回） | 4 vCPU 節點；16 workers 造成 CPU 飽和 → Raft election |
| `reWriteBatchedInserts=true` | JDBC URL | 縮短單筆 transaction 時間，避免 kSnapshotTooOld |
| `yb_disable_transactional_writes` | **不使用** | 繞過 Raft coordinator 會移除 MVCC 保護，反而引發 kSnapshotTooOld |
| `timestamp_history_retention_interval_sec` | **7200**（runtime set_flag） | 擴大 MVCC snapshot 保留窗口，容忍 leader re-election 後 HLC 跳進 |
| `ysql_num_shards_per_tserver` | **3** | 預設 1（3 節點 = 3 tablets/table）；改為 3（= 9 tablets/table），分散 loadWorkers 到不同 leader |
| RF during prepare | **1 → 3** | prepare 期間 RF=1 省略 Raft quorum；載入完成後改回 RF=3，remote bootstrap 自動複製 |

### RF=1 bulk load 策略（2026-04-29 新增）

```bash
YB_MASTERS=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100

# prepare 前：改 RF=1
sudo -u yugabyte /opt/yugabyte/bin/yb-admin \
  --master_addresses=${YB_MASTERS} \
  modify_placement_info 'poc.poc-region.idc:1' 1

# prepare 完成後：改回 RF=3，觸發 remote bootstrap
sudo -u yugabyte /opt/yugabyte/bin/yb-admin \
  --master_addresses=${YB_MASTERS} \
  modify_placement_info 'poc.poc-region.idc:3' 3

# 等待複製完成（100% 才能跑 benchmark）
watch -n 10 "sudo -u yugabyte /opt/yugabyte/bin/yb-admin \
  --master_addresses=${YB_MASTERS} get_load_move_completion"
```

**效益**：eliminate Raft 2/3 quorum 等待，寫入接近單機速度。  
**注意**：RF=1 期間節點掛掉資料遺失（POC 可接受）；remote bootstrap 期間不可跑 benchmark。

### 為什麼需要 `reWriteBatchedInserts=true`

BenchmarkSQL 預設使用 JDBC `addBatch()` / `executeBatch()`，PostgreSQL JDBC driver 會對每筆 row 發出獨立的 `INSERT INTO t VALUES (?)`，多筆合併為一個 transaction 但仍是多次 round-trip。

`reWriteBatchedInserts=true` 讓 driver 把同一批次改寫為：

```sql
INSERT INTO t VALUES (v1), (v2), ..., (vN)
```

**效果**：單一 round-trip 寫入更多資料 → 每個 transaction 持續時間大幅縮短。

**不加此參數的後果（實際觀察）**：載入 `bmsql_customer`（128 倉 × 10 district × 3000 customers = 3,840,000 rows）時，16 個 worker 並行開啟長時間 transaction。YugabyteDB 使用 HLC（Hybrid Logical Clock）管理 MVCC，當 transaction 持續時間超過 tablet 的 snapshot 保留窗口，HLC 會推進至新的最小讀取點，舊 snapshot 被清除，觸發：

```
ERROR: Snapshot too old. delta (usec): ~39,434,167
kSnapshotTooOld
```

加入 `reWriteBatchedInserts=true` 後每筆 transaction 在 snapshot 過期前完成，問題消除。

---

## TiDB vs YugabyteDB 資料匯入效能差異：根本原因

### 現象

YugabyteDB `Loading ITEM`（100k rows，single worker）明顯緩慢。

dstat 觀測（poc-1，4 vCPU）：

```
usr  sys  idl  wai  csw      disk-w    net
41%  19%  39%  0%   ~160k/s  2–4 MB/s  ~12 MB/s
Load avg: 6.3–6.8 / 4 vCPU = 1.6× overloaded
```

### 根本原因

**YugabyteDB（BenchmarkSQL / JDBC）**

```
每筆 COMMIT → Raft quorum 確認（需 2/3 節點 ACK）
16 workers 並行 → 大量短暫 TCP round-trip × 3 節點
→ 網路頻繁 wakeup → context switch 飽和（csw 160k/s）
→ 4 vCPU 排程壓力大 → commit latency 升高 → 吞吐下降
瓶頸：CPU scheduler 飽和 + 分散式 Raft 協議延遲（非磁碟 I/O）
```

**TiDB（go-tpc prepare）**

```
go-tpc 使用大 batch INSERT + Go 原生低 syscall overhead
TiKV 3 副本同樣走 Raft，但：
  - batch size 大 → 每次 Raft RTT 攜帶更多資料
  - Go goroutine scheduler 比 JVM thread 輕量
  - TiDB 有 Lightning import mode 可完全繞過 Raft
→ 單位 Raft RTT 效益高，csw 壓力相對低，吞吐較高
```

### 比較表

| 面向 | TiDB (go-tpc) | YugabyteDB (BenchmarkSQL) |
|------|---------------|--------------------------|
| 工具語言 | Go（低 syscall overhead） | Java/JDBC（JVM overhead） |
| batch size | 較大 | 較小（逐行或小批） |
| Raft bypass | import mode 可完全繞過 | `yb_disable_transactional_writes`（部分繞過） |
| 儲存引擎 | RocksDB LSM（write-optimized） | DocDB（RocksDB 變體） |
| CPU 效率 | 高 | 較低 |
| 匯入速度 | 快 | 慢（ITEM 尤明顯） |

### 結論

差異主要來自**工具層不對等**，而非 DB 引擎本身差距。  
正式 YugabyteDB 大量匯入應使用 `COPY` 命令或 `ysql_dump/restore`，效能會大幅提升。  
BenchmarkSQL ITEM 慢屬正常；後續 WAREHOUSE/STOCK 建議搭配 RF=1 prepare 策略加速。

---

## Gflag 調查紀錄（2026-04-29）

影響 prepare 寫入速度的 TServer 預設值：

| Flag | 預設值 | 問題 | 建議值 |
|------|--------|------|--------|
| `ysql_num_shards_per_tserver` | 1 | 3 節點僅 3 tablets/table；8 workers 競爭 3 leader | 3 |
| `memstore_size_mb` | 128 | MemTable 小 → 頻繁 flush → L0 file 累積 → compaction stall | 512 |
| `rocksdb_max_write_buffer_number` | 2 | flush 中 active buffer 滿 → write stall | 4 |
| `rocksdb_level0_file_num_compaction_trigger` | 5 | bulk load 頻繁觸發 compaction | 10 |

查詢方式：
```bash
curl -s 'http://<node>:9000/varz?raw' | grep -E 'memstore|write_buffer|compaction|num_shards'
```

Runtime 修改（不需重啟，--force 繞過 not-safe 限制）：
```bash
/opt/yugabyte/bin/yb-ts-cli --server_address=<node>:9100 \
  set_flag --force <flag_name> <value>
```
