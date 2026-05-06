# TPC-C Benchmark Results — S-BASE

**工具**: go-tpc  
**規格**: 4vCPU / 16GB × 節點數 | 128 Warehouses | 16/32/64/128 threads  
**方法**: 無 think/keying time | warmup 5min | run 10min

---

## 測試矩陣

### TiDB (tidb-tc1) ✅ 已完成

| variant | 拓撲 | 入口 | resource limit | 狀態 | 16t | 32t | 64t | 128t | peak |
|---------|------|------|----------------|------|-----|-----|-----|------|------|
| vm | VM×1 | 直連 :4000 | — | ✅ | 13,993 | 17,939 | **20,816** | 18,923¹ | 20,816 |
| vm-no-analyze | VM×1 | 直連 :4000 | — | ✅ | 14,236 | 18,067 | 20,020 | **20,394** | 20,394 |
| k8s-unlimit | K8s×3 | Service | 無 | ✅ | 13,668 | 16,992 | 18,456 | **18,842** | 18,842 |
| k8s-limit | K8s×3 | Service | TiKV 2c | ✅ | 11,156 | 11,508 | 11,729 | **11,823** | 11,823 |

> ¹ 128t 反降原因：AUTO ANALYZE 干擾；vm-no-analyze 停用後恢復正常

### YugabyteDB (yuga-tc1) 🔄 進行中

| variant | 拓撲 | RF | 入口 | resource limit | 狀態 | 16t | 32t | 64t | 128t | peak |
|---------|------|----|------|----------------|------|-----|-----|-----|------|------|
| vm-1node | VM×1 | RF=1 | 直連 :5433 | — | ⏳ | — | — | — | — | — |
| vm-3node | VM×3 | RF=3 | HAProxy :15433 | — | ⏳ | — | — | — | — | — |
| vm-3node-direct | VM×3 | RF=3 | 直連 :5433 | — | ⏳ | — | — | — | — | — |
| k8s-3node-unlimit | K8s×3 | RF=3 | HAProxy :15433 | 無 | ⏳ | — | — | — | — | — |
| k8s-3node-limit | K8s×3 | RF=3 | HAProxy :15433 | tserver Nc | ⏳ | — | — | — | — | — |

---

## 對標維度

| 維度 | TiDB variant | YBDB variant | 說明 |
|------|-------------|-------------|------|
| 單機 VM 基線 | vm-no-analyze | vm-1node | 最純粹的單節點效能 |
| 多節點 VM | — | vm-3node | YBDB 特有：RF=3 Raft 開銷 |
| HAProxy overhead | — | vm-3node vs vm-3node-direct | 隔離 proxy 成本 |
| K8s 無限制 | k8s-unlimit | k8s-3node-unlimit | 容器化 overhead |
| K8s 資源限制 | k8s-limit | k8s-3node-limit | 資源管制影響 |

---

## 環境規格

| 項目 | TiDB | YBDB |
|------|------|------|
| 節點組成 | TiDB + TiKV×3 + PD | 3-node (tserver + master) / 1-node |
| CPU | 4vCPU (Xeon Gold 6346) | 4vCPU (Xeon Gold 6346) |
| RAM | 16GB | 16GB |
| max_connections | 無限 | 300/tserver |
| 特殊 flags | — | packed_row=false, wait_queues=true, read_committed=true |

---

## 參考

- TiDB 詳細分析: `results_old/tidb-tc1/S-BASE/compare.md`
- YBDB 歷史 pipeline log: `results_old/yuga-tc1/S-BASE/pipeline-log.md`
