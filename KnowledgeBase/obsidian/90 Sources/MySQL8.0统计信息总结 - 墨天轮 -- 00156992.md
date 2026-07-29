---
doc_id: "001569921a9bb9ed2b9b5384beec7bbe"
title: "MySQL8.0统计信息总结 - 墨天轮"
aliases:
  - "MySQL8.0统计信息总结 - 墨天轮"
url: "https://www.modb.pro/db/1901545046118248448?utm_source=index_ori"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "MySQL 8.0"
  - "DBA"
  - "优化器"
  - "统计信息"
  - "执行计划"
  - "性能调优"
  - "InnoDB"
generated: true
---

# MySQL8.0统计信息总结 - 墨天轮

> [!info] Provenance
> - doc_id: `001569921a9bb9ed2b9b5384beec7bbe`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1901545046118248448?utm_source=index_ori)
> - PDF: [open local PDF](../../collector/001569921a9bb9ed2b9b5384beec7bbe.pdf)

## Summary

本文介绍 MySQL 8.0 统计信息对优化器执行计划的影响，区分非持久化与持久化统计信息，说明触发更新机制、采样参数、持久化统计信息表、准确性影响因素及提升方法。

## Knowledge Outline

- 概念描述 — MySQL, 优化器, 统计信息, 执行计划
- 统计信息管理 — MySQL, 统计信息, Persistent Statistics
- 非持久性优化器统计信息 — MySQL, InnoDB, 非持久化统计信息, innodb_stats_persistent
- 非持久统计采样页参数 — MySQL, InnoDB, innodb_stats_transient_sample_pages, 采样, 性能调优
- 持久性优化器统计信息 — MySQL, InnoDB, 持久化统计信息, innodb_stats_persistent
- mysql.innodb_table_stats — MySQL, InnoDB, mysql.innodb_table_stats, 统计信息表
- mysql.innodb_index_stats — MySQL, InnoDB, mysql.innodb_index_stats, 索引统计信息
- 索引统计信息查询示例 — MySQL, InnoDB, mysql.innodb_index_stats, 索引基数
- 持久化统计信息准确性来源 — MySQL, 统计信息准确性, innodb_stats_persistent_sample_pages, 直方图, ANALYZE TABLE
- 统计信息准确性影响因素 — MySQL, 统计信息准确性, 数据分布, 索引结构, 直方图
- 提高统计信息准确性 — MySQL, 性能调优, ANALYZE TABLE, OPTIMIZE TABLE, 直方图, 索引优化
- 相关参数 — MySQL, InnoDB, innodb_stats_persistent, innodb_stats_auto_recalc, innodb_stats_method
- 总结 — MySQL, 统计信息, 优化器, 执行计划

## Repository Paths

- PDF: `collector/001569921a9bb9ed2b9b5384beec7bbe.pdf`
- Extracted: `generated/extracted/001569921a9bb9ed2b9b5384beec7bbe/full.md`
- Filtered: `generated/filtered/001569921a9bb9ed2b9b5384beec7bbe/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
