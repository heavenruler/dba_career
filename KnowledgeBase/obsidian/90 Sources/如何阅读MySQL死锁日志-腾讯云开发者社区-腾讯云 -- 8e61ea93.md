---
doc_id: "8e61ea932eead7717bffe5e2796f001a"
title: "如何阅读MySQL死锁日志-腾讯云开发者社区-腾讯云"
aliases:
  - "如何阅读MySQL死锁日志-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/2185083"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "死锁"
  - "InnoDB"
  - "事务"
  - "锁分析"
  - "DBA"
  - "故障排查"
generated: true
---

# 如何阅读MySQL死锁日志-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `8e61ea932eead7717bffe5e2796f001a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/2185083)
> - PDF: [open local PDF](../../collector/8e61ea932eead7717bffe5e2796f001a.pdf)

## Summary

本文通过一个并发删除数据导致 MySQL 死锁的案例，拆解 InnoDB 死锁日志中的事务 ID、等待锁、持有锁、回滚事务等信息，并给出复现实验步骤、表结构和操作顺序。

## Knowledge Outline

- 现象描述 — MySQL, 死锁, 故障现象
- 死锁日志 — MySQL, 死锁日志, InnoDB, 事务
- 阅读死锁日志 — MySQL, 死锁分析, 排查方法
- 事务39474锁等待 — MySQL, 锁等待, 聚集索引, X锁
- 事务39475持有锁 — MySQL, 持有锁, X锁, 事务
- 事务39475锁等待 — MySQL, 死锁成因, 加锁顺序, 事务
- 回滚与补充排查 — MySQL, 回滚事务, general log, binlog, 业务代码
- 实验表结构 — MySQL, 实验复现, 表结构
- 复现操作步骤 — MySQL, 死锁复现, 并发事务
- 总结 — MySQL, 死锁预防, 应用开发, 数据库操作

## Repository Paths

- PDF: `collector/8e61ea932eead7717bffe5e2796f001a.pdf`
- Extracted: `generated/extracted/8e61ea932eead7717bffe5e2796f001a/full.md`
- Filtered: `generated/filtered/8e61ea932eead7717bffe5e2796f001a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
