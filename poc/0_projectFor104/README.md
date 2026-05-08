# [分散式資料庫架構 PoC](https://104corp.atlassian.net/browse/ITDBA-3596)

```
opencode -s ses_28f349b65ffesqMOs3ScraWUt4
claude --resume 39164c14-87bc-4b78-a426-385135878d3f
```

## PoC 目標

本 PoC 用於驗證分散式資料庫架構是否可滿足 104Corp 既有業務系統需求。

Goal: 分散式資料庫部署不應因任何因素（例如停機維護）導致服務中止或暫停。

- 可用性：單點故障時可持續提供服務
- 擴充性：可支援資料量與流量成長
- 一致性：確認交易、複寫與故障切換行為
- 維運性：備援、監控、告警、備份與還原流程可操作
- 成本可行性：評估導入與營運成本是否合理

## 文件索引

| 用途 | 檔案 |
| --- | --- |
| 選型比較（9 維度 survey 表） | [`docs/survey.md`](./docs/survey.md) |
| Test case 定義、metrics、驗收重點 | [`docs/test-design.md`](./docs/test-design.md) |
| 部署流程、IaC 需求、執行 runbook | [`docs/execution-runbook.md`](./docs/execution-runbook.md) |
| TiDB 架構圖（Mermaid） | [`docs/architecture/tidb.md`](./docs/architecture/tidb.md) |
| YugabyteDB 架構圖（Mermaid） | [`docs/architecture/yugabytedb.md`](./docs/architecture/yugabytedb.md) |

## Requirements for Consultant

以下文件列出外部顧問（或評估廠商）在參與 PoC 時必須提前閱讀/了解的技術規格，確保顧問的建議是基於我們的實際環境與需求。

- [TiDB](https://hackmd.io/@a0SKFQ6dSo6shLxkFRvsBw/SycRGvKAWe) — TiDB 架構需求文件（顧問必讀：我們的部署限制、版本、配置需求）
- [YugabyteDB](https://hackmd.io/@a0SKFQ6dSo6shLxkFRvsBw/SkhH4vt0Zx) — YugabyteDB 架構需求文件（同上）

> ⚠️ 內部文件，請確認連結分享權限。

## 目前狀態

測試執行中：YBDB VM 部分測試已完成，TiDB 測試進行中；IaC 狀態請確認最新進度。

下一步：補齊 vSphere / GCP 環境資訊後，開始建立 `infra/` Terraform 與 Ansible 骨架。

## 技術背景

本 PoC 執行過程中採用的關鍵技術／標準／工具，對應原理與選型考量說明如下。

### TPC：業界標準效能評測組織

**TPC**（Transaction Processing Performance Council，交易處理效能委員會）是 1988 年成立的非營利組織，由各大資料庫與硬體廠商共同制定資料庫效能評測標準。所有 TPC 標準都包含完整的工作負載定義、測量方法、結果發布規範，確保不同廠商發表的效能數字可被公平對比。

### TPC 系列標準總覽

| 標準 | 用途分類 | 模擬場景 |
|------|---------|---------|
| **TPC-C** | OLTP（線上交易處理） | 倉儲訂單處理（最廣泛使用，1992 起，本 PoC 採用） |
| **TPC-E** | OLTP | 證券交易公司運作（較新但業界採用度低） |
| **TPC-H** | OLAP（分析查詢） | 商業報表 ad-hoc 查詢 |
| **TPC-DS** | OLAP | 現代 BI 場景，更貼近實際資料倉儲 |
| **TPC-DI** | 資料整合 | ETL／資料管線效能 |
| **TPCx-HS** | 大數據 | Hadoop 排序與處理 |
| **TPCx-AI** | AI／ML | 模型訓練與推論 |
| **TPCx-IoT** | IoT | 物聯網時序資料注入 |
| **TPC-Energy** | 能效附加 | 在標準上加測能源消耗 |

### 為何本 PoC 選用 TPC-C

1. **業務情境貼近**：TPC-C 模擬倉儲下單／付款／出貨／庫存查詢的混合工作流，與 104 既有業務（履歷投遞、會員交易、人才搜尋）同屬 OLTP 短交易場景。
2. **跨資料庫公平基準**：TiDB／YugabyteDB／CockroachDB 三家官方均公布 TPC-C 結果，採此標準可直接與廠商與業界數據對比。
3. **能暴露架構差異**：TPC-C 的熱點競爭、跨表交易、混合讀寫設計可同時驗證資料庫的隔離機制、鎖定策略、MVCC 行為與分散式交易能力——這正是 PoC 想確認的核心問題。

### 為何採用 go-tpc 而非官方 BenchmarkSQL

| 比較項目 | BenchmarkSQL（官方參考實作） | go-tpc（PingCAP 維護） |
|---------|---------------------------|----------------------|
| 語言／部署 | Java，須裝 JDK + JDBC driver | Go 單一 binary，跨平台部署簡單 |
| 多協定支援 | JDBC（切換 driver 麻煩） | 內建 MySQL + PostgreSQL 協定（覆蓋本 PoC 三家測試對象） |
| 維護活躍度 | 更新緩慢 | 高，持續適配新版資料庫 |
| 擴充性 | 修改成本高 | 程式碼結構清楚，新增 dialect 容易 |
| 限制 | 標準支援 think time（用戶操作間隔） | 不支援 think time（適合壓力測試極限，但無法模擬真實節奏） |

### go-tpc 運作原理

1. **prepare 階段**：依設定的 warehouse 數量建立 9 張 TPC-C 資料表（warehouse／district／customer／item／stock／orders／order_line／new_orders／history），並載入符合規範的初始資料（含隨機分布與引用完整性）。
2. **run 階段**：
   - 啟動 N 個 goroutine（每個對應一條同時進行的資料庫連線），先暖機 5 分鐘填滿快取並穩定狀態。
   - 每個 goroutine 依 TPC-C 標準的交易混比隨機抽樣下一筆交易：**NEW_ORDER 45%、PAYMENT 43%、ORDER_STATUS 4%、DELIVERY 4%、STOCK_LEVEL 4%**。
   - 一筆交易完成立即發下一筆，**無 keying time／think time**（持續滿載，是 go-tpc 與官方標準最大的差異點）。
   - 即時統計 tpmC（每分鐘新訂單交易數）、tpmTotal、延遲分布（P50／P90／P95／P99）、錯誤計數。
   - 單筆交易超過 16,106 ms（≈16 秒）即標記為 timeout。
3. **check 階段**：執行 TPC-C 規範的 12 條跨表一致性驗證 SQL（condition 3.3.2.1 ~ 3.3.2.12），確認壓測過程中資料庫狀態未被破壞。

### go-tpc 如何體現 TPC-C 的複雜度

go-tpc 忠實實作 TPC-C 規範，下列 6 點是真正讓這個 benchmark 有別於「無腦壓測」、能夠暴露分散式資料庫架構差異的核心設計：

1. **多表寫入交易**：一筆 NEW_ORDER 同時更新最多 7 張資料表（warehouse／district／customer／orders／new_orders／order_line／stock），任一表寫入失敗整筆交易必須 rollback。
2. **熱點競爭設計**：每個 warehouse × district 共用一個 `D_NEXT_O_ID` 訂單流水號欄位（128 倉 × 10 區 = 1280 個熱點 row），所有 NEW_ORDER 都必更新這個欄位，是高併發下鎖／MVCC 衝突的集中點，也是區分悲觀鎖 vs 樂觀 MVCC 行為的關鍵戰場。
3. **跨倉庫遠端呼叫**：依規範約 1% 的 NEW_ORDER 必須跨 warehouse 取貨（remote item），模擬真實分散式場景中的 cross-shard transaction。
4. **隔離等級行為驗證**：DELIVERY 為 read-modify-write 模式，會放大 optimistic MVCC vs 悲觀鎖定機制下的衝突處理差異，是區分資料庫架構走向的關鍵交易。
5. **真實統計分布**：客戶 ID 採用 NURand 函數產生，模擬真實業務的 80／20 熱點分布；商品價格、訂單行數皆有官方規範的分布範圍，避免 uniform 隨機掩蓋熱點問題。
6. **資料一致性硬性驗證**：壓測結束後 check 階段強制驗證 12 條跨表 condition（例如 `sum(O_OL_CNT)` 必須等於 `count(order_line)`），確保資料庫在高壓下未產生資料遺失或不一致。
