# CockroachDB TPC-C Pipeline Log — crdb-tc1 / S-K8S

> 本檔僅紀錄 **S-K8S**（Kubernetes 部署平面）CockroachDB 對照數據；VM baseline 在 `../S-BASE/pipeline-log.md`、跨家對比見 `1_MeetingMinutes/` 同期會議檔。
> 取數口徑：`results/crdb-tc1/S-K8S/<case>/summary.json`（由 `tests/common/summary-from-stdout.py v1` 從 `runs/threads-*/round-*/go-tpc-stdout.txt` 解析）。

---

## TL;DR — 兩個 K8s resource variant，N=5 sweep 完成

**核心結論**：同硬體（3 IDC 節點 × cockroach Pod 各 1 + HAProxy frontend）下，K8s `unlimit` 對 VM baseline 保留 **81.1 %** tpmC、p99 +27.1 %；加上 cpu=2 / mem=8Gi 限額後 `limit` 只剩 **43.2 %** tpmC、p99 +191.6 %。

### t=128 mean tpmC 排行（W=128，N=5，NEW_ORDER）

| 排名 | variant | tpmC | p99 (ms) | NEW_ORDER err rate | range/mean | N |
|---|---|---:|---:|---:|---:|:---:|
| 🥇 | VM HAProxy 3s3r (S-BASE 對照) | **15,033.3** | 718.0 | 0.0 % | 6.9 % | 5 |
| 🥈 | K8s **unlimit** RC | **12,196.7** | 912.7 | 0.0 % | 5.1 % | 5 |
| 🥉 | K8s **limit** RC（cpu=2 / mem=8Gi） | **6,493.5** | 2,093.8 | 0.0 % | 6.4 % | 5 |

### 三大觀察

1. **K8s 部署層額外開銷 ≈ 19 %**：unlimit 相對 VM tpmC 保留 81.1 %、p99 +27.1 %。差距來自 pod network（CNI overlay + iptables hop）+ cgroup parent + kube-reserved，非 CockroachDB binary 本身。對比 TiDB 同硬體 unlimit 保留 87 %，CockroachDB 的 K8s 額外開銷略高（推測 Pebble fsync 在 CNI 路徑下對 latency 更敏感）。
2. **Resource limit 把 t=128 拖到 2 秒級 p99**：limit t=128 mean tpmC = 6,493.5、p99 = 2,094 ms；t=64 → t=128 thread ×2、tpmC 僅 +7.0%、p99 ×1.79。`cpu=2` cap 下 CockroachDB pod 已飽和，加 thread 主要堆排隊深度而非 throughput。但 CockroachDB 不像 TiDB 出現 t=128 < t=64 的反曲，t=128 仍為 limit cell 最高 tpmC，**對外可用 t=128 直接報數**。
3. **N=5 穩定度可接受**：unlimit cell t=128 range/mean=5.1 %、limit cell t=128 range/mean=6.4 %，皆在內部 15 % 容忍內。低 thread 端 unlimit t=16 range/mean=11.9 % 與 limit t=16=16.1 % 偏高，但不影響 t=128 對外引用。

---

## 1. Adopted cases

| variant | TPCC_TS | suite path | markers | summary.json |
|---|---|---|---|---|
| K8s unlimit RC | 20260609T065714+0800 | `crdb-k8s-3node-haproxy-3s3r-unlimit-rc-20260609T065714+0800/` | `.suite.done` + `.collect.done` | ✅ retrofit 2026-06-23 |
| K8s limit RC | 20260611T132715+0800 | `crdb-k8s-3node-haproxy-3s3r-limit-rc-20260611T132715+0800/` | `.suite.done` + `.collect.done` | ✅ retrofit 2026-06-23 |

排除：

| variant | TPCC_TS | 原因 |
|---|---|---|
| K8s unlimit RC | 20260608T094902+0800 | `.dry-run.done` only，dry-run 不入數據表 |
| K8s limit RC | 20260608T102008+0800 | `.dry-run.done` only，dry-run 不入數據表 |

---

## 2. Thread sweep（5-round mean per cell）

表頭口徑統一：per-round tpmC + mean + range/mean + NO p99 mean + NEW_ORDER err rate；p50/p95/tpmTotal 等補充指標見對應 `summary.json`。

### unlimit（無 K8s resource limits）

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|--------:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16  |  8,427 |  8,620 |  7,650 |  8,038 |  8,188 |  8,184.7 | 11.9 % | 157.7 | 0.0 % |
| 32  | 10,711 | 10,919 | 10,817 | 11,154 | 11,619 | 11,043.9 |  8.2 % | 226.5 | 0.0 % |
| 64  | 11,552 | 11,489 | 11,711 | 11,586 | 11,556 | 11,578.8 |  1.9 % | 453.0 | 0.0 % |
| 128 | 11,804 | 12,429 | 12,012 | 12,320 | 12,420 | **12,196.7** | 5.1 % | 912.7 | 0.0 % |

### limit（cpu=2 / mem=8Gi per pod）

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|--------:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16  | 4,683 | 4,719 | 4,208 | 4,858 | 4,964 | 4,686.3 | 16.1 % |   396.0 | 0.0 % |
| 32  | 5,635 | 5,566 | 5,047 | 5,095 | 5,184 | 5,305.2 | 11.1 % |   684.5 | 0.0 % |
| 64  | 5,839 | 5,797 | 6,311 | 6,250 | 6,146 | 6,068.6 |  8.5 % | 1,167.7 | 0.0 % |
| 128 | 6,670 | 6,504 | 6,703 | 6,287 | 6,303 | **6,493.5** | 6.4 % | 2,093.8 | 0.0 % |

### limit 反曲解讀

t=64 → t=128：thread ×2、tpmC +7.0 %、p99 ×1.79。`cpu=2` cap 下 CockroachDB pod 已接近飽和，但與 TiDB limit cell 不同，CockroachDB t=128 仍勝 t=64 而非反曲。**limit cell 對外引用建議用 t=128**（throughput 最高、p99 雖達 2 秒級但仍為單調延伸）。

---

## 3. VM baseline 對標（t=128，NEW_ORDER）

公式：retention = K8S / VM；Δ = K8S / VM − 1。

| 對照 | tpmC retention | p99 Δ | error-rate Δ |
|---|---:|---:|---:|
| unlimit / VM | **81.1 %** | +27.1 % | 0.0 pp |
| limit / VM | **43.2 %** | +191.6 % | 0.0 pp |
| limit / unlimit | 53.2 % | +129.4 % | 0.0 pp |

VM baseline 數值：tpmC 15,033.3 / p99 718.0 / err 0.0 %，來自 `../S-BASE/vm-3node-haproxy-3s3r-rc/crdb-vm-3node-haproxy-3s3r-rc-20260602T051500+0800/summary.json`。

---

## 4. Caveats / 未補項

- S-K8S 與 S-BASE 屬不同 baseline family（k8s vs vm）；retention 僅量化部署平面開銷，不可與 vm 系列同表排名。
- CockroachDB unlimit cell 在 4 vCPU 路徑下 latency 對 CNI overlay 較 TiDB 敏感（unlimit p99 +27 % vs TiDB +17 %），推測為 Pebble WAL fsync 在 pod 網路 / cgroup parent 下被放大；本檔未直接量測 store-level metrics。
- DB-host metrics 已收齊 `runs/threads-128/round-*/free-1m / iostat / mpstat / sar-net / vmstat`；本檔未對 CPU/IO 飽和作推論。
- 「unlimit」並非 cgroup 真正無限：parent cgroup / kube-reserved 仍有上限，僅相對 `cpu=2/mem=8Gi` 而言為「未顯式 limit」。

---

## 5. 變更紀錄

- **2026-06-23**：retrofit `summary.json` 至兩個 suite-done case（呼叫 `tests/common/summary-from-stdout.py`）；建立本 `pipeline-log.md`。在此之前 K8s 兩 case 僅有 stdout artifacts，pipeline 上下游若依 `summary.json` 自動匯整會 missing source — 本次補齊。
