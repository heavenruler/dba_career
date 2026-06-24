# YugabyteDB TPC-C Pipeline Log — yuga-tc1 / S-K8S

> 本檔僅紀錄 **S-K8S**（Kubernetes 部署平面）YugabyteDB 對照數據；VM baseline 在 [`../S-BASE/pipeline-log.md`](../S-BASE/pipeline-log.md)。取數口徑一律為各 suite 的 `summary.json`（由 [`tests/common/summary-from-stdout.py`](../../../tests/common/summary-from-stdout.py) 從 `runs/threads-*/round-*/go-tpc-stdout.txt` 解析）。

---

## TL;DR — 兩個 Kubernetes resource variant 完成

**核心結論**：YugabyteDB 在 S-K8S 3-node HAProxy 3s3r RC 下，t=128 相對 VM HAProxy baseline 只保留 **19.2%**（unlimit）與 **10.3%**（limit）tpmC；tail latency 放大明顯，unlimit p99 +669.6%，limit p99 +1557.2%。limit case 的 t128 round 5 為 partial/hang caveat，t128 僅 4 個有效 tpmC 值。

### t=128 mean tpmC 排行（W=128，NEW_ORDER）

| 排名 | variant | tpmC | NO p99 (ms) | err | range/mean | 有效 rounds |
|---|---|---:|---:|---:|---:|:---:|
| 🥇 | VM HAProxy 3s3r (S-BASE 對照) | **15,632** | 705 | 0.0% | 7.1% | 5 |
| 🥈 | K8s [`unlimit`](#k8s-unlimit-rc無顯式-kubernetes-resource-limits) RC | **2,998** | 5,422 | 0.0% | 4.5% | 5 |
| 🥉 | K8s [`limit`](#k8s-limit-rckubernetes-resource-limits) RC | **1,604** | 11,677 | 0.0% | 3.3% | 4/5 caveat |

### 三大觀察

1. **Kubernetes 部署平面對 YugabyteDB 退化極大**：unlimit t=128 retention 僅 19.2%，limit 僅 10.3%；這是 K8s family vs VM family 的 overhead 對照，不可混入 VM 主排名。
2. **tail latency 是主要風險**：unlimit t=128 NO p99 = 5,422 ms，limit t=128 NO p99 = 11,677 ms；相對 VM baseline 705 ms，分別放大約 7.7x / 16.6x。
3. **limit t128 不完整**：`.suite.done` 記錄 `T128 round 5 partial (SIGTERM after 25min hang); 19/20 rounds usable`；summary 只能解析 r1-r4 的 tpmC，對外引用需標 caveat。

---

## 1. Adopted cases

| variant | TPCC_TS | suite path | markers | summary.json |
|---|---|---|---|---|
| K8s [`unlimit`](#k8s-unlimit-rc無顯式-kubernetes-resource-limits) RC | 20260612T120138+0800 | [`ybdb-k8s-3node-haproxy-3s3r-unlimit-rc-20260612T120138+0800/`](./ybdb-k8s-3node-haproxy-3s3r-unlimit-rc-20260612T120138+0800/) | `.suite.done` + `.collect.done` | ✅ retrofit 2026-06-23 |
| K8s [`limit`](#k8s-limit-rckubernetes-resource-limits) RC | 20260613T233549+0800 | [`ybdb-k8s-3node-haproxy-3s3r-limit-rc-20260613T233549+0800/`](./ybdb-k8s-3node-haproxy-3s3r-limit-rc-20260613T233549+0800/) | `.suite.done` + `.collect.done` | ✅ retrofit 2026-06-23 |

排除：

| variant | TPCC_TS | 原因 |
|---|---|---|
| K8s unlimit RC | 20260608T120857+0800 | `.dry-run.done` only，dry-run 不入數據表 |
| K8s limit RC | 20260608T120336+0800 | `.dry-run.done` only，dry-run 不入數據表 |

---

## 2. Execute 結果總覽（S-K8S 2 variants）

> 口徑對齊 S-BASE：代表點採各 resource variant 的主要觀察併發；完整 per-round thread sweep 見各 variant 的 `Thread sweep` 表。p99 為 NEW_ORDER 5-round latency mean；err 為 all transaction error rate。S-K8S 目前只有 `READ COMMITTED`，拓樸皆為 `k8s-3node-haproxy-3s3r`。

| variant | resource profile | TPCC_TS | 代表併發 | tpmC mean | range/mean | NO p99 mean (ms) | err | N | 判讀 |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| [`unlimit`](#k8s-unlimit-rc無顯式-kubernetes-resource-limits) | 無顯式 Kubernetes resource limits | [`20260612T120138`](./ybdb-k8s-3node-haproxy-3s3r-unlimit-rc-20260612T120138+0800/) | 128 | 2,998 | 4.5% | 5,422 | 0.0% | 1 | 相對 VM HAProxy baseline 保留 19.2% tpmC |
| [`limit`](#k8s-limit-rckubernetes-resource-limits) | Kubernetes resource limits | [`20260613T233549`](./ybdb-k8s-3node-haproxy-3s3r-limit-rc-20260613T233549+0800/) | 128 | 1,604 | 3.3% | 11,677 | 0.0% | 1 | t128 僅 4/5 有效 round；相對 VM 保留 10.3% tpmC |

---

## 3. Thread sweep（主表取自 summary.json）

### k8s-unlimit-rc（無顯式 Kubernetes resource limits）

> tpmC / latency / error rate 皆取自 [`summary.json`](./ybdb-k8s-3node-haproxy-3s3r-unlimit-rc-20260612T120138+0800/summary.json)；p50 / p95 / tpmTotal / efficiency 補充見 `summary.json`。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 2,502 | 2,288 | 2,326 | 2,312 | 2,330 | 2,352 | 9.1% | 591 | 0.0% |
| 32 | 2,842 | 2,843 | 2,746 | 2,744 | 2,778 | 2,790 | 3.5% | 1,007 | 0.0% |
| 64 | 3,005 | 3,095 | 2,998 | 2,961 | 2,923 | 2,996 | 5.7% | 2,107 | 0.0% |
| 128 | 3,091 | 2,974 | 2,977 | 2,989 | 2,957 | **2,998** | 4.5% | 5,422 | 0.0% |

### k8s-limit-rc（Kubernetes resource limits）

> tpmC / latency / error rate 皆取自 [`summary.json`](./ybdb-k8s-3node-haproxy-3s3r-limit-rc-20260613T233549+0800/summary.json)；p50 / p95 / tpmTotal / efficiency 補充見 `summary.json`。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 1,710 | 1,678 | 1,698 | 1,685 | 1,648 | 1,684 | 3.6% | 913 | 0.0% |
| 32 | 1,764 | 1,738 | 1,692 | 1,694 | 1,694 | **1,716** | 4.2% | 1,960 | 0.0% |
| 64 | 1,699 | 1,726 | 1,718 | 1,737 | 1,684 | 1,713 | 3.1% | 4,617 | 0.0% |
| 128 | 1,610 | 1,579 | 1,597 | 1,632 | — | 1,604 | 3.3% | 11,677 | 0.0% |

> limit t128：`.suite.done` 標記 round 5 partial / SIGTERM after 25 min hang；`summary.json` 僅有 4 個有效 tpmC 值，因此本列 N=4/5，不可視為完整 5-round baseline。

---

## 4. VM baseline 對標（t=128，NEW_ORDER）

VM baseline 取 [`../S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/summary.json`](../S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/summary.json) t=128：tpmC 15,632 / NO p99 705 ms / err 0.0%。

公式：retention = K8s / VM；Δ = K8s / VM − 1。

| 對照 | tpmC retention | NO p99 Δ | error-rate Δ |
|---|---:|---:|---:|
| unlimit / VM | **19.2%** | +669.6% | 0.0 pp |
| limit / VM | **10.3%** | +1557.2% | 0.0 pp |
| limit / unlimit | 53.5% | +115.3% | 0.0 pp |

---

## 5. Caveats / 未補項

- S-K8S 與 S-BASE 屬不同 baseline family（k8s vs vm）；retention 僅量化部署平面開銷，不可與 VM 系列同表排名。
- 兩個 adopted case 皆為 N=1 suite；其中 unlimit 各 thread 有 5 round，limit t128 為 4/5 有效 round。
- `prepare/shard-count.txt` 顯示 9 張 TPC-C table 皆 `expected>=3 actual=3 pass=true`，SPLIT INTO 3 TABLETS 已生效。
- DB-host metrics 已收集至 `runs/threads-*/round-*/{mpstat,iostat,vmstat,sar-net}*`；本檔不對 CPU / IO 飽和作定論。
- postgres + DocDB 雙 process pod IPC / CPU contention 是可能方向，但目前缺足夠 metrics 歸因，需另行證實。

---

## 6. 變更紀錄

- **2026-06-23**：retrofit `summary.json` 至兩個 suite-done case（呼叫 `tests/common/summary-from-stdout.py`）；建立本 `pipeline-log.md`。
