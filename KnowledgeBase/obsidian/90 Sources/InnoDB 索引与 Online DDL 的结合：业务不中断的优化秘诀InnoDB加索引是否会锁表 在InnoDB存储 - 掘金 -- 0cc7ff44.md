---
doc_id: "0cc7ff4443fbb0cb3c90ca79bc6b9dcd"
title: "InnoDB 索引与 Online DDL 的结合：业务不中断的优化秘诀InnoDB加索引是否会锁表 在InnoDB存储 - 掘金"
aliases:
  - "InnoDB 索引与 Online DDL 的结合：业务不中断的优化秘诀InnoDB加索引是否会锁表 在InnoDB存储 - 掘金"
url: "https://juejin.cn/post/7459359268521836570"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "Online DDL"
  - "索引"
  - "锁"
  - "DBA"
  - "性能优化"
  - "并发"
  - "SQL"
generated: true
---

# InnoDB 索引与 Online DDL 的结合：业务不中断的优化秘诀InnoDB加索引是否会锁表 在InnoDB存储 - 掘金

> [!info] Provenance
> - doc_id: `0cc7ff4443fbb0cb3c90ca79bc6b9dcd`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7459359268521836570)
> - PDF: [open local PDF](../../collector/0cc7ff4443fbb0cb3c90ca79bc6b9dcd.pdf)

## Summary

文章说明在 InnoDB 中添加索引是否锁表取决于索引类型与操作方式，重点介绍 Online DDL 的锁粒度、支持操作、MDL 与后台执行机制，并给出创建表、添加索引、监控进度和并发验证的 SQL 示例。

## Knowledge Outline

- 索引是否锁表 — InnoDB, 索引, 锁表, 行级锁, 表级锁, 性能影响
- Online DDL 概述 — Online DDL, MySQL, 锁粒度, 并发, DDL
- 支持范围与机制 — Online DDL, Metadata Lock, MDL, 行级锁, 后台线程, 支持范围
- 使用建议 — Online DDL, MySQL, 性能优化, 监控, 业务低峰期
- 测试表与在线索引 — MySQL, InnoDB, DDL, 普通索引, 唯一索引, SQL
- 全文索引与监控 — 全文索引, performance_schema, Online DDL, 监控, 锁表, SQL
- 并发场景与优化 — 并发, 索引, 锁=NONE, 数据验证, 重复数据, SQL, 性能优化

## Repository Paths

- PDF: `collector/0cc7ff4443fbb0cb3c90ca79bc6b9dcd.pdf`
- Extracted: `generated/extracted/0cc7ff4443fbb0cb3c90ca79bc6b9dcd/full.md`
- Filtered: `generated/filtered/0cc7ff4443fbb0cb3c90ca79bc6b9dcd/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
