# 13. Day-2 維運與 DR

> 最後驗證：2026-07-11｜RTO/RPO 方法已定義；跨區 failover、backup restore 與 chaos 實跑尚未完成。

## Day-2 最小作業面

| 作業 | 日常 | 事件時 | 交接紀錄 |
|---|---|---|---|
| 健康與容量 | 節點、複寫、磁碟、連線、延遲、錯誤率 | 凍結擴散性操作，判斷 quorum/leader | dashboard、SLO、容量趨勢 |
| 變更 | 版本、schema、參數、憑證經審查 | 回退已核准變更或停止 rollout | 變更單、前後指標 |
| 備份 | 檢查完成、完整性與保留 | 依 runbook 進行 restore | restore 證據、RPO 實測 |
| 事件 | on-call 分級、通報、時間線 | 先保一致性，再恢復服務 | incident report、RCA |
| 演練 | 定期 tabletop 與 restore | A/S failover 僅於核准演練 | drill report、改進項 |

## DR 模式與邊界

| 模式 | 正常流量 | 故障目標 | 已知邊界 |
|---|---|---|---|
| A/S | 主區讀寫，備區待命 | 備區接手 | 可作主要 DR 候選；RTO/RPO 尚待實測 |
| A/A-RO | 主區寫，兩區讀 | 異地讀可降級 | 必標 stale-read 與 read-your-write 邊界 |
| A/A | 兩區讀寫 | 維持衝突可控 | 先證明衝突、重試與延遲可接受；非預設生產模式 |

RTO 採「事故發生至第一筆成功寫入 commit」；RPO 採事故前後已 commit 交易差異。此為量測定義，不是目前已達成的承諾。[待驗證]

## 演練閘門

1. 變更單、DBA 與應用 owner 簽核；資安確認演練資料與權限。
2. 時鐘同步、placement actual、cluster health、監測與回退路徑全部通過。
3. 在單一 driver 量測 RTO；同時保存成功寫入、leader/placement 與資料比對證據。
4. 演練結束後確認資料完整、解除凍結、恢復告警；未完成不得關單。

## 證據與限制

- [待驗證] X-CROSS 的 chaos/F1 目前為 planner-only，實跑需要獨立 PR 與 DBA review。[跨區 README](../phase-crossregion/README.md)
- [待驗證] RTO/RPO 指標、誤差與升級條件已有方法論；閾值多為 TBD。[RTO/RPO 方法](../phase-crossregion/failover/RTO-RPO-methodology.md)
- [本 PoC 實測｜N=1] 唯一可引用的跨區 W=128 正式 cell 為 TiDB P-A/A-S N=1；不可推論 DR 成功或跨家排名。[X-CROSS pipeline log](../results/x-cross/pipeline-log.md)

## 決策與待決

| 決策 | 狀態 | Owner |
|---|---|---|
| 服務級 RTO/RPO、降級讀取與通報窗口 | 待核定 | 應用 owner、業務 owner |
| A/S failover、restore、C4/F1 演練排程 | 待核定 | DBA、平台 |
| on-call、升級路徑與廠商支援責任 | 待核定 | 維運主管、採購 |
