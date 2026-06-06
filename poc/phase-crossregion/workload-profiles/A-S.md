# Workload Profile: A/S (active-standby)

## 定義

IDC 為 active（接 read + write）；GCP 為 standby（pure follower，client 平常不連）。

failover 時 client 才切到 GCP。

## Client 配置

| Region | Client | 平常 | failover 後 |
|---|---|---|---|
| IDC | go-tpc @ .31 (existing) | full TPCC | (down 模擬 region 失效) |
| GCP | go-tpc @ gcp-dbhost-1 | idle | full TPCC（接手）|

## 預期觀察點

| 維度 | 觀察 |
|---|---|
| 平時 tpmC | 接近 IDC-only baseline（GCP voter 只接 raft replication）|
| Failover RTO | IDC region down → GCP voter 變 leader → 新 client 接管，耗時 ~ election timeout + RTT |
| Failover RPO | raft 確保 0（已 commit 的 transaction 不丟）|
| WAN replication lag | replication-lag.txt per-second |

## 建議搭配 placement

- **P-A**（majority IDC）→ A/S 的 base case
  - 平常 IDC 兩 voter ACK 即 commit
  - GCP voter 為 follower（接 raft log replication）

## Failover 程序（測試時觸發）

1. **平時 baseline**：跑 IDC TPCC 5 round × 4 threads（同 baseline）
2. **觸發 failover**：`ansible -m shell -i ... 'systemctl stop tidb-server'` × IDC 3 nodes
3. **觀察 RTO**：GCP voter 變 leader，新 client 從 `.31` 切到 `gcp-dbhost-1`
4. **量化**：
   - failover-to-acceptance latency (s)
   - 第一筆 transaction success timestamp
   - 從 IDC down 到 GCP write success 的 dt

## Metrics 增補

- `failover/timeline.json`（chaos C7 cross-link）
- `placement/leader-region.txt` 前後對比

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | (本) | 初版 spec |
