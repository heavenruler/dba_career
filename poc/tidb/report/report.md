# TiDB Intro



## [RPS 效能對照解析](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-1.md)

- **MySQL 跨區中併發易掉速（-7%〜-33%）**  
- **TiDB 低併發吞吐可比 MySQL 快 +290%**  
- **跨區高併發（500 threads）TiDB 在 GCP 可快 +402%**  
- **同區高併發（GCP Local vs IDC）TiDB 可快 +518%**  
- **TiDB 跨區穩定度極高：10〜250 threads 僅 ±1%〜2% 波動**  
- **TiDB Scale-Out 成效顯著，可呈接近線性成長**  
- **跨區併發時，負載會自然傾向 TiDB 表現較佳的一側（多為 GCP）**

## [Sysbench 效能對照解析](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-2.md)

### **Single Instance（基準比較）**

- **MySQL 在單機效能上全面領先 TiDB（差距 40%～80%）**
- 原因在於：
  - **MySQL：單節點、無 RPC、無 2PC → 本地記憶體路徑極快**
  - **TiDB：SQL Layer → RPC → TiKV → RocksDB → Raft → 固定開銷大**

## **OLTP 比較（16 threads TPS 對照）**
| 類型 | MySQL TPS | TiDB TPS | 差異 |
|------|-----------|-----------|-----------|
| read_only | 1342.52 | 559.71 | **-58.3%** |
| random_points | 18096.01 | 3403.69 | **-81%** |
| random_ranges | 18309.55 | 4424.09 | **-75%** |
| write_only | 2625.10 | 1108.85 | **-58%** |
| update_index | 4015.32 | 2704.83 | **-33%** |
| read_write | 1003.99 | 354.22 | **-59%** |

### **Scale-Up / Scale-Out（擴展能力比較）**
### **跨區延遲與寫入競爭（IDC vs IDC+GCP）— sysbench TPS & Error Rate 視角**









## [Failover Scenario](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-4.md)

## Chaos engineering for leased-line quality across multiple data centers

## Staging AC-API 整合測試紀錄

## Other