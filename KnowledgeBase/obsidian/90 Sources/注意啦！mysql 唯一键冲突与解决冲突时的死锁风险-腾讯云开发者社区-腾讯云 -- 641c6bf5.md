---
doc_id: "641c6bf58c66c8289d1f3afb9c8322c5"
title: "注意啦！mysql 唯一键冲突与解决冲突时的死锁风险-腾讯云开发者社区-腾讯云"
aliases:
  - "注意啦！mysql 唯一键冲突与解决冲突时的死锁风险-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/2031570"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "唯一键"
  - "死锁"
  - "InnoDB"
  - "插入意向锁"
  - "主从同步"
  - "数据库"
generated: true
---

# 注意啦！mysql 唯一键冲突与解决冲突时的死锁风险-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `641c6bf58c66c8289d1f3afb9c8322c5`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/2031570)
> - PDF: [open local PDF](../../collector/641c6bf58c66c8289d1f3afb9c8322c5.pdf)

## Summary

本文讲的是 MySQL 唯一键冲突的常见处理方式，以及 `REPLACE INTO`、`INSERT ... ON DUPLICATE KEY UPDATE`、`INSERT IGNORE` 在并发场景下的锁风险、死锁风险和主从同步风险。重点落在 InnoDB 的临键锁、插入意向锁、死锁检测，以及高并发下的应对思路。

## Knowledge Outline

- 唯一键冲突与解决方案 — MySQL, 唯一键, SQL, 数据库
- replace into 原理与死锁 — MySQL, replace into, InnoDB, 死锁, 插入意向锁, 主从同步
- insert on duplicate key update 风险 — MySQL, insert on duplicate key update, InnoDB, 死锁, 锁, 版本差异
- insert ignore into 的取舍 — MySQL, insert ignore, 数据一致性, 告警, 数据库
- 死锁的解决 — MySQL, 死锁, 重试, innodb_deadlock_detect, 高并发, 数据库

## Repository Paths

- PDF: `collector/641c6bf58c66c8289d1f3afb9c8322c5.pdf`
- Extracted: `generated/extracted/641c6bf58c66c8289d1f3afb9c8322c5/full.md`
- Filtered: `generated/filtered/641c6bf58c66c8289d1f3afb9c8322c5/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
