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

### [TPC](https://www.tpc.org/)：業界標準效能評測組織

**[TPC](https://www.tpc.org/)**（Transaction Processing Performance Council，交易處理效能委員會）是 1988 年成立的非營利組織，由各大資料庫與硬體廠商共同制定資料庫效能評測標準。所有 TPC 標準都包含完整的工作負載定義、測量方法、結果發布規範，確保不同廠商發表的效能數字可被公平對比。

### TPC 系列常用標準

| 標準 | 用途分類 | 模擬場景 |
|------|---------|---------|
| **TPC-C** | OLTP（線上交易處理） | 倉儲訂單處理（業界最廣泛使用，1992 起；**本 PoC 採用**） |
| **TPC-E** | OLTP | 證券交易公司運作（較新，作為 TPC-C 的現代替代但採用度較低） |
| **TPC-H** | OLAP（分析查詢） | 商業報表 ad-hoc 查詢，資料倉儲基準 |
| **TPC-DS** | OLAP | 現代 BI／資料倉儲場景，比 TPC-H 更貼近實務 |

> 其他附加／領域標準（TPC-DI、TPCx-HS、TPCx-AI、TPCx-IoT、TPC-VMS、TPC-Energy 等）涵蓋 ETL、Hadoop、AI／ML、IoT、虛擬化、能效附加等場景，本 PoC 不涉及。完整清單見 [tpc.org](https://www.tpc.org/information/benchmarks5.asp)。

### 為何本 PoC 選用 TPC-C

1. **業務情境貼近**：OLTP 短交易，對齊 104 履歷投遞／會員／搜尋場景。
2. **跨資料庫公平基準**：TiDB／YugabyteDB／CockroachDB 三家官方皆公布 TPC-C 結果。
3. **能暴露架構差異**：熱點競爭 + 跨表交易可同時驗證隔離、鎖、MVCC 與分散式行為。

### 為何採用 [go-tpc](https://github.com/pingcap/go-tpc) 而非官方 BenchmarkSQL

| 項目 | BenchmarkSQL | go-tpc |
|------|--------------|--------|
| 語言／部署 | Java + JDBC | Go 單一 binary |
| 多協定 | JDBC 切 driver | 內建 MySQL + PostgreSQL |
| 維護 | 緩慢 | PingCAP 持續更新 |
| 限制 | 支援 think time | 不支援 think time（壓極限） |

### go-tpc 運作原理

1. **prepare**：建 9 張 TPC-C 表並載入指定 warehouse 量的規範資料。
2. **run**：N 個 goroutine 持續按官方混比（NEW_ORDER 45% / PAYMENT 43% / 其餘各 4%）發交易，無 think time，即時統計 tpmC 與 P50–P99；單筆 >16s 標記 timeout。
3. **check**：執行 12 條一致性驗證 SQL（condition 3.3.2.x），確保壓測未破壞資料庫狀態。

### go-tpc 如何體現 TPC-C 的複雜度

1. **多表寫入交易**：一筆 NEW_ORDER 同時更新最多 7 張表，任一失敗整筆 rollback。
2. **熱點競爭**：`district.D_NEXT_O_ID`（1280 row）為高併發衝突集中點，分辨悲觀鎖 vs 樂觀 MVCC 的關鍵戰場。
3. **跨倉庫呼叫**：~1% NEW_ORDER 跨 warehouse，觸發 cross-shard 交易。
4. **隔離行為驗證**：DELIVERY 的 read-modify-write 放大 MVCC vs 鎖差異。
5. **NURand 分布**：模擬真實 80／20 熱點，避免 uniform 隨機掩蓋問題。
6. **一致性硬驗證**：check 階段強制 12 條跨表 condition，確保資料無遺失或不一致。
