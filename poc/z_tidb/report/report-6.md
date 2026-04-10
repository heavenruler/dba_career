# TiDB Intro for DBA #5-6

## TiDB 原理架構

### 儲存層（TiKV / RocksDB）

- TiDB Region 合併與分裂機制
- RocksDB SST 結構與前綴壓縮
- LSM-Tree Compaction 與三列族 (Default CF / Write CF / Lock CF)
- MemTable 與 Immutable MemTable
- Delta Tree 與 B+ Tree 比較

### 分散式事務系統

- 兩階段提交 (2PC) 與原子性保證
- Primary / Secondary Write 流程
- MVCC 寫入型別 (Put/Delete/Lock/Rollback)
- LockCF / WriteCF 雙鎖機制
- 事務模式自適應切換

### Raft 與一致性協議

- Raft Group 架構
- Leader 選舉與 Lease Time
- Heartbeat 與日誌複製機制
- Multi-Raft 架構與副本同步

### PD（Placement Driver）與調度機制

- Region 負載均衡與熱點打散
- PD 協調與 Region Merge 流程
- Leader 更新與心跳節奏調整

### SQL 層（TiDB Server）

- SQL Parser / Planner / Executor
- Explain Analyze 解讀
- Hash / Join 策略
- MPP 核心組件與調度

### TiFlash 與列式存儲

- Delta Tree 與 Sorted Data
- DTFile 結構與背景合併
- Column / Row Store 融合設計
- 冷熱資料交換策略

### 緩衝與快取體系

- TiDB Buffer 內部架構
- Store Engine Buffer 層次
- TiKV Block Cache 與 Compaction 效率

### GC 與資料維護

- TiDB GC 機制
- SafePoint 管理與版本清理
- Snapshot 隔離與可見性處理

### 系統維運與觀測

- Learner 副本同步
- Region 不可用監控
- Graceful Shutdown
- TiUP / pd-ctl 管理差異
