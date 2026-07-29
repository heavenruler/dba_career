---
doc_id: "9793d273762077412ec1100458f4fee7"
title: "[MySQL FAQ]系列 — MySQL复制中slave延迟监控-腾讯云开发者社区-腾讯云"
aliases:
  - "[MySQL FAQ]系列 — MySQL复制中slave延迟监控-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/2185089"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "复制"
  - "主从延迟"
  - "slave延迟监控"
  - "binlog"
  - "SHOW SLAVE STATUS"
  - "效能监控"
generated: true
---

# [MySQL FAQ]系列 — MySQL复制中slave延迟监控-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `9793d273762077412ec1100458f4fee7`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/2185089)
> - PDF: [open local PDF](../../collector/9793d273762077412ec1100458f4fee7.pdf)

## Summary

本文讨论 MySQL 复制环境中 slave 延迟监控的判断方式，指出仅依赖 Seconds_Behind_Master 不够准确，并结合 SHOW SLAVE STATUS、SHOW PROCESSLIST、MASTER/SLAVE binlog 差异给出更严谨的延迟判断方法。

## Knowledge Outline

- Seconds_Behind_Master 不够准确 — MySQL, 复制, slave延迟
- SLAVE 状态示例 — SHOW SLAVE STATUS, Seconds_Behind_Master, binlog
- Seconds_Behind_Master 读数说明 — Seconds_Behind_Master, 复制线程
- REPLICATION 进程状态示例 — SHOW PROCESSLIST, Replication, SQL线程, IO线程
- Time 值的含义 — SHOW PROCESSLIST, Time, SQL线程, Seconds_Behind_Master
- IO 线程 Time 异常 — IO线程, Time, 系统时间
- 无活跃 SQL 与活跃 SQL 对比 — pager, SHOW PROCESSLIST, SHOW SLAVE STATUS, Exec_Master_Log_Pos, Read_Master_Log_Pos
- 判断 SLAVE 延迟的方法 — slave延迟监控, Relay_Master_Log_File, Master_Log_File, Exec_Master_Log_Pos, Read_Master_Log_Pos
- MASTER Binary Logs 示例 — SHOW BINARY LOGS, MASTER, binlog
- SLAVE Status 示例 — SHOW SLAVE STATUS, SLAVE, Read_Master_Log_Pos, Exec_Master_Log_Pos
- 实际延迟计算 — binlog, 延迟计算, binlog event

## Repository Paths

- PDF: `collector/9793d273762077412ec1100458f4fee7.pdf`
- Extracted: `generated/extracted/9793d273762077412ec1100458f4fee7/full.md`
- Filtered: `generated/filtered/9793d273762077412ec1100458f4fee7/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
