---
doc_id: "836dd0d3a1fafd647498cb0d2cbe5083"
title: "MYSQL proxysql 在深入 信息获取和信息输出-腾讯云开发者社区-腾讯云"
aliases:
  - "MYSQL proxysql 在深入 信息获取和信息输出-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/1695487"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "ProxySQL"
  - "MySQL"
  - "DBA"
  - "監控"
  - "日誌"
  - "讀寫分離"
  - "主從複製"
generated: true
---

# MYSQL proxysql 在深入 信息获取和信息输出-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `836dd0d3a1fafd647498cb0d2cbe5083`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/1695487)
> - PDF: [open local PDF](../../collector/836dd0d3a1fafd647498cb0d2cbe5083.pdf)

## Summary

文章介绍 ProxySQL 透過 global variables、audit log、events log、stats_* 與 monitor 日誌來做資訊獲取與監控，並說明如何判讀連通性、連線時間與主從角色。

## Knowledge Outline

- 全局变量概览 — ProxySQL, MySQL, global variables, DBA
- 审计日志配置 — ProxySQL, audit log, MySQL, DBA, 安全审计
- 查询日志与规则 — ProxySQL, query log, mysql_query_rules, MySQL, 監控
- 运行状态与内存统计 — ProxySQL, 内存, 运行状态, 统计, DBA
- 命令统计与连接池 — ProxySQL, stats_mysql_commands_counters, stats_mysql_connection_pool, stats_mysql_processlist, stats_mysql_query_digest, MySQL, 監控
- Monitor 日志判读 — ProxySQL, monitor, mysql_server_ping_log, mysql_server_connect_log, mysql_server_read_only_log, 复制集, 告警
- 复制集状态与监控方式 — ProxySQL, PMM, WEB监控, 讀寫分離, 主從延遲

## Repository Paths

- PDF: `collector/836dd0d3a1fafd647498cb0d2cbe5083.pdf`
- Extracted: `generated/extracted/836dd0d3a1fafd647498cb0d2cbe5083/full.md`
- Filtered: `generated/filtered/836dd0d3a1fafd647498cb0d2cbe5083/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
