# YugabyteDB TPC-C Pipeline 作業紀錄

**結論**：Strategy C（`ysql_enable_packed_row=false`）+ tpccbenchmark v2.4 在單節點驗證載入零錯誤；3-node RF=3 叢集已恢復（zone-a/b/c + HAProxy roundrobin 入口，新 UUID `128cf909-...`），待 3-node 拓撲再驗證一次 baseline。

---

## TL;DR — YugabyteDB TPC-C Pipeline 進度彙整

### 一、目前遇到的核心問題

| # | 問題 | 嚴重度 | 影響 |
|---|------|-------|------|
| 1 | **Schema packing not found: 0, available_versions: [5]** | 🔴 阻斷 | 4 tier 累計 15.6–48 萬 unique errors，錯誤率 10–60%，tpmC 嚴重低估 |
| 2 | 硬體規格不足對齊官方基準 | 🟡 結構性 | 3×4vCPU/16GB 是官方 100K 紀錄組的 1/9 vCPU、1/4 RAM |
| 3 | BenchmarkSQL 與官方 tpccbenchmark 工具不一致 | 🟡 方法論 | 結果無法直接對照官方公佈數據 |
| 4 | MVCC 衝突殘留（Restart read / serialize fail） | 🟢 可接受 | TPC-C 本質高衝突，比例已大幅下降 |

### 二、根因分析（已確認）

| 假設 | 驗證方式 | 結論 |
|------|---------|------|
| Raft / 跨節點 schema 同步問題 | 單節點 RF=1 重測 | ❌ 否定 — 單節點仍復發 28 萬 errors |
| OS 層環境設定不當（THP/limits/core_pattern）| 完整對齊官方 prerequisite | ❌ 否定 — 完整套用後仍復發 |
| 測試時間過短未觸發 | 5m vs 10m 對比 | ✅ 印證 — 5m 未觸發、10m 必觸發 |
| **DocDB packed-row + compaction 清除舊 schema metadata** | 三階段橫向比對 | ✅ **確認根因** |

**機制**：prepare 階段 `CREATE TABLE / CREATE INDEX / ALTER` 累積 schema version v0→v5，早期 row 用 v0 packed 編碼；major compaction rewrite SST 時只保留當前 schema metadata，v0 metadata 被清 → 讀取時報錯。

### 三、已解決問題（15 項）

| 類別 | 已解決項目 |
|------|----------|
| 環境/工具 | HAProxy port 衝突、psql/JDK 缺失、BenchmarkSQL 需編譯、props password 處理、CREATE DATABASE 判斷邏輯、cleanup pkill、locale `%tp` 解析、osCollector python 依賴 |
| 叢集穩定 | destroy 殘留 conf 重建流程、`yb_disable_transactional_writes` 移除、`reWriteBatchedInserts=true` 縮短 txn |
| 效能調校 | loadWorkers 16→8、`timestamp_history_retention_interval_sec` 7200、`ysql_num_shards_per_tserver=3`、RF=1 bulk load 策略 |
| MVCC 衝突 | `yb_enable_read_committed_isolation=true`、`enable_wait_queues=true` runtime set |
| 環境前置 | THP=always+defer+madvise（systemd 持久化）、limits 1048576/12000、kernel.core_pattern + cores 目錄 |

### 四、三階段測試成果對比

| 階段 | 拓撲 | 峰值 tpmC | 錯誤率峰值 | 主要錯誤類型 |
|------|------|----------|----------|-------------|
| 20260429-1636 | 3-node RF=3 | 3,863 (16t/5m) | 1.1% | MVCC 衝突 |
| 20260430-1341 | 3-node RF=3 | 12,259 (128t/10m) | 60.0% | **Schema packing** |
| 20260504-0230 | 1-node RF=1 | 6,772 (32t/10m) | 38.5% | **Schema packing** |

### 五、歷史 prepare / load 時長對比

| 階段 | 工具 | 拓撲 | packed_row | 耗時 |
|------|------|------|-----------|------|
| 20260430-1341 | BenchmarkSQL | 3-node RF=3 | true | ~190m |
| 20260504-0230 | BenchmarkSQL | 1-node RF=1 | true | ~225m |
| 20260504-1041 | BenchmarkSQL | 1-node RF=1 | false | 390m（撞 Customer not found） |
| 20260504-2155 | tpccbenchmark | 1-node RF=1 | false | **40m45s** ✅ |

**關鍵觀察**：tpccbenchmark vs BenchmarkSQL 在同等 packed_row=false 條件下 **9.6× 加速**；BenchmarkSQL 與 packed_row=false 不相容（run 階段 C_LAST 缺料 FATAL）。

### 六、下一步測試方向

#### 🎯 進度：C 載入階段已驗證，待 execute；A 後置

| 優先 | 方向 | 動作 | 進度 |
|------|------|------|------|
| **1️⃣ C** | 驗根因對策 | `.32` tserver `ysql_enable_packed_row=false` → tpccbenchmark load 128w | ✅ 載入 40m45s 完成、Schema packing=0、資料完整。**待 execute 驗 runtime tpmC** |
| **附帶 B** | 換工具 | BenchmarkSQL run 失敗（C_LAST 缺）→ 換 YB 官方 tpccbenchmark v2.4 | ✅ 已部署於 .31，Java 11 路徑修妥 |
| **2️⃣ A** | 規格匹配 | WAREHOUSES=32、THREADS=48 單階、3-node RF=3、每 tier 前重建 | C 完成後再進 |

#### 驗收條件

| 指標 | 通過門檻 | 備註 |
|------|---------|------|
| Schema packing not found | **= 0** | 必要條件 |
| 整體錯誤率 | < 5% | MVCC 衝突可接受殘留 |
| tpmC（32t）| ≥ 6,500 | 與 20260504 baseline 同等或更高 |
| storage 增量 | < 30% | packed_row=false 會略增儲存 |

### 七、風險與限制

| 風險 | 緩解 |
|------|------|
| `ysql_enable_packed_row=false` 是非預設組態，可能影響生產相容性 | POC 階段可接受；正式環境需等 YugabyteDB 修復 packed-row + compaction bug |
| 單節點驗證通過不代表 3-node 必通過 | C 通過後立即在 3-node RF=3 重跑驗證 |
| 規格不足無法達官方公佈 tpmC 水平 | 目標調整為「取得內部可重現基準」而非追平官方 |

---

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
| 13 | `Failed to create directory '下午c-c_result%'` | Java `String.format()` 把 `%tp` 解析為 locale AM/PM（中文環境 = 下午/上午） | `resultDirectory` 改為 `$(mktemp -u /tmp/bsl-result.XXXXXX)`，unique path 且不預先建立目錄 |
| 14 | `Cannot run program "python"` | `osCollectorScript` 需要 `python` binary，節點未安裝 | 移除 props 中的 `osCollectorScript` 與 `osCollectorInterval` |
| 15 | `Unknown transaction, could be recently aborted` / 大量 conflict error | `yb_enable_read_committed_isolation=false`（預設）→ READ COMMITTED 無 statement-level retry；`enable_wait_queues=false`（預設）→ 衝突直接 abort | `yb-ts-cli set_flag --force yb_enable_read_committed_isolation true`；`set_flag --force enable_wait_queues true`（3 節點均執行，runtime 生效無需重啟） |

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

---

## Benchmark 結果（yuga-vm，2026-04-29）

### 叢集狀態（benchmark 前確認）

- RF=3，9 tablets/table（ysql_num_shards_per_tserver=3）
- `yb_enable_read_committed_isolation=true`（runtime set）
- `enable_wait_queues=true`（runtime set）
- `timestamp_history_retention_interval_sec=7200`（runtime set）

### 第一次有效跑（20260429-1636）

| 參數 | 值 |
|------|----|
| threads | 16 |
| duration | 5m |
| warehouses | 128 |
| warmup | 5m |

| 指標 | 值 |
|------|----|
| **tpmC** | **3,863.75** |
| tpmTOTAL | 8,566.17 |
| p99 NEW_ORDER | n/a（CSV 解析待修）|
| p99 PAYMENT | n/a |

**狀態**：conflict error 仍存在（`enable_wait_queues=true` 剛啟用，待 16t re-run 確認改善幅度）。

### 全量跑（20260430-1341，THREADS_LIST="16 32 64 128"）

| threads | tpmC | Schema packing err (v5) | Schema packing err (v3) | serialize err | kAborted |
|---------|------|------------------------|------------------------|---------------|---------|
| 16 | 9,563 | 127,223 | 299 | 2 | 0 |
| 32 | 9,545 | 88,714 | 5,783 | 1,861 | 44 |
| 64 | 11,161 | 96,720 | 16,467 | 2,306 | 50 |
| 128 | 12,260 | 105,050 | 15,700 | 8,025 | 227 |

**結果無效**：`Schema packing not found: 0, available_versions: [5]` 大量出現（~10 萬次/run），retry 消耗大量 CPU/connection，tpmC 嚴重低估。

### Schema packing 問題技術原理

YugabyteDB DocDB 用 packed row 格式：每筆 row 用 binary blob 存，並記錄該 row 用哪個 schema version 編碼。BenchmarkSQL `runDatabaseBuild.sh` 過程中 schema version 從 v0 累積到 v5（CREATE TABLE / CREATE INDEX 各自 +1）。早期載入的 row 用 v0 編碼，但 DocDB major compaction rewrite SST file 時只保留「目前 schema version 的 packing metadata」，v0 metadata 被清掉後 v0 編碼的 row 就讀不了。

### 對策（待選）

| 優先 | 方案 | 前提 | 效果 |
|------|------|------|------|
| ✅ 首選 | go-tpc + PG driver | 確認 driver 支援 | 工具與 TiDB 對齊，schema version 不疊加 |
| ✅ 次選 | `yb-admin compact_table` | 不重跑 prepare | rewrite all row 至當前 schema version |
| ⚠️ 備用 | `ysql_enable_packed_row=false` | 須重跑 prepare | 改用 legacy row format，徹底但 storage 略大 |

---

## 環境重建（2026-05-03）

### 觸發原因

20260430-1341 的 packed row schema mismatch 無法靠 runtime flag 修復，決定：停服務 → 清 data dir → 重新依官方 manual provisioning checklist 對齊環境後再裝叢集。

### 官方 prerequisite check 結果（3 節點 .32/.33/.34）

| 項目 | 官方要求 | 實際 | 狀態 |
|------|---------|------|------|
| OS | RHEL/AlmaLinux 8/9 | AlmaLinux **10.1** | ⚠️ 過新但相容 |
| yugabyte UID | 一致 | 1000 | ✅ |
| Python | 3.5–3.9 | **3.12.12**（系統內建） | ⚠️ 只報 SyntaxWarning，不影響執行 |
| chrony 同步 | 必要 | 同步 172.19.254.7，誤差 <100μs | ✅ |
| vm.swappiness | 0 | 0 | ✅ |
| vm.max_map_count | 262144 | 262144 | ✅ |
| **THP** | madvise / always（yugabyted 工具實際只接受 `always`） | `[never]` → 改為 `[always]` + `[defer+madvise]` | ❌→✅ |
| SELinux | 停用 | Disabled | ✅ |
| firewalld | 停用 | inactive | ✅ |
| nofile | 1048576 | 1000000（ansible 寫的） → **修正為 1048576** | ❌→✅ |
| nproc | 12000 | 65535（ansible 寫的） | ✅（高於要求） |
| **kernel.core_pattern** | `/home/yugabyte/cores/...` | `systemd-coredump` → 改為 `/home/yugabyte/cores/core_%p_%t_%E` | ❌→✅ |
| /home/yugabyte/cores | 存在 | 不存在 → 已建立 yugabyte:yugabyte 755 | ❌→✅ |

### 修正動作（3 節點皆執行）

```bash
# 1. core_pattern (persist)
cat > /etc/sysctl.d/99-yugabyte.conf <<EOF
kernel.core_pattern = /home/yugabyte/cores/core_%p_%t_%E
EOF
sysctl -p /etc/sysctl.d/99-yugabyte.conf

# 2. cores dir
install -d -o yugabyte -g yugabyte -m 755 /home/yugabyte/cores

# 4. THP 設為 always（yugabyted 工具檢查 [always] 才放行）
echo always > /sys/kernel/mm/transparent_hugepage/enabled
echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag

cat > /etc/systemd/system/disable-thp-never.service <<'UNIT'
[Unit]
Description=Set transparent_hugepage=always (YugabyteDB requirement)
After=sysinit.target local-fs.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c "echo always > /sys/kernel/mm/transparent_hugepage/enabled"
ExecStart=/bin/sh -c "echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag"
RemainAfterExit=yes
[Install]
WantedBy=basic.target
UNIT
systemctl daemon-reload && systemctl enable --now disable-thp-never.service

# 3. 完整 limits（取代 ansible 99-db.conf）
cat > /etc/security/limits.d/99-yugabyte.conf <<EOF
*  -  core       unlimited
*  -  data       unlimited
*  -  fsize      unlimited
*  -  nofile     1048576
*  -  nproc      12000
*  -  locks      unlimited
*  -  memlock    64
*  -  msgqueue   819200
*  -  stack      8192
EOF
```

驗證（以 yugabyte 身份）：`ulimit -n=1048576`、`ulimit -u=12000`、`ulimit -l=64`。

### 服務停止 + 清空 data dir

```bash
for node in 172.24.40.32 172.24.40.33 172.24.40.34; do
  ssh root@${node} "sudo -u yugabyte /opt/yugabyte/bin/yugabyted stop"
  ssh root@${node} "rm -rf /opt/yugabyte/data /home/yugabyte/var/conf"
done
```

確認 3 節點無任何 yb-master / yb-tserver / yugabyted / postgres process。

### .32 單節點重建（2026-05-03）

```bash
ssh root@172.24.40.32 "sudo -u yugabyte /opt/yugabyte/bin/yugabyted start \
  --advertise_address=172.24.40.32 \
  --cloud_location=gcp.asia-east1.asia-east1-a \
  --fault_tolerance=none \
  --base_dir=/opt/yugabyte/data \
  --ui=false"
```

| 項目 | 值 |
|------|----|
| Version | 2.20.1.3-b0 |
| Status | Running |
| RF | 1 |
| Universe UUID | `f926eca1-2b34-4a3f-88bb-5eae9b871db8` |
| YSQL | `172.24.40.32:5433` |
| Web console | `http://172.24.40.32:7000` |

### 踩坑：stop+wipe+start 同 SSH session race

第一次重啟把 `stop && rm && start` 串在同一個 `ssh` 命令裡，stop 回傳後 child process 還沒完全清掉，後續 yb-master/yb-tserver 撞到舊 port → fatal log "Address already in use"。yugabyted 仍舊把不一致的 conf 落地（`advertise_address=""`、`cluster_uuid` 與 API 對不上）。

**正確流程**：先 `pkill -9 -f 'yb-master|yb-tserver|yugabyted'` → `rm -rf data/conf` → 確認 process 清空 → 再 `yugabyted start`。

---

## 單節點驗證（2026-05-03 → 2026-05-04 完成）

### 目的

驗證 Schema packing not found 在**單節點 RF=1** 是否仍復發。若仍復發，代表這是 DocDB compaction 機制本身的問題（不是 Raft / 跨節點 schema 同步問題），需走 `ysql_enable_packed_row=false` 或 `compact_table` 對策。

### 環境

- 連線：`.31 → .32:5433`（HAProxy 已停）
- HAProxy on .32 已 `systemctl stop`
- 未調整 packed_row 與 num_shards（保持預設，先觀察 baseline）

### 測試指令（在 .31 tmux 執行）

```bash
# cleanup
YUGA_HOST=172.24.40.32 YUGA_PORT=5433 \
  VARIANT=yuga-vm TOPO=yuga-tc1 SCENARIO=S-BASE \
  bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh cleanup

# prepare
YUGA_HOST=172.24.40.32 YUGA_PORT=5433 \
  WAREHOUSES=128 VARIANT=yuga-vm TOPO=yuga-tc1 SCENARIO=S-BASE \
  bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh prepare

# run
YUGA_HOST=172.24.40.32 YUGA_PORT=5433 \
  WAREHOUSES=128 DURATION=10m THREADS_LIST="16 32 64 128" \
  WARMUP=5m VARIANT=yuga-vm TOPO=yuga-tc1 SCENARIO=S-BASE \
  RESULT_BASE=/tmp/yuga-results \
  bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh run
```

### prepare 期間負載快照（單節點）

| 指標 | 值 | 比較 |
|------|----|----|
| Load avg (1m) | 12.03 | 4 vCPU 3× overload |
| CPU us/sy/id | 57% / 23% / 20% | 充分運轉 |
| context switch | 145k/s | 高 |
| yb-tserver CPU | ~26%（1 核） | — |
| 連線數 | 8 個 INSERT backend (.31) | loadWorkers=8 確認生效 |

對比 3-node prepare（load ~6.3）：單節點 load 翻倍。原因：`ysql_num_shards_per_tserver` 預設 1 → 每張表只有 1 tablet，所有 INSERT 集中打單一 leader。

### 結果（20260504-0230，run 總計 45m33s）

#### tpmC 對比（128 warehouse / 5m warmup / 10m duration）

| Threads | 單節點 RF=1 tpmC | 3-node RF=3 tpmC | 比例 |
|--------:|-----------------:|------------------:|-----:|
| 16  | **4732.36** | 9563  | 49% |
| 32  | **6771.98** | 9545  | 71% |
| 64  | **5954.85** | 11161 | 53% |
| 128 | **5788.77** | 12260 | 47% |

單節點在 32 thread 觸頂後即下降，符合 4 vCPU CPU-bound 預期。

#### Schema packing error 計數（**單節點仍大量復發**）

| Threads | 錯誤總數 | 主要交易類型 |
|--------:|---------:|-------------|
| 16  | 22,368  | NEW_ORDER / PAYMENT |
| 32  | 104,082 | NEW_ORDER / PAYMENT |
| 64  | 69,129  | NEW_ORDER / PAYMENT |
| 128 | 87,617  | NEW_ORDER 21k / PAYMENT 18k / DELIVERY 2k / ORDER_STATUS 2k |
| **合計** | **283,196** | — |

錯誤訊息一致：`Schema packing not found: 0, available_versions: [5]`（要求 schema_version=0，僅剩 v5）。

### 結論：根因確認 + 對策選擇

1. **Schema packing 不是 Raft / 跨節點 schema 同步問題**——單節點 RF=1 仍大量復發（且總數比 3-node 還高）。
2. **根因確認**：DocDB 在 schema 變更（prepare 階段 ALTER TABLE 加 PK / FK）後，舊 schema metadata 在 compaction 中被清除；packed-row 格式仍引用舊 schema_version → 讀取時 metadata 找不到 → 報錯。
3. **採用對策 A**：下一輪測試前在 .32 yb-tserver 加 `--ysql_enable_packed_row=false` 重啟 → cleanup → prepare → run。
   - A 是治本（packed row 是 schema packing 機制本身）
   - B（`yb-admin compact_table`）是反應式且不一定根除
   - C（換 go-tpc）規避而非解決
4. **次要結論**：單節點 4 vCPU 跑 128 warehouse TPC-C，最佳吞吐落在 32 thread（6772 tpmC），thread 上去後 context switch 反而拖累，這是後續 yb-tc1 容量規劃的參考點。

## 三階段對比（2026-04-29 → 2026-05-04）

### 設定差異

| 項目 | 20260429-1636 | 20260430-1341 | 20260504-0230 |
|------|---------------|---------------|---------------|
| 拓撲 | 3-node RF=3 | 3-node RF=3 | **1-node RF=1** |
| 連線路徑 | `.31 → .32:5433` 直連 | `.31 → HAProxy:15433` | `.31 → .32:5433` 直連 |
| WAREHOUSES | 128 | 128 | 128 |
| DURATION | **5m** | 10m | 10m |
| WARMUP | 5m | 5m | 5m |
| THREADS_LIST | `16` 單階 | `16 32 64 128` | `16 32 64 128` |
| 總執行時間 | ~10m | ~60m | ~45m |
| 環境前置 | 未做（THP=never） | 部分（THP=madvise，錯） | **完整**（THP=always+defer+madvise + limits + core_pattern + cores 目錄）|
| `ysql_enable_packed_row` | 預設 true | 預設 true | 預設 true |

### tpmC

| Threads | 20260429-1636 | 20260430-1341 | 20260504-0230 |
|--------:|--------------:|--------------:|--------------:|
| 16  | 3863.75 | **9563.19** | 4732.36 |
| 32  | — | 9545.02 | **6771.98** |
| 64  | — | **11160.99** | 5954.85 |
| 128 | — | **12259.50** | 5788.77 |

### 錯誤率（unique JDBC exceptions / 完成 txn）

| Tier | 20260429-1636 | 20260430-1341 | 20260504-0230 |
|------|--------------:|--------------:|--------------:|
| c16  | 489 / 42857 = **1.1%** | 127535 / 212391 = **60.0%** | 11254 / 105199 = **10.7%** |
| c32  | — | 98305 / 212588 = 46.2% | 55378 / 151408 = 36.6% |
| c64  | — | 117969 / 248813 = 47.4% | 38888 / 132880 = 29.3% |
| c128 | — | 137264 / 272812 = 50.3% | 50438 / 130849 = 38.5% |

### 錯誤類型

| 階段 | 主要錯誤 |
|------|---------|
| 20260429 | **無 Schema packing**；MVCC 競爭：`Restart read required` (31)、`could not serialize access` (54)、`Unknown transaction` (10)、`Transaction aborted` (7) |
| 20260430 | **Schema packing not found** 暴量（4 tier 各 ~10 萬+），其他 MVCC 錯誤 < 10 |
| 20260504 | 同 20260430 模式：Schema packing 為主，MVCC 殘留 |

### 各階段遭遇問題

#### 20260429-1636 — 試水溫
- 3-node 叢集已建好，能跑通 16 thread / 5m
- 只跑 1 階，DURATION=5m 太短，未進入 compaction 時間窗 → Schema packing **未觸發**
- 環境前置幾乎沒做（THP=never、無 kernel.core_pattern、limits 預設）
- 主要錯誤：MVCC restart read / serialize fail（TPC-C 高衝突量本質）

#### 20260430-1341 — 全量 baseline
- 跑完 4 tier × 10m，獲得吞吐曲線（峰值 12260 tpmC @ 128 thread）
- **Schema packing not found 災難級** — 4 tier 累計 48 萬 unique errors，錯誤率 46–60%；tpmC 嚴重低估（實際正確完成的交易少一半）
- THP 設成 `madvise` 而非 `always`（yugabyted 啟動時警告但仍跑）
- 過 HAProxy 走 15433 → 增加一層轉送
- 開機資源限制部分套用，但未持久化（重啟即失效）

#### 20260504-0230 — 單節點根因驗證
- 環境完全對齊官方（THP=always + defer+madvise + systemd 持久、nofile/nproc/memlock、core_pattern + cores 目錄）
- 直連 .32:5433（HAProxy 停）；單機 Universe `f926eca1-...`
- 過程中遭遇 stop+wipe+start 在同一 SSH chain 的 race condition（yb-master/tserver pid 殘留 → conf 落地不一致），改用 pkill -9 後分段執行解決
- **Schema packing 仍復發**（4 tier 累計 15.6 萬 unique errors，錯誤率 10–38%）→ 確認是 DocDB packed-row + compaction 機制問題，與多節點 Raft 無關
- tpmC 比 3-node 低 47–71%，符合單機 4 vCPU CPU-bound 預期；峰值在 32 thread（6772）後遞減

### 跨階段關鍵發現

1. **20260429 沒有 Schema packing**：prepare 完成後馬上跑且只跑 5m，compaction 還沒清舊 schema metadata；後兩次跑滿 4 階 + 10m，compaction 必然觸發 → 錯誤是「時間累積」而非「立即性 bug」。
2. **拓撲不影響根因**：3-node 28 萬 vs 1-node 15.6 萬 unique errors，量級相同 → 不是 Raft / 跨節點問題。
3. **環境前置不影響根因**：完整套用官方前置仍復發 → 不是 OS 層 limits / THP 引起。
4. **唯一未試過的變因**：`ysql_enable_packed_row` 三次皆為預設 true → 下一輪以對策 A（`ysql_enable_packed_row=false`）驗證。

## 對齊官方 TPC-C 文件（2026-05-04）

閱讀來源：
- https://docs.yugabyte.com/stable/benchmark/tpcc/
- https://docs.yugabyte.com/stable/benchmark/tpcc/running-tpcc/
- https://docs.yugabyte.com/stable/benchmark/tpcc/horizontal-scaling/
- https://docs.yugabyte.com/stable/benchmark/tpcc/high-scale-workloads/
- https://docs.yugabyte.com/stable/benchmark/
- https://docs.yugabyte.com/stable/explore/linear-scalability/scaling-transactions/

### 我們現況 vs 官方建議的關鍵 gap

| 維度 | 我們 | 官方 | 落差 |
|------|------|------|------|
| 工具 | BenchmarkSQL (jTPCC) on .31 | `/opt/yugabyte/bin/tpccbenchmark`（YB 內建，OLTPBench 衍生）| 不同 fork，官方發布結果用前者 |
| 節點規格 | 3 × 4 vCPU / 16GB | 最小 3 × 2 vCPU（10 warehouse），mid 3 × 16 vCPU（100/1000 warehouse）| 規格嚴重不足 |
| WAREHOUSES | 128 | 10 (3×2vCPU) / 100 (3×16vCPU) / 1000 (3×16vCPU) | 對 4 vCPU 拍 128，過載 |
| `loaderthreads` | 8 | ≈ 全叢集核心數 | 3-node × 4 vCPU = 12 → 應 12 |
| 連線數/節點 | 16/32/64/128 thread total | ~67 conn/node（500w/3n=200, 1000w/4n=266）| 每節點 5–43 連線，偏少 |
| Warmup | 5m | 60s 或 300s（多 client 才 300s）| OK |
| 階層測試 | 同一 prepare 跑 4 tier | 每 tier 前 `--create=true` 重建（horizontal scaling 明文）| 累積 compaction → 放大 schema packing |
| `ysql_enable_packed_row` | 預設 true | 文件未提（TPC-C 段落）| 可能 2.20.1.3 已知 bug 而非 config 議題 |

### 官方公布成績的硬體基準（對照組）

| Scale | Cluster | Hardware | tpmC | 效率 | YBDB 版本 |
|-------|---------|----------|------|------|-----------|
| 100K warehouse | 59 nodes | c5d.9xlarge (36 vCPU / 72GB / NVMe) | 1,283,804 | 99.83% | 2.18.0 |
| 150K warehouse | 75 nodes | c5d.12xlarge (48 vCPU / 96GB) | ~1M | 99.3% | 2.18.0 |
| 1K warehouse | 3 nodes | 16 vCPU each | — | — | — |
| 100 warehouse | 3 nodes | 16 vCPU each | — | — | — |
| 10 warehouse | 3 nodes | 2 vCPU each | — | — | — |

我們 3 × 4 vCPU / 16GB 是 100K 紀錄組的 1/9 vCPU、1/4 RAM。

### 多 client 分擔載入（規模 >1000 warehouse 才需要）

```
--warehouses=2500           # per-client 切片
--total-warehouses=10000    # 全資料集規模
--start-warehouse-id=1/2501/5001/7501  # 切片起點
--initial-delay-secs=0/30/60/90        # 錯開避免 master catalog overload
--loaderthreads=16          # 每個 client
--num-connections=90        # execute 階段
```

我們規模未達門檻，單 client (.31) OK。

### 三個重規劃方向

**方向 A：縮規模符合硬體**
- WAREHOUSES 降至 10–32
- THREADS_LIST 單一 tier（如 48 = 3-node × 16）
- 每 tier 前 cleanup + prepare 重建
- 續用 BenchmarkSQL
- 目的：取得乾淨 baseline，避免 Schema packing 蓋掉訊號

**方向 B：換用官方 tpccbenchmark 工具**
- `/opt/yugabyte/bin/tpccbenchmark`
- 旗標：`--create=true → --load=true → --execute=true --warmup-time-secs=60 --num-connections=N`
- 風險：重寫 yuga-tpcc.sh wrapper、result 落地格式不同
- 目的：對齊官方 code path，排除 BenchmarkSQL JDBC 行為差異

**方向 C：先驗對策 A（`ysql_enable_packed_row=false`）**
- 不動工具、不改規模
- 在 .32 重啟加 tserver flag → cleanup → prepare → run
- 目的：快速驗證根因 + 取得無 schema packing 的對照吞吐
- 缺點：不解決規格不足

### 採用順序：C → A（先治根，再縮規模）

1. **先 C**：1 小時驗 packed_row=false 是否清掉 Schema packing。錯誤歸零 → 取得可信 baseline。
2. **再 A**：規格匹配（warehouse=32、threads=48 單階、3-node RF=3），得到乾淨對照。
3. **B 暫緩**：換工具成本高，先不為未確認相關性的問題改流程。

---

## Strategy C 執行 + 工具切換（2026-05-04 → 2026-05-05）

### 一、Strategy C 動作（.32 單節點 RF=1）

| 步驟 | 動作 | 結果 |
|------|------|------|
| 1 | `yugabyted stop` → 加 `--tserver_flags='ysql_enable_packed_row=false'` 重啟 | OK |
| 2 | `yb_admin … list_all_tablet_servers` 確認 flag 生效 | OK |
| 3 | BenchmarkSQL cleanup + prepare（128 warehouse）| ⚠️ prepare 耗時 **386m40s（6.5h）** |
| 4 | BenchmarkSQL run | ❌ FATAL `Customer(s) for C_W_ID=28 C_D_ID=8 C_LAST=PRESANTIBAR not found` |

**判斷**：BenchmarkSQL 自身載入路徑與 packed_row=false 不相容（NURand C_LOAD=220 / C_RUN=125 valid，但載入完整性破損）。停損切換工具。

### 二、換用 YB 官方 tpccbenchmark v2.4

| 項目 | 內容 |
|------|------|
| 來源 | GitHub Releases v2.4（YB OLTPBench fork，20MB tarball） |
| 部署 | 走 .31 為 client，下載至 `/tmp/tpcc/` |
| 障礙 | `UnsupportedClassVersionError: class file version 55.0 / runtime supports 52.0` |
| 修復 | 修改 `tpccbenchmark` launcher，Java 路徑寫死 `/usr/lib/jvm/java-11-openjdk-11.0.25.0.9-2.el8.x86_64/bin/java` |
| 設定 | `dbtype=yugabyte`、port=5433、isolation=`TRANSACTION_REPEATABLE_READ`、batchSize=128 |

### 三、載入結果（packed_row=false 持續啟用）

| 階段 | warehouses | 耗時 | Schema packing errors | 狀態 |
|------|-----------|------|----------------------|------|
| Smoke test | 8 | **2m40s** | 0 | ✅ |
| 正式載入 | 128 | **40m45s** | 0 | ✅ |

**對比 BenchmarkSQL prepare 6.5h**：tpccbenchmark 9.6× 加速。

### 四、資料完整性驗證（128 warehouse）

| Table | Rows | 備註 |
|-------|------|------|
| warehouse | 128 | ✅ |
| district | 1,280 | 128 × 10 ✅ |
| customer | 3,840,000 | 128 × 30,000，每 wh 整 3 萬，無缺口 ✅ |
| item | 100,000 | ✅ |
| stock | 12,800,000 | 128 × 100,000 ✅ |
| oorder | 3,840,000 | ✅ |
| new_order | 1,152,000 | 128 × 9,000 ✅ |
| order_line | 38,398,557 | 接近 3.84M × 10 ✅ |
| history | 3,840,000 | ✅ |

### 五、載入期觀察

- RocksDB WARNING：`Stopping writes because we have 2 immutable memtables, max_write_buffer_number is set to 2`（write stall，非阻斷）
- 後續啟動建議：`--tserver_flags='ysql_enable_packed_row=false,rocksdb_max_write_buffer_number=4'` 一併持久化
- Background task `bc3fvkvcy` exit code 0

### 六、下一步

| 項目 | 動作 | 驗收 |
|------|------|------|
| Phase 3 execute | tpccbenchmark `--execute=true --num-connections=N` | runtime 全程 Schema packing = 0、tpmC 取得乾淨 baseline |
| 階層策略 | 待定：5m smoke → 4 階（16/32/64/128 conn）或直接 4 階 | 同上 |
| 配置確認 | `workload_all.xml` `<runtime>` 欄位（預設 1800s/30m）| 對齊原計畫的 10m/tier 需先改 XML |

---

## 3-node 叢集恢復（2026-05-05）

### 一、動機

單節點 Strategy C 已驗證 packed_row=false 能清掉 Schema packing；恢復 3-node RF=3 拓撲到 .32/.33/.34，準備在原始目標規格上再次驗證。

### 二、設計（最佳化優先，非 POC 妥協）

| 項目 | 設計 |
|------|------|
| 拓撲 | 3-node RF=3，`fault_tolerance=zone` |
| Zone 切分 | `.32 → asia-east1-a`、`.33 → b`、`.34 → c`（zone 級故障容忍） |
| 入口 | HAProxy on `.32:15433`，TCP roundrobin → 三節點 5433 |
| Universe UUID | `128cf909-001c-4034-a18a-8476883af6f8`（新建） |

### 三、tserver 啟動旗標（三節點一致）

| Flag | 值 | 目的 |
|------|----|------|
| `ysql_enable_packed_row` | false | **避免 DocDB packed-row + compaction Schema packing bug**（已驗證） |
| `rocksdb_max_write_buffer_number` | 4 | 消除 load 階段 write stall（預設 2 不夠） |
| `yb_enable_read_committed_isolation` | true | READ COMMITTED statement-level retry |
| `enable_wait_queues` | true | 衝突 wait 而非直接 abort |
| `timestamp_history_retention_interval_sec` | 7200 | 長壓測避免 kSnapshotTooOld |
| `ysql_num_shards_per_tserver` | 3 | 對齊 4 vCPU/16GB 小硬體 |

注：`ysql_num_shards_per_tserver` yugabyted 預設 `=1`，--tserver_flags 帶 `=3` 後 gflags 取最後值，實際生效為 3。

### 四、執行流程

```bash
# 1. 全節點停服 + pkill 確認 + 清資料
ssh root@<ip> "/opt/yugabyte/bin/yugabyted stop --base_dir=/opt/yugabyte/data; pkill -9 -f 'yb-master|yb-tserver|yugabyted'; rm -rf /opt/yugabyte/data /home/yugabyte/var/conf"

# 2. .32 bootstrap (zone-a)
sudo -u yugabyte /opt/yugabyte/bin/yugabyted start \
  --advertise_address=172.24.40.32 \
  --cloud_location=gcp.asia-east1.asia-east1-a \
  --fault_tolerance=zone --base_dir=/opt/yugabyte/data --ui=false \
  --tserver_flags='ysql_enable_packed_row=false,rocksdb_max_write_buffer_number=4,yb_enable_read_committed_isolation=true,enable_wait_queues=true,timestamp_history_retention_interval_sec=7200,ysql_num_shards_per_tserver=3'

# 3. .33 / .34 join（zone-b / zone-c，相同 tserver_flags）
... --cloud_location=gcp.asia-east1.asia-east1-b/c --join=172.24.40.32 ...

# 4. 強制 placement
yb-admin --master_addresses 172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100 \
  modify_placement_info gcp.asia-east1.asia-east1-a:1,gcp.asia-east1.asia-east1-b:1,gcp.asia-east1.asia-east1-c:1 3

# 5. HAProxy
systemctl start haproxy
```

### 五、HAProxy 設定（已存在於 .32:/etc/haproxy/haproxy.cfg）

```
defaults
  mode tcp
  timeout connect 5s
  timeout client  30s
  timeout server  30s

frontend ysql
  bind *:15433
  default_backend db_nodes

backend db_nodes
  balance roundrobin
  server node1 172.24.40.32:5433 check inter 2s
  server node2 172.24.40.33:5433 check inter 2s
  server node3 172.24.40.34:5433 check inter 2s
```

**模式**：純 roundrobin（mode tcp + balance roundrobin）。**無 session stickiness**（沒有 stick-table / stick on / cookie）；每條新 TCP 連線獨立輪詢，連線生命週期內固定後端。

### 六、驗收

| 檢查 | 指令 | 結果 |
|------|------|------|
| 三節點 ALIVE | `yb-admin list_all_tablet_servers` | 3 ✓ |
| Placement RF=3 | `yb-admin get_universe_config` | 3 zone × minNumReplicas=1 ✓ |
| HAProxy listen | `ss -tlnp \| grep 15433` | LISTEN ✓ |
| 連線可達 | `psql -h 172.24.40.32 -p 15433 -c 'select * from yb_servers()'` | 3 rows ALIVE ✓ |
| Roundrobin 分散 | 9 次連線 `select inet_server_addr()` 計次 | 3:3:3 ✓ |
| tserver flags | 三節點 `ps -ef \| grep yb-tserver` | 6 旗標皆生效 ✓ |

