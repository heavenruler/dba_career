---
doc_id: "7e04df7e492af937f3db7351c4bd43b8"
title: "Using Blue/Green Deployment For (near) Zero-Downtime Primary Key Updates in RDS MySQL"
aliases:
  - "Using Blue/Green Deployment For (near) Zero-Downtime Primary Key Updates in RDS MySQL"
url: "https://www.percona.com/blog/using-blue-green-deployment-for-near-zero-downtime-primary-key-updates-in-rds-mysql/"
source_domain: "www.percona.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "RDS"
  - "Aurora"
  - "Blue/Green Deployment"
  - "資料庫遷移"
  - "零停機部署"
  - "Schema Change"
  - "Replication"
  - "DBA"
generated: true
---

# Using Blue/Green Deployment For (near) Zero-Downtime Primary Key Updates in RDS MySQL

> [!info] Provenance
> - doc_id: `7e04df7e492af937f3db7351c4bd43b8`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.percona.com/blog/using-blue-green-deployment-for-near-zero-downtime-primary-key-updates-in-rds-mysql/)
> - PDF: [open local PDF](../../collector/7e04df7e492af937f3db7351c4bd43b8.pdf)

## Summary

本文說明如何使用 Amazon RDS Blue/Green Deployment，以近乎零停機方式在 RDS MySQL/Aurora 環境修改大型資料表的 primary key 相關欄位型別，包含建立 Blue/Green 環境、調整 replica_type_conversions、停止與啟動 replication、執行 ALTER TABLE、switchover 注意事項與 FAQ。

## Knowledge Outline

- 問題背景 — Blue/Green Deployment, RDS, Schema Change
- 建立 Blue/Green 環境 — RDS, Aurora, binlog_format, Blue/Green Deployment
- Replica 型別轉換設定 — MySQL Replication, replica_type_conversions, ALL_NON_LOSSY, int, bigint
- 停止 Replica — RDS, Replication, mysql.rds_stop_replication
- 變更前資料表定義 — MySQL, SHOW CREATE TABLE, Primary Key, Foreign Key
- 執行 ALTER TABLE — ALTER TABLE, Foreign Key, bigint, Schema Change
- 啟動 Replication 並確認同步 — Replication, mysql.rds_start_replication, SHOW REPLICA STATUS, Seconds_Behind_Source
- Switchover 注意事項 — Switchover, Replication, Application Writes
- 切換完成後驗證與清理 — Validation, RDS, Blue/Green Deployment
- 結論 — RDS Replication, MySQL Binary Log, Blue/Green Deployment
- FAQ — Rollback, MySQL Upgrade, Replica Error, Switchover

## Repository Paths

- PDF: `collector/7e04df7e492af937f3db7351c4bd43b8.pdf`
- Extracted: `generated/extracted/7e04df7e492af937f3db7351c4bd43b8/full.md`
- Filtered: `generated/filtered/7e04df7e492af937f3db7351c4bd43b8/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
