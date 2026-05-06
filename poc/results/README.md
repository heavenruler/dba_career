# TPC-C Benchmark Results — S-BASE

**工具**: go-tpc  
**規格**: 3 VM × 4vCPU / 16GB | 128 Warehouses | 16/32/64/128 threads  
**方法**: 無 think/keying time | warmup 5min | run 10min | 過 HAProxy

> TiDB 歷史結果見 `results_old/tidb-tc1/`

---

## 測試矩陣

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

| 項目 | 值 |
|------|-----|
| 節點 | 3-node RF=3 zone-a/b/c (vm) / RF=1 (1node) |
| CPU | 4vCPU (Xeon Gold 6346) |
| RAM | 16GB |
| 入口 | HAProxy :15433 roundrobin（vm-3node-direct 除外） |
| max_connections | 300/tserver |
| tserver flags | packed_row=false, wait_queues=true |

---

## 參考

- 歷史 pipeline log: `results_old/yuga-tc1/S-BASE/pipeline-log.md`
- TiDB 結果（對標參考）: `results_old/tidb-tc1/S-BASE/`
