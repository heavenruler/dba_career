# YugabyteDB vm-3node S-BASE 4 cells RC 分析報告

**測試完成日**：2026-05-25  
**樣本**：4 cells × 4 thread × 5 round = 80 個 5-min 取樣  
**Hardware**：3 × ProxmoxVM（4 vCPU、12 GB RAM、single XFS），AlmaLinux 8.10，YugabyteDB 2025.2.2 LTS  
**Driver**：go-tpc v1.0.12 on .31，128 warehouses，20 min warmup，5 round × 5 min，無 think time  
**Isolation**：READ COMMITTED（gflag `yb_enable_read_committed_isolation=true` + session iso 雙閘）

---

## 1. 4 cells artifact 一覽

| Cell | RF | shards/table | Tablets total | Replicas total | TPCC_TS |
|------|---:|-------------:|--------------:|---------------:|---------|
| 1s1r | 1 | 1 | 9 | 9 | 20260524T032814+0800 |
| 1s3r | 3 | 1 | 9 | 27 | 20260524T074754+0800 |
| 3s1r | 1 | 3 | 27 | 27 | 20260524T202219+0800 |
| 3s3r | 3 | 3 | 27 | 81 | 20260525T031918+0800 |

---

## 2. Throughput（tpmC，5-round mean across 5 rounds）

| cell | t=16 | t=32 | t=64 | t=128 | 飽和點 |
|------|-----:|-----:|-----:|------:|:------:|
| 1s1r | 11,491 | **13,702** | 13,200 | 13,725 | t=32 |
| 1s3r | 6,970 | 9,394 | 10,068 | **10,228** | t=128 |
| 3s1r | 11,180 | **11,967** | 11,749 | 11,691 | t=32 |
| 3s3r | 4,776 | 6,618 | 8,195 | **8,729** | t=128 |

### tpmC 排行（best mean across thread groups）

| 排名 | cell | tpmC | @threads | 註 |
|------|------|-----:|---------:|----|
| 🥇 | 1s1r | 13,725 | t=128 | 單機 baseline，無 replication |
| 🥈 | 3s1r | 11,967 | t=32 | sharding +13% 協調成本 |
| 🥉 | 1s3r | 10,228 | t=128 | RF=3 −25% replication 成本 |
| 4 | 3s3r | 8,729 | t=128 | 全 sharded+replicated，−36% 對 1s1r |

> **口徑說明**：`best mean` = 在該 cell 4 個 thread groups 中、5-round mean tpmC 最高的那組值。**與第 9 節「建議代表點」不一定相同** — 代表點採「throughput-latency 平衡」原則，可能挑較低 thread 群（例如 1s1r 代表點為 t=32 / 13,702，雖比 t=128 best mean 13,725 略低 23 tpmC，但 NO_p99 從 758 ms 降到 205 ms）。兩個口徑都有效，僅意義不同：best mean 看單純吞吐極限，代表點看可用 SLA 工作點。

---

## 3. Latency（NEW_ORDER p99，5-round mean ms）

| cell | t=16 | t=32 | t=64 | t=128 |
|------|-----:|-----:|-----:|------:|
| 1s1r | 90 | 205 | 396 | 758 |
| 1s3r | 144 | 245 | 477 | 1,034 |
| 3s1r | 94 | 203 | 436 | 1,007 |
| 3s3r | 153 | 272 | 567 | 1,114 |

DELIVERY p99（最重交易，5-round mean ms）：

| cell | t=16 | t=32 | t=64 | t=128 |
|------|-----:|-----:|-----:|------:|
| 1s1r | 117 | 268 | 507 | 1,127 |
| 1s3r | 186 | 349 | 705 | 1,476 |
| 3s1r | 123 | 268 | 624 | 1,356 |
| 3s3r | 196 | 369 | 785 | 1,517 |

---

## 4. 變數獨立成本（純效應拆解）

| 比較對 | tpmC 差 | NO_p99 差 | 結論 |
|--------|--------:|----------:|------|
| RF=1→3 @ 1-shard、t=128 (1s1r→1s3r) | **−25.5%** (13725→10228) | +36% (758→1034) | replication 寫多副本 ~25% 損耗 |
| RF=1→3 @ 3-shard、t=128 (3s1r→3s3r) | **−25.3%** (11691→8729) | +11% (1007→1114) | 一致 25% |
| 1-shard→3-shard @ RF=1、t=32 (1s1r→3s1r) | **−12.7%** (13702→11967) | −1% (205→203) | sharding 純成本 ~13%，latency 無變化 |
| 1-shard→3-shard @ RF=3、t=128 (1s3r→3s3r) | **−14.7%** (10228→8729) | +8% (1034→1114) | 在 RF=3 上 sharding 略提高 latency |
| **疊加** (1s1r→3s3r、t=128) | **−36.4%** (13725→8729) | +47% (758→1114) | RF + shard 成本疊加 |

---

## 5. 穩定度（tpmC stddev across 5 rounds）

| cell | t=16 sd | t=32 sd | t=64 sd | t=128 sd | 穩定度評語 |
|------|--------:|--------:|--------:|---------:|------|
| 1s1r | 106 | 608 | 918 | 160 | 中等；t=64 偶有 RocksDB compaction dip |
| 1s3r | **1,463** | 330 | 86 | 72 | warmup 過渡期不穩，之後極穩 |
| 3s1r | 142 | 128 | 22 | 85 | **最穩** |
| 3s3r | **2,615** | **1,788** | 1,402 | **2,415** | **極不穩**；t=16 min=1517 max=7453（4.9×） |

3s3r 在所有 thread 等級皆呈高變異 — root cause = 27 tablets × RF=3 = 81 replicas 在 4 vCPU 上 leader rebalance + RocksDB compaction 互相干擾，throughput 隨機掉到 ~50%。

---

## 6. DB host (.32) CPU 利用率（round-5 採樣）

| cell | t=16 | t=32 | t=64 | t=128 | 飽和判讀 |
|------|-----:|-----:|-----:|------:|---------|
| 1s1r | 23% idle | 9% idle | 6% idle | 4% idle | t=32 起 CPU-bound |
| 1s3r | 13% idle | 7% idle | 5% idle | 4% idle | t=32 起 CPU-bound |
| 3s1r | 13% idle | 7% idle | 5% idle | 4% idle | t=32 起 CPU-bound |
| 3s3r | 10% idle | **42% idle** | **24% idle** | 4% idle | **coordination-bound** at t=32/64 |

3s3r 在 t=32 / t=64 出現 CPU 大量空閒但 throughput 反而低，**workload 卡 tablet/raft 協調而非 CPU**。t=128 才把 CPU 推滿（被外部 queue 充飽）。

---

## 7. 跨拓樸對標（含 vm-1node baseline）

| 拓樸 / cell | RF | shards | best mean tpmC | NO_p99 | 對 vm-1node-rc ratio |
|-------------|---:|-------:|---------------:|-------:|:--------------------:|
| vm-1node-rc | 1 | 1 | 11,436 (t=32) | n/a | 1.0× |
| vm-3node-1s1r | 1 | 1 | 13,725 (t=128) | 758 | **1.20×**（cluster overhead 反而吃糖；可能 vm-3node host 略快） |
| vm-3node-1s3r | 3 | 1 | 10,228 (t=128) | 1,034 | 0.89× |
| vm-3node-3s1r | 1 | 3 | 11,967 (t=32) | 203 | 1.05× |
| vm-3node-3s3r | 3 | 3 | 8,729 (t=128) | 1,114 | 0.76× |

> 補充：vm-1node 用 `vm3_db` 同型機；本輪 1s1r 對標 vm-1node 多出 ~20%，可能來自不同採樣窗 / host I/O 雜訊，待之後跨日重採樣確認。

---

## 8. 三個結論

1. **RF=3 一律 ~25% 寫吞吐損耗**（Raft 三副本固定成本）；shard=3 加 ~13% 協調；兩者疊加 ~36% 損失，與 4 vCPU 硬體無關。
2. **3s3r 不穩定根因 = tablet 協調，非 CPU**（t=32/64 CPU 42% / 24% idle 但 throughput 反而 drop）— 81 replicas / 4 vCPU 在 leader rebalance + RocksDB write/flush 競爭過嚴。
3. **此硬體配置不適合 3s3r 生產**：t=16 round 間振幅 4.9×、整體 mean 比 1s1r 少 36%。若要 3s3r 穩定 → vCPU ≥ 8 或降 tablet 數（單表 ≤ 3 已是測試最低）。

---

## 9. 建議代表點（給 pipeline-log 收口）

| cell | 代表 threads | mean tpmC | NO_p99 ms | DEL_p99 ms | DB CPU idle% |
|------|:------------:|----------:|----------:|-----------:|-------------:|
| 1s1r | t=32 | 13,702 | 205 | 268 | 9 |
| 1s3r | t=128 | 10,228 | 1,034 | 1,476 | 4 |
| 3s1r | t=32 | 11,967 | 203 | 268 | 7 |
| 3s3r | t=128 | 8,729 | 1,114 | 1,517 | 4 |

代表 threads 採「mean tpmC 最大且不撞極端 latency」原則：1s1r/3s1r 在 t=32 飽和；1s3r/3s3r 因 RF=3 寫多副本，吞吐持續攀升到 t=128 才平台化。

---

## 10. 資料定位（artifact paths）

```
results/yuga-tc1/S-BASE/
├─ vm-3node-1s1r-rc/ybdb-vm-3node-1s1r-rc-20260524T032814+0800/
├─ vm-3node-1s3r-rc/ybdb-vm-3node-1s3r-rc-20260524T074754+0800/
├─ vm-3node-3s1r-rc/ybdb-vm-3node-3s1r-rc-20260524T202219+0800/
└─ vm-3node-3s3r-rc/ybdb-vm-3node-3s3r-rc-20260525T031918+0800/
```

每 cell 245 files，含：dry-run/、gate/、prepare/、runs/（4 threads × 5 rounds × {go-tpc-stdout, mpstat, iostat, sar, vmstat}）、db-config/、env/。

---

## 11. 還原命令

```bash
cd /Users/wn.lin/vscode-git/dba_career/poc
# 重抽某 cell tpmC：
grep -E '^tpmC:' results/yuga-tc1/S-BASE/vm-3node-1s1r-rc/ybdb-vm-3node-1s1r-rc-20260524T032814+0800/runs/threads-32/round-*/go-tpc-stdout.txt
# DB host CPU avg：
grep '平均時間' results/yuga-tc1/S-BASE/vm-3node-3s3r-rc/ybdb-vm-3node-3s3r-rc-20260525T031918+0800/runs/threads-128/round-1/mpstat-db.txt
```
