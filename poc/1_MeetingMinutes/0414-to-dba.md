# [分散式資料庫架構 PoC](https://104corp.atlassian.net/browse/ITDBA-3596)

## 這類 PoC 要完成的目標

- 停機維護是 104 的事，不影響到客戶使用權益

## 已經完成了什麼？

- MySQL Galera 與 TiDB 對照

## 為什麼我們要做這件事情

- 補完 PGSQL 體系對照

## 在這個專案可以了解 PoC 場域必須 Survey 評估面向

```
1. 系統定位
2. Multi-Region 寫入模型
3. 衝突處理機制
4. MVCC 與 Read 行為
5. Failover / HA
6. 擴展與 Hotspot
7. DDL / Schema 行為
8. 運維能力
9. 成本模型
```
[Reference](https://github.com/heavenruler/dba_career/blob/master/poc/0_projectFor104/README.md#221-survey-%E8%A9%95%E4%BC%B0%E9%9D%A2%E5%90%91)

## 如何繼續跟進討論

PoC 專案週會同步 ( 1 ~ 2 times / weekly ; 1 ~ 2 hours)
討論內容包含但不限
 - PoC 專案進度
 - 相關分散式架構技術與原理跟進
