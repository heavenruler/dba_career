---
doc_id: "9b34444b962ceaf7a53426a01d11698e"
title: "从MySQL迁移到PostgreSQL经验总结最近一两周在做从MySQL迁移到PostgreSQL的任务(新项目，历史包 - 掘金"
aliases:
  - "从MySQL迁移到PostgreSQL经验总结最近一两周在做从MySQL迁移到PostgreSQL的任务(新项目，历史包 - 掘金"
url: "https://juejin.cn/post/7460410854775455794"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "DBA"
  - "PostgreSQL"
  - "MySQL"
  - "数据库迁移"
  - "MyBatis"
  - "JSON"
  - "SQL"
  - "Java"
generated: true
---

# 从MySQL迁移到PostgreSQL经验总结最近一两周在做从MySQL迁移到PostgreSQL的任务(新项目，历史包 - 掘金

> [!info] Provenance
> - doc_id: `9b34444b962ceaf7a53426a01d11698e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7460410854775455794)
> - PDF: [open local PDF](../../collector/9b34444b962ceaf7a53426a01d11698e.pdf)

## Summary

本文总结从 MySQL 迁移到 PostgreSQL 的实践经验，涵盖驱动与连接字符串、PageHelper 方言、关键字转义、JSON 字段 TypeHandler、INSERT IGNORE 与 UPSERT 语法差异、分页差异、大小写敏感、BIT/tinyint 与 Boolean 转换、自增序列调整，以及 PostgreSQL 与 MyBatis jdbcType 常见类型参考。

## Knowledge Outline

- 背景 — 数据库迁移, PostgreSQL, MySQL
- 迁移原因 — PostgreSQL, MySQL, 安全
- 迁移事项 — 数据库迁移, PageHelper, SQL关键字, JSON
- JSON字段处理 — JSON, MyBatis, PGObject, TypeHandler
- JsonTypeHandler代码 — Java, MyBatis, JSON, PGObject, TypeHandler
- MyBatis映射示例 — MyBatis, jdbcType, JSON
- 泛型类型擦除 — Java, 泛型, TypeReference, JSON
- TypeReference子类 — Java, TypeReference, MyBatis, JSON
- Insert Ignore替代 — PostgreSQL, MySQL, INSERT IGNORE, ON CONFLICT
- Duplicate Key Update替代 — PostgreSQL, MySQL, UPSERT, ON CONFLICT
- 约束冲突处理 — PostgreSQL, 唯一约束, ON CONFLICT
- 分页差异 — PostgreSQL, MySQL, 分页, SQL
- 大小写与Boolean差异 — PostgreSQL, MySQL, 大小写敏感, Boolean, BIT
- BIT转INT示例 — PostgreSQL, ALTER TABLE, 数据迁移, BIT, INT
- 自增序列调整 — PostgreSQL, Sequence, 自增列, 数据迁移
- 总结 — 软件工程实务, 代码质量, 可移植性
- PostgreSQL数值类型 — PostgreSQL, 数据类型
- PostgreSQL字符串与时间类型 — PostgreSQL, 数据类型, 字符串, 时间
- PostgreSQL其他常用类型 — PostgreSQL, 数据类型, JSON, UUID, XML
- MyBatis jdbcType — MyBatis, JDBC, jdbcType, SQL类型

## Repository Paths

- PDF: `collector/9b34444b962ceaf7a53426a01d11698e.pdf`
- Extracted: `generated/extracted/9b34444b962ceaf7a53426a01d11698e/full.md`
- Filtered: `generated/filtered/9b34444b962ceaf7a53426a01d11698e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
