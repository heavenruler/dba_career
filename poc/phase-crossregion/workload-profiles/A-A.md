# Workload Profile: A/A (active-active)

## 定義

兩區 client 同時對 cluster 進行 read + write。

## Client 配置

| Region | Client | TPCC W 分配 | Threads | Endpoint |
|---|---|---|---|---|
| IDC | go-tpc @ idc-client (.31) | W=1-128 | 16/32/64/128 | idc-haproxy (.47.20) |
| GCP | go-tpc @ gcp-client (g-test-poc-5) | W=1-128 | 16/32/64/128 | gcp-haproxy (g-test-poc-4) |

→ **全 W=128 max contention**（per `decisions-2026-06-08.md` Q5 拍板）：兩端共用全部 warehouse 範圍，max key conflict / max cross-region raft 互擾；目的觀察跨區 active-active 最壞 case 行為。

## 預期觀察點

| 維度 | 觀察 |
|---|---|
| tpmC 兩側合計 vs IDC-only baseline | 預期顯著 < 100%（WAN 互擾 + cross-region key conflict 雙重壓力）|
| tail latency p99 | 預期顯著高於 baseline（per-shard leader 散區，部分寫必跨 WAN）|
| WAN runtime bytes | `wan/runtime-bytes.txt` per-second 量測（per §4 wan-probe.sh）|
| Cross-region key conflict rate | 兩側同 W 同時 update 同 key → 預期非 0；觀察 retry / abort 比例 |
| TiDB pessimistic lock-wait | 觀察 TiKV lock-wait queue 是否爆量 |

## 建議搭配 placement

- **P-B**（leader 散）→ A/A 的 raft 跨 WAN 行為最顯性
- P-A 下 A/A 大部分走 IDC leader，無法看到跨 WAN raft 衝擊（不建議）

## Metrics 增補

- `wan/runtime-bytes.txt` (per §4 wan-probe.sh; ifstat IDC↔GCP 介面 1s)
- `placement/leader-region.txt` (per-round dump)

## 限制

- 兩端 W 範圍完全重疊 → 兩端 client 對相同 warehouse 同時 update 機率高，retry / abort 為觀察重點而非錯誤
- 兩邊 client 啟動時間需校準（chrony 同步 < 100ms drift；per `gate-chrony-cross-region.sh`）
- 兩側 go-tpc 各自 prepare（共用 cluster 但獨立連線）；prepare 由 IDC client 走 idc-haproxy 一次完成即可

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | (init) | 初版 spec（Option B W 不重疊 1-64 / 65-128）|
| 2026-06-15 | (本) | per Q5 拍板修正：改為**全 W=128 兩端重疊** max contention；移除 Option B 不重疊段、修預期觀察與限制 |
