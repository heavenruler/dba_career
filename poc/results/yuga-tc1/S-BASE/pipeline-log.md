# YugabyteDB TPC-C Pipeline 作業紀錄

**日期**: 2026-04-28  
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

- `loadWorkers` 8 → **16**
- `ALTER DATABASE benchmarksql SET yb_disable_transactional_writes = true`（bulk load bypass Raft write path）
- 載入完成後 `RESET yb_disable_transactional_writes`

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
BenchmarkSQL ITEM 慢屬正常；後續 WAREHOUSE/STOCK 在 `yb_disable_transactional_writes=true` 生效後速度明顯加快。
