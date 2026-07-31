---
doc_id: "44862aef1f3e9f432840f303bb9da948"
chunk_id: "44862aef1f3e9f432840f303bb9da948:0003"
source_kind: "llm_filtered"
knowledge_type: runbook
status: evergreen
primary_expert: "DBA"
expert_domains: ["DBA", "SRE Platform"]
risk_level: high
review_status: approved
preconditions: ["已確認 mysqld PID", "具備 performance_schema 查詢權限", "kill 前已取得應用 owner 確認"]
validation: ["CPU 使用率下降", "目標 thread/session 已消失", "應用錯誤率未惡化"]
rollback: ["kill 無法回滾；由應用重試或重新建立連線", "若誤判立即通知應用 owner 並停止後續處置"]
evidence: ["44862aef1f3e9f432840f303bb9da948:0002", "44862aef1f3e9f432840f303bb9da948:0003"]
tested_on: "source-documented MySQL environment; local execution not performed"
---

# MySQL CPU 100% 證據保全與定位

## Symptom

`mysqld` CPU 使用率異常，業務回報卡頓。

## Checks

```text
top
free -h
top -H -p `pidof mysqld`
```

透過 OS thread ID 對應 `performance_schema.threads` 與 SQL。確認應用 owner、SQL 與影響範圍後，才評估 `kill`。

## Risk

`kill` 會中止目標 session，可能造成交易 rollback、應用錯誤或重試流量。此操作不可回滾。

## Evidence

- doc_id: `44862aef1f3e9f432840f303bb9da948`
- chunk_id: `44862aef1f3e9f432840f303bb9da948:0002`, `44862aef1f3e9f432840f303bb9da948:0003`
- source_kind: `llm_filtered`
- Source: [[CPU又100%了 -- 44862aef]]
- Review: [[44862aef1f3e9f432840f303bb9da948]]
