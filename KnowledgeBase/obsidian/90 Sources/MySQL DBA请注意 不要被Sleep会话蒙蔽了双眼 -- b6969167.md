---
doc_id: "b6969167c3b02f8ec30f7728da29dfd3"
title: "MySQL DBA请注意 不要被Sleep会话蒙蔽了双眼"
aliases:
  - "MySQL DBA请注意 不要被Sleep会话蒙蔽了双眼"
url: "https://www.modb.pro/db/1962444034597728256"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "锁等待"
  - "事务"
  - "Sleep会话"
  - "故障排查"
  - "performance_schema"
generated: true
---

# MySQL DBA请注意 不要被Sleep会话蒙蔽了双眼

> [!info] Provenance
> - doc_id: `b6969167c3b02f8ec30f7728da29dfd3`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1962444034597728256)
> - PDF: [open local PDF](../../collector/b6969167c3b02f8ec30f7728da29dfd3.pdf)

## Summary

文章记录一次 MySQL insert 因锁等待超时失败的排查过程，重点说明仅看 processlist 容易忽视 Sleep 状态但仍持有未提交事务的会话，需要结合 INFORMATION_SCHEMA.INNODB_TRX 与 performance_schema 历史语句定位问题。

## Knowledge Outline

- 锁等待报错 — MySQL, 锁等待, 错误码
- processlist 初查 — processlist, MySQL, 锁排查
- 锁表未发现问题 — innodb_locks, innodb_lock_waits, Sleep会话
- INNODB_TRX 查询活跃事务 — INNODB_TRX, 活跃事务, SQL
- Sleep 会话定位 — Sleep会话, processlist, MySQL
- 为什么查 INNODB_TRX — INNODB_TRX, processlist, 事务
- 事务详情查询 — INNODB_TRX, 事务状态, SQL
- 历史语句追踪 — performance_schema, events_statements_history, SQL历史
- 根因 — 未提交事务, 锁等待, 根因分析

## Repository Paths

- PDF: `collector/b6969167c3b02f8ec30f7728da29dfd3.pdf`
- Extracted: `generated/extracted/b6969167c3b02f8ec30f7728da29dfd3/full.md`
- Filtered: `generated/filtered/b6969167c3b02f8ec30f7728da29dfd3/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
