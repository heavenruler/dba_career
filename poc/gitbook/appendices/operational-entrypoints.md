# 附錄：操作入口

僅列出受控入口與文件，不複製命令、帳密、位址或環境細節。production 操作需依變更單與權限政策執行。

| 作業 | 入口 | 結果／驗收 |
|---|---|---|
| 跨區狀態與流程 | [phase-crossregion README](../../phase-crossregion/README.md) | scope、phase、執行限制 |
| Pre-flight | [Pre-flight plan](../../phase-crossregion/PRE-FLIGHT-TEST-PLAN-2026-06-17.md) | health、clock、placement gates |
| PoC 結果採信 | [X-CROSS pipeline log](../../results/x-cross/pipeline-log.md) | summary、round、缺失資料 |
| RTO/RPO 演練 | [Methodology](../../phase-crossregion/failover/RTO-RPO-methodology.md) | driver probe、leader、資料比對 |
| Backup/migration | [backup](../../phase-crossregion/workload-profiles/backup.md)｜[migration](../../phase-crossregion/workload-profiles/migration.md) | timeline、restore/對帳、abort |
| Security release | [安全與治理](../12-security-and-governance.md) | hard-gate evidence |
| Go/No-go | [實施計畫](../deliverables/implementation-plan.md) | 簽核、回滾、on-call |

禁止：以本附錄為 production runbook、使用未核准 bypass、在結果紀錄或 ticket 中貼入 secrets、個資或實際 IP。
