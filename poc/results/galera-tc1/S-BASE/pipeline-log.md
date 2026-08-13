# MySQL Galera Cluster（Percona XtraDB Cluster 8.4）TPC-C Pipeline Log — galera-tc1 / S-BASE

> 補測目的：填補 [`DISTRIBUTED-DB-SCORING.md`](../../../DISTRIBUTED-DB-SCORING.md)
> §2.1 MySQL 相容群組（Galera vs TiDB）#3/#4/#5 評分項目——這三家原本只有
> `phase-crossregion` 跨區 `vm-6node` 數字（見 §3.6），缺同拓樸的 `vm-1node`/
> `vm-3node-haproxy-3s3r` 對照。命名沿用 TiDB/CRDB/YBDB 既有慣例（IDC only，
> 不開 GCP，節費）；`vm-3node-haproxy-3s3r` 對 Galera 是 3 台完整副本（無 shard
> 概念），語意邊界見 §3.2.2 說明，不等同其他三家的 3 shard×RF3。

## TL;DR

**核心結論**：Galera 單節點吞吐量/延遲**大幅領先** TiDB 同拓樸數字，但加了 2 台
節點以 HAProxy round-robin 做 multi-writer 後**吞吐量反而衰退到單節點的 49%**
（負向擴展），與 TiDB 同拓樸下 2.06× 的正向擴展方向完全相反。

| topology | iso | tpmC (t=128 mean) | 5-round range/mean | error rate | TPCC_TS |
|---|---|---:|---:|---:|---|
| vm-1node | rc | 51,527.8 | 8.4% | 0.000% | `20260813T073744+0800` |
| vm-3node-haproxy-3s3r | rc | 26,166.2 | 43.2%（t=16 最高 117.5%） | 0.037%（all_txn） | `20260813T112044+0800` |

### 三大發現

1. **單節點下 wsrep 幾乎空轉**：`vm-1node` 無其他 Galera 成員可複寫，效果接近
   原生 MySQL/InnoDB——t=32 峰值 tpmC 53,791.9、NEW_ORDER p99 僅 37.7ms，四家
   `vm-1node` baseline 中最高，NEW_ORDER p99 更是 TiDB（597ms @t=128）的
   1/15.8。**Inference**：這很可能反映 TiDB 即使單 VM 部署仍有 PD/TiKV/
   TiDB-server 三元件協調開銷，不是 Galera「整體優於 TiDB」。
2. **多寫（HAProxy round-robin）造成負向擴展**：`vm-3node-haproxy-3s3r` 的
   tpmC 從單節點 53,791.9 掉到 26,166.2（0.49×）。**Fact**：post-run 單點
   wsrep snapshot 顯示 `wsrep_local_cert_failures=234`、
   `wsrep_local_bf_aborts=265`（相對 `wsrep_local_commits=1,559,041`，佔
   0.015%~0.017%）、`wsrep_flow_control_paused=22.4%`——certification 衝突
   確實發生，但**衝突成本 vs flow-control 同步成本各佔多少，本次未拆解**。
3. **round-to-round 穩定度是四家中最差**：`vm-3node-haproxy-3s3r` 的
   5-round range/mean 34.5%~117.5%（t=16 最極端：10,960.8/11,911.4/5,421.5/
   2,860.4/13,314.8，最低最高輪相差近 4.7 倍），且是四家（TiDB/CRDB/YBDB/
   Galera）中唯一觀測到非零 all-txn error rate 的一家（0.012%~0.037%，隨
   thread 數上升）。

### 業務啟示

- 若應用情境是單機/低併發（小型部署、報表庫、無需水平擴展），Galera 這裡的
  單節點數字反而優於 TiDB 同拓樸。
- 若需要真正的多節點水平擴展或高併發穩定性，本次數字明確不利於 Galera——
  但這是「無任何應用層優化下的 naive multi-writer（HAProxy round-robin）」
  情境，若改用單寫路由或以 shard key 分流降低跨節點熱點衝突，結果可能不同
  （本次未測，見 `phase-crossregion/GALERA-EXECUTION-PLAN.md` 尚待決策項目）。
- 缺 wsrep-off control（無法拆解複寫本身開銷 vs certification 衝突開銷）與
  逐輪 counter delta（無法解釋 round-to-round 為何差距近 4.7 倍），這兩項是
  把本節「型態相容但根因未證實」的觀察收斂成確定結論的必要後續步驟。

## 完整資料目錄

| topology | TPCC_TS | tpmC (t=128 mean) | error rate | 詳細段落 |
|---|---|---:|---:|---|
| vm-1node-rc | `20260813T073744+0800` | 51,527.8 | 0.000% | [`vm-1node-rc/galera-vm-1node-rc-20260813T073744+0800/summary.json`](./vm-1node-rc/galera-vm-1node-rc-20260813T073744+0800/summary.json) |
| vm-3node-haproxy-3s3r-rc | `20260813T112044+0800` | 26,166.2 | 0.037%（all_txn） | [`vm-3node-haproxy-3s3r-rc/galera-vm-3node-haproxy-3s3r-rc-20260813T112044+0800/summary.json`](./vm-3node-haproxy-3s3r-rc/galera-vm-3node-haproxy-3s3r-rc-20260813T112044+0800/summary.json) |

## 部署與量測過程（bug 修復記錄）

實跑於 2026-08-12/13，IDC only（`172.24.40.32/.33/.34` + HAProxy `172.24.47.20`），
歷經以下真實踩坑修正（詳見對應 commit 與
[`ansible/playbooks/galera-vm1.yml`](../../../ansible/playbooks/galera-vm1.yml)/
[`galera-vm3.yml`](../../../ansible/playbooks/galera-vm3.yml) 內註解）：

1. `ansible.builtin.dnf` module 在這批 IDC 模板上因 python3.12 缺
   python3-dnf binding 直接 fatal，改用 raw `ansible.builtin.command: dnf
   install -y ...`（比照既有 `tidb-vm1.yml` 的作法）。
2. `vm-1node` 首次 W=128 全量測跑到 threads=128 時發生 go-tpc livelock（單一
   round 跑超過 300s 設定值 11 倍以上、完全無新輸出），判定為極端 lock-wait-
   timeout 重試風暴下的已知 go-tpc 邊界案例（同類前例：`S-K8S` YBDB t128
   deterministic hang），kill 後重跑（第三次嘗試才完整跑完 20/20 輪，含
   threads=128 全 5 輪 0 error）。
3. 上述失敗重跑過程中，磁碟被無 purge 政策的 binlog 填爆到 100%（92GB／72+
   個 1GB binlog 檔案）——`vm-1node` 永遠不會有第二個成員跟它要 IST，
   binlog 純寫不讀卻沒設任何保留窗；修正為
   `binlog_expire_logs_seconds=1800`（vm1）／`3600`（vm3，仍可能需要短暫
   IST）。
4. `vm-3node-haproxy-3s3r` 部署時 HAProxy 主機（`.20`）因本機 ansible-core
   已升級到 2.18.7、module_utils 需要 Python 3.7+，但該主機只有既有的
   python3.6，任何 ansible module 一律 SyntaxError fatal——這是 ansible-core
   版本漂移造成的既有相容性斷層（TiDB/CRDB/YBDB 的 haproxy 佈署若重跑到這台
   一樣會炸，不是 Galera 專屬問題）；修正為在 `.20` 上額外裝 python3.12（不動
   既有 python3.6），`ansible/inventory/vm3.ini` 改指到新版本。
5. `tests/common/prepare.sh` 的 shard-count hard gate（§8）原本沒有 `galera`
   分支，`vm-3node-haproxy-3s3r` 的 `EXPECTED_SHARDS=3`（沿用其他三家的拓樸
   對照表）會導致 Galera 每張表 `actual=0 < expected=3` 誤判為 shard 沒生效
   而 fail-closed——修正為 Galera 強制 `EXPECTED_SHARDS=0`（無 shard 概念）。
6. `tests/common/coldreset-galera.sh` 原本只認 `CLUSTER_HOSTS` 環境變數
   （crossregion 專用）或退化成單台 `$DB_HOST`——`vm-3node-haproxy-3s3r` 的
   `$DB_HOST` 是 HAProxy IP（無 mysqld 可重啟），修正為加 fallback：非
   `.32/.33/.34` 的 `$DB_HOST` 一律 rolling-restart 全部 3 台真實節點。
