# 附錄：證據地圖

| ID | 標籤 | 可支持的事實 | 來源 | 不可延伸 |
|---|---|---|---|---|
| E1 | [決策] | TPC-C-derived、S-BASE 範圍與控制條件 | [PoC 設計](../../results/PoC-DESIGN.md) | audited TPC-C、生產 SLA |
| E2 | [決策] | phase scope 與 X-CROSS 不可進主表 | [Phase Registry](../../results/PHASES.md) | 跨 family 效能排名 |
| E3 | [本 PoC 實測｜N=1] | X-CROSS 結果採信、P-A/A-S W=128 單一 cell | [pipeline log](../../results/x-cross/pipeline-log.md) | 跨家推薦、DR 成功 |
| E4 | [待驗證] | A/S、A/A-RO、A/A 的 client/placement 設計 | [workload profiles](../../phase-crossregion/README.md) | 已可上線 |
| E5 | [待驗證] | RTO/RPO 公式、演練所需證據 | [methodology](../../phase-crossregion/failover/RTO-RPO-methodology.md) | 已達到任何 RTO/RPO |
| E6 | [待驗證] | backup/migration 指標與 abort 構想 | [backup](../../phase-crossregion/workload-profiles/backup.md)｜[migration](../../phase-crossregion/workload-profiles/migration.md) | restore/zero downtime 已驗證 |
| E7 | [待驗證] | security、TCO、服務級契約 | 本 GitBook 第 12、15 章 | 合規或成本結論 |
| E8 | [本 PoC 實測｜N=1] | 三家單區 VM 與三節點結果 | [TiDB](../../results/tidb-tc1/S-BASE/pipeline-log.md)｜[CockroachDB](../../results/crdb-tc1/S-BASE/pipeline-log.md)｜[YugabyteDB](../../results/yuga-tc1/S-BASE/pipeline-log.md) | 正式容量、SLA、跨環境結論 |
| E9 | [本 PoC 實測｜N=1] | 三家 Kubernetes limit/unlimit 結果及例外 | [TiDB](../../results/tidb-tc1/S-K8S/pipeline-log.md)｜[CockroachDB](../../results/crdb-tc1/S-K8S/pipeline-log.md)｜[YugabyteDB](../../results/yuga-tc1/S-K8S/pipeline-log.md) | VM 對 Kubernetes 損益、因果根因 |

標籤規則以本手冊首頁定義為準。官方文件只支持 `[官方能力]`；實際完成狀態與數字必須回到已提交的流程紀錄和 `summary.json`。

> **來源衝突處理：** `S-K8S` 的目前完成狀態以三家 `S-K8S/pipeline-log.md` 與其 `summary.json` 為準。`phase-k8s/README.md` 或 `results/README.md` 若仍顯示早期「待重跑」文字，視為過時索引，不覆蓋較新的流程紀錄。
