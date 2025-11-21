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

- **單機：MySQL 一定贏；TiDB 固定開銷大**
> 單機比較不在相同架構基礎，TiDB 非設計給單節點效能。
- **Scale-Up：TiDB 有效；MySQL 效益有限且放大寫入競爭現象**
- **Scale-Out：TiDB 擴張因效能擴增；MySQL 擴張性因 HA 考量**
- **跨區：MySQL Error Rate 爆量；TiDB 仍 0 Error**
> 跨區寫入 → MySQL 死鎖/衝突不可避免  
> TiDB → 跨區仍可維持完全成功交易




## Chaos engineering for leased-line quality across multiple data centers

## [Failover Scenario](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-4.md)

## Staging AC-API 整合測試紀錄

## Other