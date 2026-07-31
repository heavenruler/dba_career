---
doc_id: "41446ccd753567640b5543201715fb85"
chunk_id: "41446ccd753567640b5543201715fb85:0001"
source_kind: "llm_filtered"
knowledge_type: case
status: evergreen
primary_expert: "Solution Architecture"
expert_domains: ["Solution Architecture", "DBA", "SRE Platform"]
risk_level: medium
review_status: approved
---

# Aurora MySQL 到 TiDB 遷移案例

## Context

Plaid 將多數服務由 AWS Aurora MySQL 轉移到 TiDB，目標同時涵蓋可靠性、工程速度與未來成長。

## Decision frame

- 驗證資料一致性與功能相容性
- 控制 service cutover 的中斷風險
- 準備 rollback strategy
- 以 runbook 自動化降低跨團隊操作差異

## Evidence

- doc_id: `41446ccd753567640b5543201715fb85`
- chunk_id: `41446ccd753567640b5543201715fb85:0001`
- source_kind: `llm_filtered`
- Source: [[Cutting over Our journey from AWS Aurora MySQL to TiDB Plaid -- 41446ccd]]
- Review: [[41446ccd753567640b5543201715fb85]]
