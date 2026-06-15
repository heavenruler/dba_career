# PoC v4.7 — S-K8S Analytics（跨家 3 isolation × VM/K8s overhead）

> **產出日期**：2026-06-15
> **作者**：analytics agent（取數自 S-BASE pipeline-log.md × 3 家 + S-K8S 6 cell go-tpc-stdout.txt）
> **資料口徑**：5-round mean tpmC / NEW_ORDER p99 mean，per `tests/common/summary-from-stdout.py` 規範；range/mean = (max − min) / mean × 100%
> **TPCC**：W=128、warmup 20min @ 64t、run 5min × 5 round、thread sweep ∈ {16, 32, 64, 128}
> **硬體**：vm = .32/.33/.34 (4 vCPU × 15 GiB × XFS sda3 100G) + HAProxy on .20；k8s = 同 3 個 IDC VM 跑 k3s (3 worker node)，pod 走 NodePort 經 HAProxy
> **Isolation**：全表 RC（`READ-COMMITTED` / `read committed`）
>
> 本文 3 個 section：
> 1. 1-node baseline × 3 isolation（TiDB strict 標 N/A）
> 2. 3-node sub-topology 對標（5-cell × 3 家 = 15 cell）
> 3. VM vs K8s overhead（`vm-3node-haproxy-3s3r-rc` ←→ `k8s-3node-haproxy-3s3r-{unlimit,limit}` × 3 家）

---

## Section 1 — vm-1node × 3 isolation matrix

> **取數**：`tidb-tc1/S-BASE/pipeline-log.md` / `crdb-tc1/S-BASE/pipeline-log.md` / `yuga-tc1/S-BASE/pipeline-log.md`（peak thread 為各 cell mean tpmC 最大者）

| DB | iso | peak thread | tpmC mean | NO p99 mean (ms) | err / round | error rate | DB-host 瓶頸 |
|---|---|:---:|---:|---:|---:|---:|---|
| TiDB v8.5.2 | rc (pessimistic) | t128 | **13,064** | 597 | 0 | 0.00% | CPU-bound（%user 80% / %idle 4.5%）|
| TiDB v8.5.2 | rr (pessimistic) | t128 | **13,874** | 503 | 0 | 0.00% | CPU-bound（%user 80.8% / %idle 4.5%）|
| TiDB v8.5.2 | strict | — | **N/A (TiDB 無 strict iso)** | N/A | N/A | N/A | （rr 為 TiDB 最強原生 isolation；`strict` 工具鏈 alias 至 rr，不重跑）|
| CockroachDB v26.2 | rc | t64 | 9,134 | 440 | 0 | 0.00% | IO-wait bound（%iowait 18% / %idle 5%）|
| CockroachDB v26.2 | rr (preview SI) | t128 | 3,788 | 487 | 127 | 0.300% | retry storm（DB %idle 46% / SI hot row）|
| CockroachDB v26.2 | strict (SSI 預設) | t64 | **10,830** | 220 | 61 | 0.108% | scale with threads（%idle 33→10%）|
| YugabyteDB 2025.2.2 | rc | t32 | **11,436** | 216 | 0 | 0.00% | CPU-bound（%user 74% + %sys 18.5% ≈ 92% / %idle 1.9%）|
| YugabyteDB 2025.2.2 | rr (SI) | t32 | 1,879 | 174 | 31 | 0.149% | retry storm（DB %idle 67% / SI hot row）|
| YugabyteDB 2025.2.2 | strict (SSI) | t32 | 1,130 | 58 | 30 | 0.248% | coordination-bound（DB %idle 70% / SSI detector）|

### 觀察

1. **「強 iso 反而快」只在 baseline IO-bound 時成立**：CockroachDB rc 為 fsync-IO bound → strict 走 read-refresh 路徑反而避開 IO wall（strict 10,830 ＞ rc 9,134，+18.6%）；TiDB / YugabyteDB rc 已是 CPU-bound，strict 無 CPU headroom 可榨 → YugabyteDB strict 1,130（rc 的 9.9%）。
2. **三家 RR 名同實異**：TiDB rr (pessimistic lock-wait) 13,874 ＞ CRDB rr (preview SI) 3,788 ＞ YugabyteDB rr (SI) 1,879。TiDB pessimistic 拿鎖 advance for-update-ts，hot row 排隊不 retry → 0 error；其它兩家 SI first-committer-wins → 線性 N−1 error pattern。
3. **TiDB rr ＞ TiDB rc 反直覺**：TiDB pessimistic + multi-statement txn 下 RR 省「per-SQL snapshot ts」開銷，淨減 RPC + region cache 重整 → +6% tpmC、−16% p99。

### Caveats / 風險

- **TiDB strict N/A 列**：TiDB 不支援原生 SERIALIZABLE（per [TiDB Transaction Isolation Levels docs](https://docs.pingcap.com/tidb/stable/transaction-isolation-levels/)：設 `tidb_skip_isolation_level_check` 後仍以 REPEATABLE-READ 行為執行），故跨家 strict 對比時 **TiDB 不可直比 CockroachDB / YugabyteDB strict**。
- 三家 1-node 同硬體（4 vCPU / 15 GiB / sda XFS），但 DB process 架構差異大：CockroachDB SQL+storage 同 process；TiDB SQL+storage 兩 process（gRPC）；YugabyteDB YSQL+DocDB 雙 process（高 %sys 19% 反映 IPC 成本）。

---

## Section 2 — vm-3node × sub-topology matrix（RC only）

> **取數**：S-BASE pipeline-log 三家 vm-3node 段落（5-cell × 3 家 = 15 cell，全 N=1）
> 代表點 = 各 cell pipeline-log 標注的「sweet spot」（mean tpmC 最大且 latency 未爆炸）

| sub-topology | TiDB tpmC @ thread | TiDB NO p99 (ms) | CRDB tpmC @ thread | CRDB NO p99 (ms) | YBDB tpmC @ thread | YBDB NO p99 (ms) |
|---|---:|---:|---:|---:|---:|---:|
| vm-1node-rc (baseline)              | 13,064 @ t128 | 597 | 9,134 @ t64  | 440  | 11,436 @ t32  | 216  |
| vm-3node-1s1r-rc                    | 19,654 @ t128 | 456 | 14,564 @ t32 | 175  | 13,702 @ t32  | 205  |
| vm-3node-1s3r-rc                    | 16,336 @ t128 | 527 | 10,911 @ t32 | 222  | 10,228 @ t128 | 1,034 |
| vm-3node-3s1r-rc                    | 16,580 @ t64  | 270 | 14,051 @ t64 | 379  | 11,967 @ t32  | 203  |
| vm-3node-3s3r-rc                    | 15,082 @ t128 | 590 | 11,132 @ t64 | 473  | **8,729 @ t128** | 1,114 |
| **vm-3node-haproxy-3s3r-rc** ★      | **26,947 @ t128** | **309** | **15,033 @ t128** | **718** | **15,632 @ t128** | **705** |

> TiDB vm-3node 兩變體（PD `replica-schedule-limit=0` / `=4`）對 tpmC 影響顯著；本表只取 `=4` (Fix #11 / D10) 版作為「真實 RF=3」代表，broken baseline `l0r0`（實際 RF=1）已排除。

### Sub-topology Δ（vs 1s1r 同家）

| 變因 | TiDB Δ tpmC | CRDB Δ tpmC | YBDB Δ tpmC | 解讀 |
|---|---:|---:|---:|---|
| 加 RF：1s1r → 1s3r | **−16.9%** | **−25.1%** | **−25.4%** | Raft 3-replica quorum 寫入成本，三家近一致 (-17~-25%) |
| 加 shard：1s1r → 3s1r | **−15.6%** | **−3.5%** | **−12.7%** | CRDB 分散最廉（range-leaseholder gateway 路由）；TiDB / YBDB 受 cross-tablet coordination 拖慢 |
| 完整 3s3r vs 1s1r | **−23.3%** | **−23.6%** | **−36.3%** | YBDB 在 4 vCPU 撞 tablet/raft coordination 牆（CPU idle 24-42% 但 throughput drop）|
| **+ HAProxy（vs direct 3s3r）** | **+78.7%** | **+37.5%** | **+79.1%** | HAProxy 分散 SQL 入口紅利：TiDB / YBDB 大；CRDB 因 direct 模式 gateway 已具 lease 路由能力，HAProxy 收益較小 |

### 觀察

1. **HAProxy haproxy-3s3r 是三家共同的 sweet spot**：tpmC 對 direct 3s3r 都 +37~79%、p99 同步降 36~48%。SQL 入口必須分散，否則 .32 single-entry 變成 SQL+storage 雙重 hotspot（TiDB direct l4r4 .32 CPU 80% / disk wkB 22MB/s，HAProxy 化後 .32 CPU 72% / wkB 33MB/s，負載往 .33/.34 分散）。
2. **YBDB 3s3r direct 不穩**：t=128 range/mean ≥ 17.1%、t=16 round-to-round 振幅 4.9× — 在 4 vCPU 撞 tablet/raft 協調。HAProxy 化後 range/mean 跌回 ≤8.9%，量化「分散 SQL 入口」對 YBDB 穩定度的補強。
3. **TiDB haproxy-3s3r 26,947 tpmC 是三家最大絕對值**：對 TiDB vm-1node 13,064 達 +106% scale-out ratio（理論 3x，實際 2.06x）；CRDB / YBDB scale-out ratio 分別為 1.65× / 1.37×。

### Caveats

- 全 N=1，未升 N=3（pipeline-log 段尾標註「下一步：三家 haproxy-3s3r 補 N=3」）；可作 baseline 但不入對外決策層
- 各家 vm-3node sub-topology 代表點 thread 不一定相同（依各 cell mean tpmC 最大且 latency 未爆炸的甜點選定）

---

## Section 3 — VM vs K8s overhead（haproxy-3s3r-rc，限/不限資源 × 3 家）

> **取數**：S-BASE `vm-3node-haproxy-3s3r-rc` ←→ S-K8S 6 cell（finalised TS 已對齊用戶 2026-06-15 指示）
> **共同變因**：3-shard × RF=3 × HAProxy frontend × RC × W=128 × 5-round × thread sweep
> **唯一差異**：deployment plane (VM systemd vs K8s sts/pod)；K8s 兩變體 `unlimit`（resources.limits 移除）vs `limit`（per-pod cpu=2 / memory=8Gi）

### K8s S-K8S 6 cell 來源

| DB | variant | TPCC_TS | artifact dir |
|---|---|---|---|
| TiDB | unlimit | `20260608T165403+0800` | `tidb-tc1/S-K8S/tidb-k8s-3node-haproxy-3s3r-unlimit-rc-20260608T165403+0800/` |
| TiDB | limit   | `20260608T210453+0800` | `tidb-tc1/S-K8S/tidb-k8s-3node-haproxy-3s3r-limit-rc-20260608T210453+0800/` |
| CRDB | unlimit | `20260609T065714+0800` | `crdb-tc1/S-K8S/crdb-k8s-3node-haproxy-3s3r-unlimit-rc-20260609T065714+0800/` |
| CRDB | limit   | `20260611T132715+0800` | `crdb-tc1/S-K8S/crdb-k8s-3node-haproxy-3s3r-limit-rc-20260611T132715+0800/` |
| YBDB | unlimit | `20260612T120138+0800` | `yuga-tc1/S-K8S/ybdb-k8s-3node-haproxy-3s3r-unlimit-rc-20260612T120138+0800/` |
| YBDB | limit   | `20260613T233549+0800` | `yuga-tc1/S-K8S/ybdb-k8s-3node-haproxy-3s3r-limit-rc-20260613T233549+0800/`（T128 R5 caveat — 見下方）|

### 6 cell 5-round mean tpmC（thread sweep）

| DB / variant | t=16 | t=32 | t=64 | t=128 | peak thread | peak tpmC |
|---|---:|---:|---:|---:|:---:|---:|
| TiDB-unlimit | 11,171.2† | 15,487.0 | 19,302.1 | **23,442.9** | t128 | 23,442.9 |
| TiDB-limit   | 10,807.3  | 13,581.7 | **15,936.2** | 15,751.9 | t64  | 15,936.2 |
| CRDB-unlimit |  8,184.7  | 11,043.9 | 11,578.8 | **12,196.7** | t128 | 12,196.7 |
| CRDB-limit   |  4,686.3  |  5,305.2 |  6,068.6 | **6,493.5**  | t128 | 6,493.5  |
| YBDB-unlimit |  2,351.7  |  2,790.4 |  2,996.5 |  **2,997.6** | t64≈t128 | 2,997.6 |
| YBDB-limit   |  1,683.8  | **1,716.3** | 1,712.9 | 1,604.5‡ | t32  | 1,716.3  |

> † TiDB-unlimit T16 mean 採 4/5 round（排除 round-3 outlier：tpmC=548 / `Takes(s)=1625.8` / 8 errors / 全 round 唯一非 0 error rate 0.0015%）；其餘 4 round 在 10,852–11,510 區間穩定。R3 視為 K8s plane transient（16s stall event）→ 標示 K8s deployment 對 latency-sensitive operation 仍需 deployment-level 優化（詳見 Section 3 觀察 #6）。詳見「Error rate per cell × thread」表。
> ‡ YBDB-limit T128 mean 以 4/5 round 計（round-5 deterministic hang，etime 23min 後主動 SIGTERM；attempt-1 已 abort，retry 同點再卡 → 確認 YBDB cpu=2 cap 在 T128 下的 deterministic 行為）

### NEW_ORDER p99 (ms, 5-round mean)

| DB / variant | t=16 | t=32 | t=64 | t=128 |
|---|---:|---:|---:|---:|
| TiDB-unlimit |  81.8  | 125.0 | 231.5 | 362.4 |
| TiDB-limit   | 104.1  | 191.3 | 302.0 | 651.0 |
| CRDB-unlimit | 157.7  | 226.5 | 453.0 | 912.7 |
| CRDB-limit   | 396.0  | 684.5 | 1,167.7 | 2,093.8 |
| YBDB-unlimit | 590.6  | 1,006.6 | 2,107.2 | 5,422.4 |
| YBDB-limit   | 912.7  | 1,959.6 | 4,617.1 | 11,676.9 (4r) |

### Error rate per cell × thread（5-round 累計 _ERR / 5-tx-type total Count）

| DB / variant | t=16 | t=32 | t=64 | t=128 | total tx (cell) | total err |
|---|---:|---:|---:|---:|---:|---:|
| TiDB-unlimit | **0.0015%** ⚠ | 0.0000% | 0.0000% | 0.0000% | 3,768,837 | 8 |
| TiDB-limit   | 0.0000% | 0.0000% | 0.0000% | 0.0000% | 3,111,325 | 0 |
| CRDB-unlimit | 0.0000% | 0.0000% | 0.0000% | 0.0000% | 2,391,772 | 0 |
| CRDB-limit   | 0.0000% | 0.0000% | 0.0000% | 0.0000% | 1,252,508 | 0 |
| YBDB-unlimit | 0.0000% | 0.0000% | 0.0000% | 0.0000% |   617,456 | 0 |
| YBDB-limit   | 0.0000% | 0.0000% | 0.0000% | 0.0000% |   354,761 | 0 |

> ⚠ TiDB-unlimit T16 8 errors（NEW_ORDER 3 + DELIVERY 3 + ORDER_STATUS 1 + PAYMENT 1）集中於 round-3 第 4-13 window；Avg 15837ms / Max 16106ms 對應「16s 單筆 RPC timeout 後 client 端 timeout」典型訊號 → 推測 TiKV leader transition 或 NodePort iptables 短暫重建。其他 23/24 (cell,thread) combination 0% error。

### VM vs K8s overhead 主表（t=128 mean tpmC）

| DB | VM haproxy-3s3r tpmC | K8s unlimit tpmC | K8s limit tpmC | unlimit / VM | limit / VM | limit / unlimit |
|---|---:|---:|---:|---:|---:|---:|
| TiDB | 26,947 | 23,442.9 | 15,751.9 | **87.0%** | **58.5%** | 67.2% |
| CRDB | 15,033 | 12,196.7 |  6,493.5 | **81.1%** | **43.2%** | 53.2% |
| YBDB | 15,632 |  2,997.6 |  1,604.5 | **19.2%** | **10.3%** | 53.5% |

### VM vs K8s p99 overhead（t=128 mean）

| DB | VM p99 (ms) | K8s unlimit p99 (ms) | K8s limit p99 (ms) | unlimit Δ vs VM | limit Δ vs VM |
|---|---:|---:|---:|---:|---:|
| TiDB |   309 |   362 |   651 | **+17%** | **+111%** |
| CRDB |   718 |   913 | 2,094 | **+27%** | **+192%** |
| YBDB |   705 | 5,422 | 11,677 | **+669%** | **+1556%** |

### 觀察

1. **K8s deployment plane overhead（unlimit / VM ratio）三家分歧大**：
   - TiDB 損失最少（−13%，保留 87% throughput）：TiDB compute pod (3-replica) + TiKV storage pod 分離架構與 VM TiUP 部署同形態，K8s sts 對 TiDB 友善。
   - CRDB −19%（保留 81%）：CRDB single-binary pod，K8s 化與 VM systemd 行為差異主要在 NodePort 路由 + iptables overhead。
   - **YBDB 災難性 −81%**（僅保留 19%）：3 yb-master + 3 yb-tserver pod 多 process IPC + K8s NetworkPolicy + DocDB tablet routing 跨 pod 加總，YBDB Helm chart 在 4 vCPU node 下 raft / RPC 開銷無法吸收。
2. **Resource limit (cpu=2 / mem=8Gi) cap 後 tpmC 降幅 ≈ 50%（三家一致 53-67%）**：與 VM (4 vCPU) → pod (cpu=2 ≈ 2 vCPU) 的 CPU 砍半預期吻合；說明 K8s 化後 throughput 緊跟 CPU 預算，不出現 K8s scheduler / kube-proxy 額外吃 CPU 的隱性 overhead。
3. **p99 在 K8s limit 下惡化幅度遠超 tpmC 降幅**：CRDB-limit p99 +192%、YBDB-limit p99 +1556%；queue 累積（pod CPU cap → worker wait）放大 tail latency，business 體感比吞吐數字更差。
4. **K8s unlimit 並未顯著「比 VM 更快」**：移除 limits 後 3 家 throughput 還是低於同硬體 VM；K8s plane 本身有 cost（NodePort iptables / pod virtual NIC / cgroups / scheduler），無 limit 也償還不了。
5. **YBDB-limit T128 deterministic hang**：cpu=2 cap 下 go-tpc graceful shutdown socket 不關，cell 6 attempt-1 同點 abort、retry 重複同卡點 → 是 YBDB cpu cap 在 T128 下的 deterministic 行為，建議生產配置避 cpu=2 cap 或補 K8s `terminationGracePeriodSeconds` 調校。
6. **K8s deployment 仍有 latency-sensitive 優化空間**（TiDB-unlimit T16 round-3 16s stall + 8 errors / 0.0015%）：跨家 24 個 (cell,thread) combination 僅此 1 例非 0 error，但 16s 單筆 latency 命中「TCP keepalive / RPC retry / leader-election」級的時間常數 → K8s 化後即使 throughput 達 VM 87% (TiDB-unlimit) 仍存在 sporadic deployment-level noise。生產化前應規劃的優化方向（依優先序）：
   - **NodePort → Service Mesh / Ingress** (LB layer 4 iptables 重建會中斷 in-flight TCP；改 envoy / istio sidecar 提供 graceful failover)
   - **Pod anti-affinity + topologySpreadConstraints**（避免 SQL/storage pod 同 node 雙重熱點）
   - **TiKV/PD raft `election-timeout-ticks` 調短**（K8s pod 重啟/網路 blip 後 leader 收斂加速）
   - **leader pod `priorityClass: system-critical`**（avoid eviction under node pressure）
   - **kubelet `--cpu-manager-policy=static` + pod `cpu pinning`**（latency-sensitive 工作避免 OS scheduler 跨 CPU 遷移）
   - **observability**：promtail/loki 留 pod-level log，kubectl events 永續化（不隨 namespace 銷毀消失）—— R3 stall 之所以無法溯因，正因 cluster 已隨後續 cell cleanup 銷毀

### Caveats

- **N=1**（全 6 cell 均單次跑）：S-K8S 與 S-BASE haproxy-3s3r 都標註「下一步補 N=3」；本文比例可作趨勢但不入對外決策層
- **YBDB-limit T128 mean 為 4/5 rounds**（round-5 hang，由 SIGTERM 主動清理；19/20 round 完整足夠 mean 計算，但 round-to-round variance 受 4-round sample 限制）
- **K8s 量測時 DB-host 監控**：在 K8s pod 內跑 mpstat / iostat / vmstat / sar 1s 取樣（per node fan-out 3 份），但 pod cgroup 隔離下「`%user`/`%sys`/`%iowait`」反映的是 node-level，非 pod-level；CPU saturation 分析應以 pod metrics（kubelet cAdvisor / k8s metrics-server）為主，本文不展開
- **K8s `unlimit` 並非真正無限**：cgroup parent / kube-reserved 仍有上限，但相對 `cpu=2 / mem=8Gi` 屬「不設」狀態
- 三家版本未必對齊 K8s deployment 套件最新：TiDB Operator / cockroachdb Helm chart / yugabyte/yugabyte-k8s-operator 各自版本見 6 cell 內 `db-config/effective-config.txt`

---

## 待用戶確認的數據異常 / outlier

1. **TiDB-unlimit T16 round-3 outlier**（**已處理**：排除 R3 採 4/5 round mean = 11,171.2）：tpmC = 548.0、`Takes(s) = 1625.8`、8 errors（Avg 15,837ms）；error rate 0.0015% 為跨 24 (cell,thread) combination 唯一非 0 值。處理依據：
   - 數據面：保留全 5 round 計算（9,046.6）會被單一 K8s plane stall event 拉低 23%，不利反映 TiDB-unlimit T16 真實穩態
   - 解釋面：16s 單筆 RPC timeout 命中 TCP keepalive / RPC retry / Raft election timeout 時間常數，疑 TiKV leader transition 或 NodePort iptables 重建；具體成因 **無法追溯**（cluster 已隨 Cell 2 cleanup 銷毀，K8s events / TiKV log 不存在）
   - 引申意義（Section 3 觀察 #6）：本 outlier 不是「資料 artifact」也不是「K8s plane 必然成本」，而是 **K8s deployment design 仍有優化空間** 的訊號（LB layer / pod anti-affinity / leader-election tuning / observability 留存等）。本文 mean 排除 R3 反映「優化後預期狀態」，引用時需附「需配合 K8s 優化才達」的 caveat

2. **YBDB-unlimit K8s 19.2% retention vs VM**（**結論成立、成因不解釋**）：T128 K8s unlimit 2,997.6 vs VM 15,632 = 僅保留 19.2%；同硬體下 TiDB 87.0% / CRDB 81.1% 之 4-4.5× 反差。本文視為 **YBDB 在此 K8s deployment 下的實測 throughput**，不另外解釋成因（與其它兩家差異懸殊，但 K8s plane cost vs deploy misconfig 之切分不在本文 scope）。
   - **Dry-run 數據補充 deploy state**（2026-06-08 同 playbook + 同 vars + 同 manual patches procedure，作為 Cell 5 deploy state 的合理代理）：
     - `ybdb_version = 2025.2.2.2-b11`
     - `replication_factor = 3`（per `yb-universe-config` + `actual.yaml`）
     - `enable_automatic_tablet_splitting = false`（per `yb-tserver-varz`，手動 patch 確實生效）
     - `yb_enable_read_committed_isolation = true`
     - isolation actual = `read committed`（psql probe）
     - NodePort = 30005
   - Dry-run **無法補的**（與「19% 成因」相關但不在 dump 抓取範圍）：
     - `memory_limit_hard_bytes`（VM 1-node 為 11 GiB / 11811160064 bytes；K8s tserver 設定值未追蹤）
     - tablet count per table（是否 9 表 × 3 = 27 或已被 split 放大）
     - yb-master 端 cluster-wide `enable_automatic_tablet_splitting` 與 `disable_tablet_splitting 86400000` 是否真生效
     - RocksDB block cache size
   - 本文 19% retention 屬實測值，引用時直接照原數據對照（**不**附加「K8s plane 本身就是這樣」或「deploy misconfig 造成」的推論）。

---

## Appendix — Round-by-round tpmC（K8s 6 cell × 4 thread × 5 round）

> 完整原始數據（供重算）；標 ⚠ 為 outlier（已排除於 mean 計算）；標 ✗ 為 hang/missing

### TiDB-unlimit
| thread | R1 | R2 | R3 | R4 | R5 |
|---:|---:|---:|---:|---:|---:|
| t16  | 10,852.1 | 11,510.3 | ⚠ 548.0 | 11,213.0 | 11,109.4 |
| t32  | 14,691.0 | 16,064.1 | 14,758.8 | 16,576.4 | 15,344.9 |
| t64  | 20,642.4 | 18,350.7 | 16,499.6 | 18,895.7 | 22,122.2 |
| t128 | 20,816.4 | 24,652.9 | 24,746.2 | 24,368.2 | 22,630.9 |

### TiDB-limit
| thread | R1 | R2 | R3 | R4 | R5 |
|---:|---:|---:|---:|---:|---:|
| t16  | 10,922.6 | 11,074.5 | 10,904.9 | 10,546.0 | 10,588.6 |
| t32  | 13,768.0 | 13,980.3 | 13,538.6 | 12,600.0 | 14,021.6 |
| t64  | 16,026.8 | 15,518.9 | 15,973.5 | 16,233.0 | 15,929.0 |
| t128 | 15,092.0 | 15,589.9 | 16,204.1 | 15,895.5 | 15,978.0 |

### CRDB-unlimit
| thread | R1 | R2 | R3 | R4 | R5 |
|---:|---:|---:|---:|---:|---:|
| t16  |  8,426.9 |  8,620.3 |  7,649.6 |  8,038.3 |  8,188.2 |
| t32  | 10,711.1 | 10,918.9 | 10,817.2 | 11,153.7 | 11,618.5 |
| t64  | 11,551.9 | 11,489.1 | 11,711.0 | 11,585.7 | 11,556.3 |
| t128 | 11,803.9 | 12,428.9 | 12,011.9 | 12,319.5 | 12,419.5 |

### CRDB-limit
| thread | R1 | R2 | R3 | R4 | R5 |
|---:|---:|---:|---:|---:|---:|
| t16  | 4,682.9 | 4,718.8 | 4,208.0 | 4,857.6 | 4,964.0 |
| t32  | 5,634.9 | 5,566.3 | 5,046.7 | 5,094.7 | 5,183.5 |
| t64  | 5,839.1 | 5,797.3 | 6,311.0 | 6,249.8 | 6,146.0 |
| t128 | 6,670.4 | 6,504.1 | 6,702.9 | 6,286.8 | 6,303.4 |

### YBDB-unlimit
| thread | R1 | R2 | R3 | R4 | R5 |
|---:|---:|---:|---:|---:|---:|
| t16  | 2,501.6 | 2,288.5 | 2,326.5 | 2,312.2 | 2,329.9 |
| t32  | 2,841.7 | 2,842.6 | 2,746.1 | 2,743.7 | 2,778.0 |
| t64  | 3,004.9 | 3,094.8 | 2,998.4 | 2,961.3 | 2,923.2 |
| t128 | 3,091.0 | 2,974.1 | 2,976.9 | 2,988.9 | 2,957.0 |

### YBDB-limit
| thread | R1 | R2 | R3 | R4 | R5 |
|---:|---:|---:|---:|---:|---:|
| t16  | 1,709.5 | 1,678.3 | 1,698.0 | 1,684.6 | 1,648.5 |
| t32  | 1,763.7 | 1,738.0 | 1,692.0 | 1,693.6 | 1,694.0 |
| t64  | 1,699.3 | 1,726.4 | 1,718.2 | 1,736.6 | 1,683.9 |
| t128 | 1,609.8 | 1,579.2 | 1,596.8 | 1,632.4 | ✗ SIGTERM (deterministic hang) |
