# PMM PXC 叢集容量範例：p-pxc-n

## 資料範圍

- 成員：p-pxc-n-1, p-pxc-n-2, p-pxc-n-3
- 觀測期間：2026-06-26 23:23 +0800 至 2026-06-27 23:23 +0800（24 小時）
- 採樣與 rate 視窗：5 分鐘；持續峰值為連續三個樣本的移動平均。
- 每個 HTTP request timeout：1 秒
- 叢集總量只使用三個成員都有資料的共同時間點。
- 本報告是容量等效換算的輸入，不是經 TPC 稽核的 TPC-C 成績。

## 計算規則

對 metric `m`、成員 `i` 與對齊後的時間點 `t`：

1. 每台先換算速率：`x_i(t) = rate(m_i[5m]) * 60`。
2. 同時間點加總：`X(t) = x_1(t) + x_2(t) + x_3(t)`；缺少任一成員資料的時間點不納入。
3. P50/P95/P99：對加總後的 `X(t)` 計算，不能把三台各自的 percentile 相加。
4. Max 15m avg：每三個連續 `X(t)` 樣本取平均，再取其中最大值。
5. 物理/邏輯比值：每個時間點先算 `sum(RW commits_i(t)) / sum(local commits_i(t))`，再計算 percentile。

| 報告欄位 | 來源 metric | 彙整方式 | 意義 |
|---|---|---|---|
| 叢集發起的邏輯寫入 | `mysql_global_status_wsrep_local_commits` | 三台加總 | 此 PXC 叢集實際發起的邏輯寫入交易 |
| 唯讀交易 | `...trx_ro_commits_total` | 三台加總 | 讀取工作量，與 tpmC 等效值分開呈現 |
| 交易回滾 | `...trx_rollbacks_total` | 三台加總 | 整個叢集的回滾活動 |
| 所有節點承受的物理 RW commit | `...trx_rw_commits_total` | 三台加總 | 包含 wsrep 複寫造成的物理工作 |
| 所有節點承受的物理讀取列數 | `mysql_global_status_innodb_row_ops_total{operation="read"}` | 三台加總 | 所有節點實際處理的資料列讀取工作 |
| 觀測到的物理/邏輯 commit-work | RW 總量 / local 總量 | 每個時間點計算 | 容量診斷比值，不是 PXC replication factor |

## 邏輯需求與物理負載

| 指標 | 單位 | P50 | P95 | P99 | 15 分鐘平均峰值 | 峰值結束時間 | 對齊樣本數 |
|---|---|---:|---:|---:|---:|---|---:|
| 叢集發起的邏輯寫入 | txn/min | 1,272.7 | 4,895.1 | 5,370.3 | 5,368.2 | 06-27 06:38 | 289 |
| 唯讀交易 | txn/min | 57.2 | 321.8 | 552.9 | 1,756.0 | 06-27 03:28 | 289 |
| 交易回滾 | txn/min | 0.0 | 0.0 | 0.0 | 0.1 | 06-27 21:13 | 289 |
| 所有節點承受的物理 RW commit | txn/min | 10,711.5 | 22,066.7 | 25,844.4 | 26,231.2 | 06-27 06:03 | 289 |
| 所有節點承受的物理讀取列數 | rows/min | 49,151,084.8 | 85,910,724.8 | 121,215,851.6 | 208,516,120.6 | 06-27 03:48 | 289 |
| 觀測到的物理/邏輯 commit-work | ratio | 8.53 | 11.53 | 12.03 | 12.09 | 06-27 20:38 | 289 |

- 24 小時邏輯寫入設計需求候選值：**5,370.3 txn/min**（`max(P99, 15 分鐘平均峰值)`）。
- 寫入來源集中度：觀測到的 local commit 有 **100.00%** 來自 **p-pxc-n-1**。
- 在 benchmark 提供 `每 tpmC 對應的 logical local commits` 校正係數前，容量等效 tpmC 維持 N/A。

## HA 健康狀態

| 指標 | 數值 |
|---|---:|
| 健康狀態資料覆蓋率 | 100.0% (289/289) |
| Quorum 可用率（至少 2 台健康） | 100.000% |
| 三台同時健康 | 100.000% |

健康成員必須同時符合 `mysql_up=1`、`wsrep_ready=1`、`wsrep_connected=1`、`wsrep_local_state=4`（Synced）。這代表資料庫健康狀態，不等同應用程式或 Proxy 可用率。

### 目前成員狀態

| 成員 | up | ready | connected | local state | cluster size |
|---|---:|---:|---:|---:|---:|
| p-pxc-n-1 | 1 | 1 | 1 | 4 | 3 |
| p-pxc-n-2 | 1 | 1 | 1 | 4 | 3 |
| p-pxc-n-3 | 1 | 1 | 1 | 4 | 3 |

## 成員容量比較

| 成員 | Local commit P99 | 物理 RW P99 | RO P99 | CPU P99 | Memory P99 | Disk write P99 |
|---|---:|---:|---:|---:|---:|---:|
| p-pxc-n-1 | 5,370.3 txn/min | 10,967.2 txn/min | 239.8 txn/min | 22.0% | 89.2% | 15.9 MiB/s |
| p-pxc-n-2 | 0.0 txn/min | 7,729.2 txn/min | 167.8 txn/min | 8.7% | 86.2% | 14.1 MiB/s |
| p-pxc-n-3 | 0.0 txn/min | 7,634.0 txn/min | 162.1 txn/min | 9.0% | 85.5% | 15.4 MiB/s |

## 判讀說明

- 邏輯寫入需求是所有成員 `wsrep_local_commits` 在相同時間點的加總。
- 物理 RW commit 與 row operation 包含複寫工作，不能直接當成叢集 tpmC。
- 物理/邏輯 commit-work 比值只用於容量診斷，不是 PXC replication factor。
- 唯讀交易與寫入 tpmC 等效值分開呈現，不合併成單一數字。
- N-1 容量必須確認任一存活成員能承接整個叢集的邏輯需求；CPU 百分比不能跨節點相加當成容量。
- 24 小時範圍只驗證資料收集與報告格式；正式 sizing 仍需涵蓋業務尖峰並完成 benchmark 校正。
