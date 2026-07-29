---
doc_id: "ccb59c456a3bd191d7826ccb513aa08c"
title: "DBCP一个配置，浪费了MySQL 50%的性能！1. 引言 研究背景 数据库性能的重要性 数据库性能优化对于保证应用的 - 掘金"
aliases:
  - "DBCP一个配置，浪费了MySQL 50%的性能！1. 引言 研究背景 数据库性能的重要性 数据库性能优化对于保证应用的 - 掘金"
url: "https://juejin.cn/post/7350214909056483366"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBCP"
  - "连接池"
  - "性能优化"
  - "源码分析"
  - "事务"
  - "autocommit"
  - "后端"
generated: true
---

# DBCP一个配置，浪费了MySQL 50%的性能！1. 引言 研究背景 数据库性能的重要性 数据库性能优化对于保证应用的 - 掘金

> [!info] Provenance
> - doc_id: `ccb59c456a3bd191d7826ccb513aa08c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7350214909056483366)
> - PDF: [open local PDF](../../collector/ccb59c456a3bd191d7826ccb513aa08c.pdf)

## Summary

本文通过压测实验和源码分析，说明在 spring + mybatis + dbcp + mysql 场景下，dbcp 的 `defaultAutoCommit=false` 会导致每次借还连接都额外触发 `SET autocommit`、`commit`、`rollback` 等操作，从而显著增加网络 IO 和 CPU 开销；建议连接池 autocommit 与数据库保持一致，仅在需要事务控制时再显式开启事务。

## Knowledge Outline

- 研究背景与问题 — MySQL, 连接池, 性能优化, 事务, autocommit
- 实验设计与结果 — MySQL, DBCP, 压测, 性能测试, autocommit, CPU, TPS
- 源码分析 — MyBatis, DBCP, JDBC, 源码分析, autocommit, 连接池
- 获取与归还连接 — DBCP, 连接池, 源码分析, autocommit, rollback, commit
- general_log 对比 — MySQL, general_log, DBCP, autocommit, MyBatis, 网络IO
- 结论与建议 — MySQL, DBCP, 事务, autocommit, 性能优化, Spring, MyBatis

## Repository Paths

- PDF: `collector/ccb59c456a3bd191d7826ccb513aa08c.pdf`
- Extracted: `generated/extracted/ccb59c456a3bd191d7826ccb513aa08c/full.md`
- Filtered: `generated/filtered/ccb59c456a3bd191d7826ccb513aa08c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
