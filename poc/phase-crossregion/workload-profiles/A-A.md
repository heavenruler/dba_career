# Workload Profile: A/A (active-active)

## 定義

兩區 client 同時對 cluster 進行 read + write。

## Client 配置

| Region | Client | TPCC W 分配 | Threads | Endpoint |
|---|---|---|---|---|
| IDC | go-tpc @ idc-dbhost-1 client | W=1-64 | 16/32/64/128 | idc-haproxy |
| GCP | go-tpc @ gcp-dbhost-1 client | W=65-128 | 16/32/64/128 | gcp-haproxy |

→ **Option B W 分配**（C6 已決）：兩側 W 不重疊，隔離 key conflict 與 WAN 互擾。

## 預期觀察點

| 維度 | 觀察 |
|---|---|
| tpmC 兩側合計 vs IDC-only baseline | 預期 < 100%（WAN 互擾 + cross-region key conflict）|
| tail latency p99 | 預期顯著高於 baseline（per-shard leader 散區，部分寫必跨 WAN）|
| WAN runtime bytes | `wan/runtime-bytes.txt` per-second 量測 |
| Cross-region key conflict rate | 兩側同時 update 不同 W 應為 0；若 > 0 → workload 設定錯 |

## 建議搭配 placement

- **P-B** （leader 散）→ A/A 的 raft 跨 WAN 行為最顯性
- P-A 下 A/A 大部分走 IDC leader，無法看到跨 WAN raft 衝擊（不建議）

## Metrics 增補

- `wan/runtime-bytes.txt` (Track E 必補；ifstat IDC↔GCP 介面 1s)
- `placement/leader-region.txt` (per-round dump)

## 限制

- 兩側 go-tpc 必須**獨立 prepare**（兩套 W；prepare.sh 需擴）
- 兩邊 client 啟動時間需校準（chrony 同步 < 100ms drift）

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | (本) | 初版 spec |
