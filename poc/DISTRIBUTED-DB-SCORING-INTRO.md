# 分散式資料庫 PoC 評分導讀與決策摘要

> 本檔是導讀，**不是**新的評分 SSOT。完整評分規則、公式、原始數字、Fact/Inference 分析與結果檔案連結，一律以 [`DISTRIBUTED-DB-SCORING.md`](./DISTRIBUTED-DB-SCORING.md) 為準；本檔任何數字都可回查該檔對應章節。
>
> 資料快照日期：2026-08-14；對應 commit `dab237c6`（`git rev-parse --short HEAD`）。
>
> 本 PoC 是 stress benchmark / TPC-C-derived workload（go-tpc），**不是** audited TPC-C 認證結果，不可與官方 TPC-C 排名直接比較。

## 給誰看、要回答什麼問題

- **管理層**：目前的證據夠不夠支持啟動下一階段（不是「選哪家」）？
- **產品開發端**：換一條協定路線，SQL / ORM / driver 要改多少？
- **架構端**：單節點延遲、水平擴展、跨區、故障模式，各自的取捨是什麼？
- **維運端**：部署、備份 / PITR、Online DDL、維運工具，還缺哪些驗證？

分散式資料庫的選型**不該只由維運端推動**。正確順序是：先由 application 需求決定可接受的協定、RTO/RPO 目標、一致性等級與跨區 workload 型態，再拿這些條件去篩產品——而不是先挑產品再回頭改需求。

## 一頁結論

- 目前只有**部分評分**，不是最終選型結論；相容性、PITR、Online DDL 等高影響項目仍待測。
- MySQL 相容路線：已測 56% 原始權重，`TiDB 78.6` 分 vs `Percona XtraDB Cluster 8.4（PXC，Galera）41.4` 分；TiDB 在水平擴展、高併發穩定性與本次 failover 設計上領先，Galera 在單節點延遲領先。
- PostgreSQL 相容路線：已測 56% 原始權重，`YugabyteDB 87.5` 分 vs `CockroachDB 87.1` 分；0.4 分差距小於本 PoC 可支持的決策精度，應視為**接近**而非排名勝負。
- 兩組分數**不可互相比較**——不同協定門檻、不同測試維度，星等只在群組內部有意義。
- 所有 cell 主要為 `N=1`（僅一次獨立重跑），方向可用，統計嚴謹度不足，對外結論前需 N=3 驗證。

## 先選遷移路線，再選產品

```mermaid
flowchart TD
    A[既有應用能否離開 MySQL 協定？] -->|否| B["PXC/Galera vs TiDB"]
    A -->|是| C{是否接受 PostgreSQL 協定與應用改造？}
    C -->|是| D["YugabyteDB vs CockroachDB"]
    C -->|尚未確認| E["先做 SQL/ORM/driver 相容性矩陣，不進產品排名"]
```

- 協定相容性是**選型門檻**，不是普通權重項目——換協定代表應用改造成本，不能用一般加權分數蓋過。
- 兩個群組使用不同測試維度與拓樸假設，**分數不可互相比較**。
- 「尚未確認」分支請先做相容性矩陣，不要跳過門檻直接比產品分數。

## 目前證據覆蓋率

| 路線 | 適用權重 | 已測權重 | 尚未量測 | 判讀 |
|---|---|---|---|---|
| MySQL 相容群組 | 95%（[§2.1](./DISTRIBUTED-DB-SCORING.md#21-mysql-相容群組mysql-galera-cluster-vs-tidb)） | 56%（#3 單節點延遲＋#4 水平擴展＋#5 高併發穩定性＋#6 Failover） | 34%（#1 相容性＋#7 PITR＋#8 Online DDL）；HTAP #9 5% 對 Galera 為 n/a，不計入已測範圍 | ⚠️ 僅 56% 可作方向判斷，34% 未測前不能下最終結論 |
| PostgreSQL 相容群組 | 80%（[§2.2](./DISTRIBUTED-DB-SCORING.md#22-postgresql-相容群組yugabytedb-vs-cockroachdb)） | 56%（#3+#4+#5+#6，項目同上） | 24%（#2 PostgreSQL 相容性＋#7 PITR＋#8 Online DDL＋#9 Geo-Distribution） | ⚠️ 同上；接近的 87.5 vs 87.1 更不能忽略未測 24% |

**重要（SSOT 內部不一致，待原檔修正）**：
- `DISTRIBUTED-DB-SCORING.md` §4.2 與 §5 引言處寫「其餘 44% 權重」。
- 但依 §2.2 權重表實際加總（80% 適用 − 56% 已測 = 24%），正確值應為 **24%**，不是 44%。
- 本檔採 24%（有直接算式支持的值），未回頭修改原檔，特此列為待釐清的原始文件錯誤，交由原檔負責人後續修正。

## 關鍵觀察：MySQL 相容路線

1. **單節點延遲**
   - Fact：`PXC/Galera` p99 37.7 ms vs `TiDB` p99 597 ms（[§3.2.1](./DISTRIBUTED-DB-SCORING.md#321-單節點低併發延遲vm-1node-rc)）。
   - 解讀：Galera 同步多主在低併發單節點下延遲更低。
   - 決策影響：延遲敏感但併發不高的場景可參考此項；不能單獨當作整體優劣依據。

2. **水平擴展**
   - Fact：vm-1node → vm-3node-haproxy-3s3r，`PXC/Galera` 0.49× vs `TiDB` 2.06×（[§3.2.2](./DISTRIBUTED-DB-SCORING.md#322-水平擴展能力vm-1node--vm-3node-haproxy-3s3r)）。
   - 解讀：Galera 是 HAProxy round-robin 多寫入節點架構，TiDB 是分散式儲存（TiKV Region）擴展機制，兩者擴展模型本質不同。
   - 決策影響：預期靠加節點提升吞吐的場景，需先確認架構是否支援真正水平擴展，而非同一套機制的不同參數。

3. **高併發穩定性**
   - Fact：t=128 時 5-round range/mean，`PXC/Galera` 43.2% vs `TiDB` 7.4%（[§3.2.3](./DISTRIBUTED-DB-SCORING.md#323-高併發穩定性t1285-round-rangemean-與-error-rate)）。
   - 解讀：Galera 在高併發下波動明顯較大；兩家皆為 `N=1`，尚未確認是否穩定重現。
   - 決策影響：對併發穩定性要求高的場景需留意此差異，但單次重跑不足以下定論。

4. **Failover / 跨區**
   - Fact：`PXC/Galera` G2（quorum-loss，殺光 3 個 IDC 節點）cluster_rebuild_sec ≈ 22.169s（[§3.3.1a](./DISTRIBUTED-DB-SCORING.md#331a-mysql-相容群組galerapxc-84chaosfailover-實測2026-08-13)）；`TiDB` 跨區 F2 場景約 44.3s/39.1s（[§3.3.1](./DISTRIBUTED-DB-SCORING.md#331-failover-rtorpo--2026-08-11-真實重跑完成)）。
   - 解讀：「Galera 節點 rejoin/quorum 重組」與「TiDB 跨區 leader 接手」**不是同一種能力**，不可直接比數字；跨區 P-A/P-B 穩態吞吐（[§3.6](./DISTRIBUTED-DB-SCORING.md#36-mysql-相容群組percona-xtradb-cluster-84pxcgalera跨區-p-ap-b-穩態吞吐量實測2026-08-12)）屬 X-CROSS exploratory，不計入加權分數。
   - 決策影響：若引用 Galera P-B 跨區失敗率作技術錨點，只能當方向性參考——缺 wsrep counter delta、Error 1213 不能全部定性為 certification failure，與 TiDB 的錯誤分類方式不同，不能逐一對應。

## 關鍵觀察：PostgreSQL 相容路線

- **總分差距**：`YugabyteDB` 87.5 分 vs `CockroachDB` 87.1 分，差距僅 0.4，應視為**接近**而非分出勝負。
- **Failover 代表點**：`YugabyteDB` 約 2.99s/3.65s、`CockroachDB` 約 7.01s/7.12s（[§3.3.1](./DISTRIBUTED-DB-SCORING.md#331-failover-rtorpo--2026-08-11-真實重跑完成)）；吞吐/穩定性差異請回原檔對應章節查代表數字，不在此複製。
- **未測缺口**：PostgreSQL 相容性、PITR、Online DDL、正式 Geo-Distribution 排名等 24% 未測權重仍待驗證，不能只看已測 56% 就下結論。

## 分數能說什麼、不能說什麼

| 可以支持 | 不能支持 |
|---|---|
| 同一群組、已測 workload、已測拓樸下的方向性比較 | 跨群組直接排名（MySQL 相容 vs PostgreSQL 相容分數不可比） |
| 指出哪類架構的擴展/穩定性成本需要應用端或維運端承擔 | 把 `N=1` 當統計顯著結果 |
| 標示哪些權重項目已有實測證據、哪些仍是空白 | 把官方能力宣稱（docs/whitepaper）當作實測結果 |
| 作為下一輪驗證（N=3、相容性矩陣、PITR）的優先順序依據 | 把 stress benchmark（go-tpc）當作正式 TPC-C 認證 |
| 在同群組內比較不同拓樸（單節點 vs 三節點）的擴展方向 | 只看部分加權總分而忽略尚未量測的權重（MySQL 34%、PostgreSQL 24%） |

## 決策前必補的驗證

1. **實際 application SQL/ORM/driver 相容性矩陣**
   完成後可解除：「協定改造成本未知」的風險，才能判斷是否值得跨出 MySQL 協定。

2. **PITR、備份還原與 RPO 實測**
   完成後可解除：「災難復原能力未驗證」的風險——這是兩組都尚未量測的高權重項目（各佔 4%）。

3. **Online DDL 對前台 throughput/latency 的影響**
   完成後可解除：「線上變更 schema 是否可承受」的風險（兩組各佔 10%，屬未測缺口中權重最高項目之一）。

4. **代表性 cell 補 `N=3`**
   完成後可解除：「單次重跑波動被誤讀為架構差異」的風險，讓已測 56% 的方向性結論升級為可對外使用的 baseline。

5. **依 104 產品情境確認 A/S、A/A Read Only、A/A 是否真有需求**
   完成後可解除：「為不存在的需求付出跨區成本」的風險，避免在未確認需求前就投入跨區部署。

6. **TCO / 維運人力 / 授權 / 跨區網路成本**
   原檔沒有數字的項目一律標「待建立」，不可補估值；完成後可解除：「總持有成本未知就啟動專案」的風險。

## 建議閱讀路徑

| 想回答的問題 | 前往原評分表 |
|---|---|
| 評分規則與兩群組如何分組 | [§2 評分總表（依協定/架構分組）](./DISTRIBUTED-DB-SCORING.md#2-評分總表依協定架構分組) |
| 單節點延遲 / 水平擴展 / 高併發穩定性細節 | [§3.2.1](./DISTRIBUTED-DB-SCORING.md#321-單節點低併發延遲vm-1node-rc)、[§3.2.2](./DISTRIBUTED-DB-SCORING.md#322-水平擴展能力vm-1node--vm-3node-haproxy-3s3r)、[§3.2.3](./DISTRIBUTED-DB-SCORING.md#323-高併發穩定性t1285-round-rangemean-與-error-rate) |
| Failover 完整數據 | [§3.3.1](./DISTRIBUTED-DB-SCORING.md#331-failover-rtorpo--2026-08-11-真實重跑完成)、[§3.3.1a](./DISTRIBUTED-DB-SCORING.md#331a-mysql-相容群組galerapxc-84chaosfailover-實測2026-08-13) |
| 跨區穩態吞吐（exploratory，不計分） | [§3.6](./DISTRIBUTED-DB-SCORING.md#36-mysql-相容群組percona-xtradb-cluster-84pxcgalera跨區-p-ap-b-穩態吞吐量實測2026-08-12) |
| 部分加權分數怎麼算出來 | [§4.1](./DISTRIBUTED-DB-SCORING.md#41-mysql-相容群組mysql-galera-cluster-vs-tidb)、[§4.2](./DISTRIBUTED-DB-SCORING.md#42-postgresql-相容群組yugabytedb-vs-cockroachdb) |
| 結論與下一步建議 | [§5.1](./DISTRIBUTED-DB-SCORING.md#51-mysql-相容群組percona-xtradb-cluster-84pxcgaleravs-tidb)、[§5.2](./DISTRIBUTED-DB-SCORING.md#52-postgresql-相容群組yugabytedb-vs-cockroachdb)、[§5.3](./DISTRIBUTED-DB-SCORING.md#53-兩組共通的下一步建議依風險與可行性排序) |
| 原始測試證據索引 | [`results/README.md`](./results/README.md)、[`results/x-cross/README.md`](./results/x-cross/README.md) |
