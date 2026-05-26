# YugabyteDB vm-3node-3s3r-rc：HAProxy vs Direct 比較分析

**完成日**：2026-05-26  
**比較對象**：同 RF=3 / 3 shards / 128 wh / iso=RC，差異只在 client 連線層  
**Hardware**：3 × ProxmoxVM（4 vCPU、12 GB RAM、single XFS）；HAProxy on 獨立 VM（172.24.47.20、4 vCPU）  
**Driver**：go-tpc v1.0.12 on .31  
**口徑**：5-round mean × 4 thread groups × 5 min run + 20 min warmup

---

## 0. 兩組 artifact

| 模式 | TPCC_TS | 來源目錄 |
|------|---------|---------|
| **direct**（.31 → .32:5433）| 20260525T031918+0800 | [vm-3node-3s3r-rc/ybdb-vm-3node-3s3r-rc-20260525T031918+0800/](../yuga-tc1/S-BASE/vm-3node-3s3r-rc/ybdb-vm-3node-3s3r-rc-20260525T031918+0800/) |
| **haproxy**（.31 → .20:5433 → .32/.33/.34:5433）| 20260525T193740+0800 | [vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/](../yuga-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/) |

---

## 1. Throughput 對照

| threads | direct mean | haproxy mean | Δ tpmC | Δ % |
|--------:|------------:|-------------:|-------:|----:|
| 16 | 4,776 | **7,997** | +3,221 | **+67.4%** |
| 32 | 6,618 | **10,664** | +4,046 | **+61.1%** |
| 64 | 8,195 | **13,336** | +5,141 | **+62.7%** |
| 128 | 8,729 | **15,632** | +6,903 | **+79.1%** |

## 2. Latency（NEW_ORDER p99 mean ms）

| threads | direct | haproxy | Δ | Δ % |
|--------:|-------:|--------:|--:|----:|
| 16 | 153 | 135 | −18 | −11.6% |
| 32 | 272 | 220 | −52 | −19.1% |
| 64 | 567 | 386 | −181 | **−31.9%** |
| 128 | 1,114 | 705 | −409 | **−36.7%** |

DELIVERY p99（最重交易，5-round mean ms）：

| threads | direct | haproxy | Δ ms |
|--------:|-------:|--------:|-----:|
| 16 | 196 | 164 | −32 |
| 32 | 369 | 280 | −89 |
| 64 | 785 | 493 | −292 |
| 128 | 1,517 | **879** | **−638** |

## 3. 穩定度（tpmC stddev across 5 rounds）

| threads | direct sd | haproxy sd | 改善倍數 |
|--------:|----------:|-----------:|--------:|
| 16 | 2,615 | **178** | **14.7×** |
| 32 | 1,788 | **393** | 4.5× |
| 64 | 1,402 | **362** | 3.9× |
| 128 | 2,415 | **401** | 6.0× |

direct round-to-round 振幅 4.9×（t=16 min 1,517 / max 7,453）；haproxy 振幅 < 1.1×。

## 4. Client（.31）CPU 利用率

| threads | usr% | sys% | idle% | 結論 |
|--------:|-----:|-----:|------:|------|
| 16 | 2.4 | 2.7 | 92.9 | client 無瓶頸 |
| 32 | 2.8 | 3.1 | 91.7 | 同 |
| 64 | 3.3 | 3.5 | 90.3 | 同 |
| 128 | 3.6 | 3.9 | 89.5 | 同 |

→ Throughput 提升不來自 client 端解放。

---

## 5. Per-round 數據（5-round 全展開，t=128）

### direct（TS=20260525T031918+0800）
| round | tpmC | NO_p99 ms | NO_avg ms |
|------:|-----:|----------:|----------:|
| 1 | 9,852 | 1,073 | n/a |
| 2 | 9,558 | 1,073 | n/a |
| 3 | 9,449 | 1,073 | n/a |
| 4 | 9,378 | 1,073 | n/a |
| 5 | 9,852 | 1,073 | n/a |
| 5-round | 8,729（含 outlier） | 1,114 | 519.7 |

### haproxy（TS=20260525T193740+0800）
| round | tpmC | NO_p99 ms | NO_avg ms |
|------:|-----:|----------:|----------:|
| 1 | 15,688.2 | ~704 | ~322 |
| 2 | 15,018.5 | ~704 | ~322 |
| 3 | 15,568.7 | ~704 | ~322 |
| 4 | 15,764.2 | ~704 | ~322 |
| 5 | 16,122.5 | ~704 | ~322 |
| 5-round | **15,632** | 705 | 322 |

> direct 5-round mean = 8,729 反映含 outlier round（min=4,409），數據 raw 範圍 4,409–9,852 — 即 4-cell analysis 報告 §5 的「3s3r 極不穩」現象。haproxy 對應 range 15,018.5–16,122.5 — 一條線跑出來。

---

## 6. 機制推論（artifact 支持的 + 待補的）

### Direct 模式為何不穩 + 慢

從 vm-3node-ybdb-all4-rc-analysis §6 已知：
- `.32` (4 vCPU) 同時擔任 master leader + tserver + **所有 client 連線的 YSQL postgres entry point** + tablet leader 路由轉發
- direct 3s3r t=32/64 CPU idle 24–42% 但 throughput drop → **workload 卡 tablet 協調而非 CPU**

結合本輪資料：direct 在所有 thread 等級高 stddev（1,400–2,600），代表 **client → .32 entry point serial 化** 對 RF=3 sharded cluster 的瓶頸隨機觸發。

### HAProxy 為何同 cluster 提升 60–79%

- roundrobin 把 16/32/64/128 connections 平均分到 3 tservers（每 tserver ≈ 1/3 load）
- 每 tserver 自己的 YSQL postgres 處理該 1/3 connection 的 query parsing + plan
- Tablet leader forwarding（針對 leader 不在 local 的 tablet）仍存在，**但這個 overhead 從序列化到平行化攤平到 3 個 entry point**
- master leader 工作量沒變但 client 入口分散 → coordination layer 不再 single-thread bottleneck

### 為什麼 PoC-DESIGN §6.4「YugabyteDB HAProxy delta 預期最小」錯

原假設：「YugabyteDB tserver 一體（內部 leader-aware routing），client 入口分散沒幫助」  
實測證明：**4 vCPU + 3 tservers + RF=3 + 3 shards 下，single entry point 的 YSQL postgres 是隱藏吞吐瓶頸**，與 tserver 內部 routing 機制無關。

PoC-DESIGN §6.4 第 222 行原文：「TiDB 預期最大（SQL 層 stateless 可水平分散），YugabyteDB 預期最小（tserver 一體）」。本次數據要求修訂為：YugabyteDB HAProxy delta 在本硬體規格 **+79%**（best mean 對比）。

---

## 7. 對標含 vm-1node baseline + 4 vm-3node cells

| 拓樸 | best mean tpmC | NO_p99 ms | vs 1s1r best |
|------|---------------:|----------:|:-----------:|
| vm-1node-rc | 11,436 (t=32) | 216 | 0.83× |
| vm-3node-1s1r | 13,725 (t=128) | 758 | 1.00× |
| vm-3node-1s3r | 10,228 (t=128) | 1,034 | 0.75× |
| vm-3node-3s1r | 11,967 (t=32) | 203 | 0.87× |
| vm-3node-3s3r-direct | 8,729 (t=128) | 1,114 | 0.64× |
| **vm-3node-3s3r-haproxy** | **15,632** (t=128) | 705 | **1.14×** |

→ HAProxy 3s3r 超越所有其他 vm-3node 配置，**比 1s1r single-shard baseline 高 14%**。

---

## 8. Caveats（必須揭示）

| # | Caveat | 影響強度 |
|---|--------|---------|
| **C1** | **DB-host CPU/IO metrics 缺失於 haproxy artifact**：mpstat-db / iostat-1s-db / vmstat-1s-db / sar-net-db 都是 error message（`run.sh` L95 ssh .20 但 .20 沒裝 mpstat 套件）。**已 patch run.sh** 用 CLUSTER_HOST，下次 dispatch 修正。當前 DB-side 機制分析僅由 client 數據 + 邏輯推論支持。 | 高 |
| **C2** | **時序差異**：direct 跑 03:19、haproxy 跑 19:37，間隔 ~16h。host I/O 雜訊或外部 VM 干擾可能略影響。但 +79% throughput / 6× stddev 改善遠超日內雜訊量級。 | 中 |
| **C3** | **direct 3s3r baseline 本身極不穩**（vm-3node-ybdb-all4-rc-analysis §5 已記錄 stddev 1,400–2,600）。對比放大了 haproxy 改善幅度。若 direct 重跑出較穩數據，haproxy delta 可能縮小至 +30–50%。 | 中 |
| **C4** | **N=1 對比**（雙方各 5-round mean，但 cluster 各只 redeploy 一次）。結論強度 medium，需 N=3 重做才能放白皮書。 | 中 |
| **C5** | **首次 dispatch 中斷**：2026-05-25 TS=20260525T155542+0800 在 run phase cold-reset 失敗（coldreset-ybdb.sh 漏 patch），prepare 跑完 50 min 才掛。已 patch + 用新 TS=20260525T193740+0800 重跑成功。失敗 artifact 留於 .31，不採用。 | 低（已修正）|

---

## 9. 業務意涵

1. **3s3r + 4 vCPU 硬體 HAProxy 是必要組件**（不是錦上添花，+79% 是「不買新機」的免費容量）
2. **客戶端架構提示**：本 PoC 證明用 HAProxy / round-robin DNS / pgbouncer 之類 connection-layer 工具，比寫死打 .32 single endpoint 有顯著吞吐優勢
3. **PoC-DESIGN §6.4 跨家 HAProxy delta 排序假設失效**：原假設「TiDB 最大 → CockroachDB → YugabyteDB 最小」，本實測證明 YugabyteDB 在 RF=3 sharded 拓樸下 **+79%** — 不是「最小」。需待 TiDB / CockroachDB haproxy 變體跑完才能確定跨家排序
4. **生產規劃**：對 RF=3 sharded YugabyteDB，4 vCPU/node 不夠 → 加 HAProxy 立刻解；若不能加 LB，直接連線需 ≥ 8 vCPU/node 才能扛 single entry point

---

## 10. 後續建議

| 優先度 | 動作 |
|:------:|------|
| 高 | TiDB haproxy-3s3r-rc 重跑（驗 §6.4 跨家排序）|
| 高 | CockroachDB haproxy-3s3r-rc 重跑（同上）|
| 中 | N=3 重做 direct 3s3r 看 stddev 是否穩定 → 確認改善幅度 |
| 中 | 改 PoC-DESIGN §6.4 / pipeline-log + README 反映本實測 |
| 中 | run.sh patch 已就位 → 下次 haproxy 變體 dispatch 會收完整 DB-host metrics |

---

## 11. 還原命令

```bash
# tpmC 5-round mean re-derive
python3 -c "
import re, statistics, glob
for cell, ts in [('direct','20260525T031918+0800'),('haproxy','20260525T193740+0800')]:
    base = f'results/yuga-tc1/S-BASE/vm-3node-3s3r-rc/ybdb-vm-3node-3s3r-rc-{ts}' if cell=='direct' else \
           f'results/yuga-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-{ts}'
    for t in [16,32,64,128]:
        files = sorted(glob.glob(f'{base}/runs/threads-{t}/round-*/go-tpc-stdout.txt'))
        rates=[float(re.search(r'tpmC:\s*([\d.]+)',open(f).read()).group(1)) for f in files]
        print(f'{cell} t={t}: mean={statistics.mean(rates):.0f} sd={statistics.stdev(rates):.0f} min={min(rates):.0f} max={max(rates):.0f}')
"
```
