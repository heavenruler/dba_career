# PoC 對照驗證報告

> 版本：2026-07-11｜判讀原則：目前統一為 `N=1`；證據不足時標示待驗證，不以設計規格代替實測。

## 管理摘要

- [本 PoC 實測｜N=1] `S-BASE` 與 `S-K8S` 可支持相同控制條件下的吞吐、延遲、錯誤率及部署差異觀察；不構成生產容量或 SLA 承諾。
- [本 PoC 實測｜N=1] `X-CROSS` 目前只有 TiDB P-A/A-S、W=128 的正式口徑 cell；`baseline_eligible=false`，不得併入跨家排名。
- [待驗證] A/A-RO、A/A、備份還原、資料遷移與 failover/chaos 尚未完成實跑；目前只能審查方法，不能宣稱 DR 或零停機能力已通過。
- [決策] 選型需同時考量一致性、延遲、可用性、應用改造、安全、維運與五年成本，不以單一 tpmC 排名。

## 驗證覆蓋

| 驗證面 | 目前證據 | 狀態 | 可引用結論 | 缺口或風險 |
|---|---|---|---|---|
| 一致性 | 三家 isolation gate、單節點三 isolation、RC 主矩陣 | 部分完成，N=1 | 設定是否生效及不同 isolation 下的相對行為 | 尚未以 104 服務交易做 anomaly/retry 驗收 |
| 延遲 | S-BASE/S-K8S 的 p95/p99、X-CROSS 單一正式 cell | 部分完成，N=1 | 同一 scope 內的尾端延遲差異 | 不可外推正式 SLA；跨區 paired control 未完成 |
| 可用性 | topology/marker、部分 placement 與 framework smoke | 未完成 | 可確認部分流程與放置 gate 可執行 | failover、RTO/RPO、資料完整性與 restore 未實測 |
| 錯誤率 | stdout Summary 經 parser 彙整 | 已建立口徑 | 可與 throughput/latency 同表判讀 | 需逐 cell 確認缺 round、hang 與 summary lineage |
| Kubernetes | 三家 limit/unlimit 六個 cell | 已完成，N=1 | 可觀察資源宣告下的差異 | 尚不能只靠數字認定 throttling/OOM 根因 |
| 資源隔離 | `T-THRD` framework 與調參規格 | 探索中 | 可隔離調參結果，不污染 baseline | 無可作 baseline 的 N=3 或正式 sizing 結論 |
| 跨區 | TiDB P-A/A-S W=128 單一 cell | 探索中，N=1 | framework 與該 cell 可追溯 | 不能跨家比較、不能宣稱 WAN penalty 或 DR |

## 104 應用適性

| 應用原型 | 適性判讀焦點 | PoC 可提供 | 上線前必補 |
|---|---|---|---|
| 核心交易 | 強一致、冪等、retry、尾端延遲、RPO | isolation 與壓力行為觀察 | 真實交易回歸、故障對帳、RTO/RPO |
| 讀取密集 | stale read 邊界、快取、回源與峰值 | 讀寫模式與資源對照方法 | API 級 staleness/SLO 驗收 |
| 高併發熱點 | 熱鍵、鎖競爭、admission 與降載 | 多併發水位與錯誤率口徑 | 熱點資料模型與服務級壓測 |
| 批次與資料整合 | 長交易、批次切片、與線上流量隔離 | 資源控制與調參框架 | migration/CDC、重跑、對帳與窗口演練 |

詳細條件見[應用就緒性](../11-application-readiness.md)。目前沒有足夠證據指定單一候選；應依服務契約形成條件式適用矩陣。

## 採信規則

1. 數字只引用已提交的流程紀錄、`summary.json` 或其 raw stdout；官方文件只證明能力存在。
2. 每個 cell 必須同時揭露 workload、拓樸、isolation、`N`、round 選取與缺失資料。
3. failed run、hang、監控缺失與環境限制不得省略；`N=1` 不宣稱統計顯著。
4. `S-BASE`、`S-K8S`、`T-THRD`、`X-CROSS` 不跨 scope 混表或排名。

## 決策與待決

| 項目 | 狀態 | 下一個簽核證據 |
|---|---|---|
| 進入服務級試行 | 待決 | 選一個低風險原型，完成安全、相容性、restore 與回切演練 |
| 跨區模式 | 待決 | 依序驗證 A/S、A/A-RO、A/A，不互相外推 |
| 最終候選 | 未決 | 補應用契約、維運責任、五年 TCO 與必要故障演練 |
| N=3 | 時程允許再補 | 保留 N=1，對代表性案例比較獨立重建差異 |

來源：[PoC 設計](../../results/PoC-DESIGN.md)｜[結果索引](../../results/README.md)｜[X-CROSS pipeline log](../../results/x-cross/pipeline-log.md)｜[Phase Registry](../../results/PHASES.md)
