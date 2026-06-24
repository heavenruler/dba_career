# TiDB TPC-C Pipeline Log — tidb-tc1 / S-K8S

> 本檔僅紀錄 **S-K8S**（Kubernetes 部署平面）TiDB 對照數據；VM baseline 在 [`../S-BASE/pipeline-log.md`](../S-BASE/pipeline-log.md)、跨家對比在 [`1_MeetingMinutes/analytics-S-K8S-2026-06-15.md`](../../../1_MeetingMinutes/analytics-S-K8S-2026-06-15.md)。
> 取數口徑一律為各 suite 的 `summary.json`（由 [`tests/common/summary-from-stdout.py`](../../../tests/common/summary-from-stdout.py) 從 `runs/threads-*/round-*/go-tpc-stdout.txt` 解析）。

---

## TL;DR — 兩個 Kubernetes resource variant 完成

**核心結論**：同硬體（3 IDC 節點 × TiKV/PD/TiDB Pod 各 1）下，K8s `unlimit` 對 VM baseline 保留 **87.0 %** tpmC、p99 +17.4 %；加上 cpu=2 / mem=8Gi 限額後 `limit` 只剩 **58.5 %** tpmC、p99 +110.9 %。

### t=128 mean tpmC 排行（W=128，NEW_ORDER）

| 排名 | variant | tpmC | NO p99 (ms) | err | range/mean | 有效 rounds |
|---|---|---:|---:|---:|---:|:---:|
| 🥇 | VM HAProxy 3s3r (S-BASE 對照) | **26,947** | 309 | 0.0% | 7.4% | 5 |
| 🥈 | K8s [`unlimit`](#k8s-unlimit-rc無顯式-kubernetes-resource-limits) RC | **23,443** | 362 | 0.0% | 16.8% | 5 |
| 🥉 | K8s [`limit`](#k8s-limit-rckubernetes-resource-limits) RC | **15,752** | 651 | 0.0% | 7.1% | 5 |

### 三大觀察

1. **K8s 部署層額外開銷 ≈ 13 %**：unlimit 相對 VM tpmC 保留 87.0 %、latency 增幅 1.16-1.17×。差距來自 pod network（CNI overlay + iptables hop）+ cgroup parent + kube-reserved，非 TiDB binary 本身。
2. **Resource limit 把 t=128 cell 砍到反曲**：limit t=128 mean tpmC = 15,751.9，**低於同 case t=64 mean = 15,936.2**；cpu=2 飽和後加 thread 只是排隊。limit cell 的真實峰值 thread 是 **t=64**，不是 t=128。
3. **unlimit cell 5 rounds 仍偏抖動**：t=128 range/mean = 16.8 %（r1=20,816 顯著低於 r2-r5 的 24,369-24,746），t=64 更達 29.1 %、t=16 含 outlier 121.2 %。limit cell 反而穩（t=128 range/mean=7.1 %），符合「資源限額抑制 noise」直覺。對外引用 unlimit 前建議補一次 sweep 或排除 r1。

---

## 1. Adopted cases

| variant | TPCC_TS | suite path | markers | summary.json |
|---|---|---|---|---|
| K8s [`unlimit`](#k8s-unlimit-rc無顯式-kubernetes-resource-limits) RC | 20260608T165403+0800 | [`tidb-k8s-3node-haproxy-3s3r-unlimit-rc-20260608T165403+0800/`](./tidb-k8s-3node-haproxy-3s3r-unlimit-rc-20260608T165403+0800/) | `.suite.done` + `.collect.done` | ✅ retrofit 2026-06-23 |
| K8s [`limit`](#k8s-limit-rckubernetes-resource-limits) RC | 20260608T210453+0800 | [`tidb-k8s-3node-haproxy-3s3r-limit-rc-20260608T210453+0800/`](./tidb-k8s-3node-haproxy-3s3r-limit-rc-20260608T210453+0800/) | `.suite.done` + `.collect.done` | ✅ retrofit 2026-06-23 |

排除：

| variant | TPCC_TS | 原因 |
|---|---|---|
| K8s unlimit RC | 20260608T013543+0800 | `.dry-run.done` only，dry-run 不入數據表 |
| K8s limit RC | 20260608T084259+0800 | `.dry-run.done` only，dry-run 不入數據表 |

---

## 2. Execute 結果總覽（S-K8S 2 variants）

> 口徑對齊 S-BASE：代表點採各 resource variant 的主要觀察併發；完整 per-round thread sweep 見各 variant 的 `Thread sweep` 表。p99 為 NEW_ORDER 5-round latency mean；err 為 all transaction error rate。S-K8S 目前只有 `READ COMMITTED`，拓樸皆為 `k8s-3node-haproxy-3s3r`。

| variant | resource profile | TPCC_TS | 代表併發 | tpmC mean | range/mean | NO p99 mean (ms) | err | N | 判讀 |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| [`unlimit`](#k8s-unlimit-rc無顯式-kubernetes-resource-limits) | 無顯式 Kubernetes resource limits | [`20260608T165403`](./tidb-k8s-3node-haproxy-3s3r-unlimit-rc-20260608T165403+0800/) | 128 | 23,443 | 16.8% | 362 | 0.000% | 1 | 相對 VM HAProxy baseline 保留 87.0% tpmC |
| [`limit`](#k8s-limit-rckubernetes-resource-limits) | Kubernetes resource limits | [`20260608T210453`](./tidb-k8s-3node-haproxy-3s3r-limit-rc-20260608T210453+0800/) | 128 | 15,752 | 7.1% | 651 | 0.000% | 1 | cpu=2 / mem=8Gi；t64 才是 throughput peak |

---

## 3. Thread sweep（主表取自 summary.json）

### k8s-unlimit-rc（無顯式 Kubernetes resource limits）

> tpmC / latency / error rate 皆取自 [`summary.json`](./tidb-k8s-3node-haproxy-3s3r-unlimit-rc-20260608T165403+0800/summary.json)；p50 / p95 / tpmTotal / efficiency 補充見 `summary.json`。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 10,852 | 11,510 | 548 | 11,213 | 11,109 | 9,047 | 121.2% | 81 | 0.001% |
| 32 | 14,691 | 16,064 | 14,759 | 16,576 | 15,345 | 15,487 | 12.2% | 125 | 0.000% |
| 64 | 20,642 | 18,351 | 16,500 | 18,896 | 22,122 | 19,302 | 29.1% | 232 | 0.000% |
| 128 | 20,816 | 24,653 | 24,746 | 24,368 | 22,631 | **23,443** | 16.8% | 362 | 0.000% |

† t=16 含 round-3 outlier（tpmC=548，疑似 prepare 殘餘或 warmup 異常）；range/mean 121.2 % 由此放大。analytics 報告採 4/5 round mean (11,171.2)，本表保留 5/5 raw。

### k8s-limit-rc（Kubernetes resource limits）

> tpmC / latency / error rate 皆取自 [`summary.json`](./tidb-k8s-3node-haproxy-3s3r-limit-rc-20260608T210453+0800/summary.json)；p50 / p95 / tpmTotal / efficiency 補充見 `summary.json`。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 10,923 | 11,074 | 10,905 | 10,546 | 10,589 | 10,807 | 4.9% | 104 | 0.000% |
| 32 | 13,768 | 13,980 | 13,539 | 12,600 | 14,022 | 13,582 | 10.5% | 191 | 0.000% |
| 64 | 16,027 | 15,519 | 15,974 | 16,233 | 15,929 | **15,936** | 4.5% | 302 | 0.000% |
| 128 | 15,092 | 15,590 | 16,204 | 15,896 | 15,978 | 15,752 | 7.1% | 651 | 0.000% |

### limit 反曲解讀

t=64 → t=128：thread ×2，tpmC −1.2 %、p95 ×2.17、p99 ×2.16。`cpu=2` cap 下 TiDB pod CPU 早已飽和；加 thread 只增加排隊深度，throughput 不漲、latency 倍增。**limit cell 對外引用建議用 t=64 而非 t=128**，否則低估限額能力。

---

## 4. VM baseline 對標（t=128，NEW_ORDER）

公式：retention = K8S / VM；Δ = K8S / VM − 1。

| 對照 | tpmC retention | NO p99 Δ | error-rate Δ |
|---|---:|---:|---:|
| unlimit / VM | **87.0 %** | +17.4 % | 0.0 pp |
| limit / VM | **58.5 %** | +110.9 % | 0.0 pp |
| limit / unlimit | 67.2 % | +79.6 % | 0.0 pp |

VM baseline 數值：tpmC 26,946.7 / p95 231.5 / p99 308.7 / err 0.0 %，來自 `../S-BASE/vm-3node-haproxy-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-haproxy-3s3r-rc-20260601T003316+0800/summary.json`。

---

## 5. Caveats / 未補項

- S-K8S 與 S-BASE 屬不同 baseline family（k8s vs vm）；retention 僅量化部署平面開銷，不可與 vm 系列同表排名。
- unlimit cell 5 rounds 仍偏抖（range/mean t=64=29.1 %、t=128=16.8 %）。對外引用前建議：
  - 補一次 5-round sweep 並排除 r1，或
  - 提升 N=10 收斂 CV ≤ 5 %。
- DB-host metrics 已收齊 `runs/threads-128/round-*/free-1m / iostat / mpstat / sar-net / vmstat`；本檔未對 CPU/IO 飽和作推論。
- 「unlimit」並非 cgroup 真正無限：parent cgroup / kube-reserved 仍有上限，僅相對 `cpu=2/mem=8Gi` 而言為「未顯式 limit」。

---

## 6. 變更紀錄

- **2026-06-23**：retrofit `summary.json` 至兩個 suite-done case（呼叫 `tests/common/summary-from-stdout.py`）；建立本 `pipeline-log.md`。在此之前數字僅在 `1_MeetingMinutes/analytics-S-K8S-2026-06-15.md`，pipeline 上下游若依 `summary.json` 自動匯整會 missing source — 本次補齊。
