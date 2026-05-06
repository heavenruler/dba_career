# TPC-C Benchmark Results — S-BASE

**工具**: TiDB → go-tpc | YBDB → go-tpc  
**規格**: 3 VM × 4vCPU / 16GB | 128 Warehouses | 16/32/64/128 threads  
**方法**: 無 think/keying time | warmup 5min | run 10min | 過 HAProxy

---

## 測試矩陣

### TiDB (tidb-tc1) ✅ 已完成

| variant | 路徑 | 狀態 | peak tpmC |
|---------|------|------|-----------|
| vm | tidb-tc1/S-BASE/vm/20260427-1624 | ✅ | 20,816 (64t) |
| vm-no-analyze | tidb-tc1/S-BASE/vm/20260428-0900 | ✅ | 20,394 (128t) |
| k8s-unlimit | tidb-tc1/S-BASE/k8s-unlimit/20260427-1241 | ✅ | 18,842 (128t) |
| k8s-limit | tidb-tc1/S-BASE/k8s-limit/20260427-1431 | ✅ | 11,823 (128t) |

### YugabyteDB (yuga-tc1) 🔄 進行中

| variant | 路徑 | RF | HAProxy | 狀態 | peak tpmC |
|---------|------|----|---------|------|-----------|
| vm-1node | yuga-tc1/S-BASE/vm-1node | RF=1 | 直連 | ⏳ 待執行 | — |
| vm-3node | yuga-tc1/S-BASE/vm-3node | RF=3 | ✅ | ⏳ 待執行 | — |
| vm-3node-direct | yuga-tc1/S-BASE/vm-3node-direct | RF=3 | ❌ | ⏳ 待執行 | — |
| k8s-3node-unlimit | yuga-tc1/S-BASE/k8s-3node-unlimit | RF=3 | ✅ | ⏳ 待規劃 | — |
| k8s-3node-limit | yuga-tc1/S-BASE/k8s-3node-limit | RF=3 | ✅ | ⏳ 待規劃 | — |

---

## 環境規格

| 項目 | TiDB | YBDB |
|------|------|------|
| 節點 | TiDB + TiKV×3 + PD | 3-node RF=3 zone-a/b/c |
| CPU | 4vCPU (Xeon Gold 6346) | 4vCPU (Xeon Gold 6346) |
| RAM | 16GB | 16GB |
| 入口 | 直連 :4000 / K8s Service | HAProxy :15433 roundrobin |
| max_connections | 無限 | 300/tserver (900 total) |
| tserver flags | — | packed_row=false, wait_queues=true |

---

## 參考

- TiDB 詳細分析: `tidb-tc1/S-BASE/compare.md`
- YBDB pipeline log: (移至 results_old，歷史紀錄)
- 跨 DB 對標: `compare-tidb-vs-ybdb.md`
