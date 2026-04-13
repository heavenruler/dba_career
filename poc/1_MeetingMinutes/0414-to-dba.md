# [分散式資料庫架構 PoC](https://104corp.atlassian.net/browse/ITDBA-3596)

## 這類 PoC 要完成的目標

```
停機維護是 104 的事，不影響到客戶使用權益
```

## 已經完成了什麼？

- 完成 `MySQL Galera` 與 `TiDB` 的架構特性初步對照。
- 補齊 `PostgreSQL-compatible` 路線，現階段以 `YugabyteDB` 為主要觀察標的。

## 為什麼我們要做這件事情

- 傳統 HA 架構經驗足夠，但分散式資料庫的 trade-off 仍需用 PoC 實際確認。
- 若只看單一產品或單一路線，容易被既有習慣綁住，無法形成完整選型依據。
- 補完 `PostgreSQL-compatible` 路線後，才能與 `MySQL-compatible` 路線一起評估。

## 在這個專案可以了解的 Survey 評估面向

```
- 系統定位
- Multi-Region 寫入模型
- 衝突處理機制
- MVCC 與 Read 行為
- Failover / HA
- 擴展與 Hotspot
- DDL / Schema 行為
- 運維能力
- 成本模型
```
[Reference](https://github.com/heavenruler/dba_career/blob/master/poc/0_projectFor104/README.md#221-survey-%E8%A9%95%E4%BC%B0%E9%9D%A2%E5%90%91)

## 如何繼續跟進討論

PoC 專案週會同步（`1~2 times / weekly`，`1~2 hours`）

討論內容包含但不限於：

- PoC 專案進度與時程。
- 相關分散式架構技術與原理跟進。
- 技術領域風向。
- 104Corp 產品適性架構討論。
