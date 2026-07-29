---
doc_id: "864da5709363c16af76f365306c1a0f1"
title: "MySQL 有没有类似 Oracle 的索引监控功能？ - 墨天轮"
aliases:
  - "MySQL 有没有类似 Oracle 的索引监控功能？ - 墨天轮"
url: "https://www.modb.pro/db/1901881763480219648?utm_source=index_ori"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "Performance Schema"
  - "sys Schema"
  - "索引监控"
  - "性能优化"
  - "DBA"
generated: true
---

# MySQL 有没有类似 Oracle 的索引监控功能？ - 墨天轮

> [!info] Provenance
> - doc_id: `864da5709363c16af76f365306c1a0f1`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1901881763480219648?utm_source=index_ori)
> - PDF: [open local PDF](../../collector/864da5709363c16af76f365306c1a0f1.pdf)

## Summary

本文回答 MySQL 8.0 是否有类似 Oracle 索引监控功能，核心做法是通过 performance_schema.table_io_waits_summary_by_index_usage 和 sys.schema_index_statistics 查看索引使用情况，并提醒覆盖索引、统计重置、performance_schema 开启状态与慢查询日志分析等限制。

## Knowledge Outline

- 背景 — MySQL, Oracle, 索引监控, DBA
- 小记 — MySQL, Performance Schema, 索引监控, 性能优化
- Performance Schema 监控索引 — MySQL, Performance Schema, SQL, 索引监控
- sys Schema 简化分析 — MySQL, sys Schema, information_schema, SQL, 索引监控
- 重置统计 — MySQL, Performance Schema, 运维, 统计重置
- 慢查询日志 — MySQL, 慢查询日志, EXPLAIN, 索引优化
- 注意事项 — MySQL, 索引监控, 覆盖索引, 注意事项
- 总结 — MySQL, Performance Schema, sys Schema, 性能优化, DBA
- 参考链接 — MySQL, 参考资料, Performance Schema, sys Schema

## Repository Paths

- PDF: `collector/864da5709363c16af76f365306c1a0f1.pdf`
- Extracted: `generated/extracted/864da5709363c16af76f365306c1a0f1/full.md`
- Filtered: `generated/filtered/864da5709363c16af76f365306c1a0f1/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
