---
doc_id: "a298dd2bf5726df03a02ce438b399390"
title: "MySQL-extra常见的额外信息 - 墨天轮"
aliases:
  - "MySQL-extra常见的额外信息 - 墨天轮"
url: "https://www.modb.pro/db/1772429352336166912"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "EXPLAIN"
  - "执行计划"
  - "SQL优化"
  - "索引"
  - "semi-join"
  - "优化器"
generated: true
---

# MySQL-extra常见的额外信息 - 墨天轮

> [!info] Provenance
> - doc_id: `a298dd2bf5726df03a02ce438b399390`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1772429352336166912)
> - PDF: [open local PDF](../../collector/a298dd2bf5726df03a02ce438b399390.pdf)

## Summary

整理 MySQL EXPLAIN Extra 常见提示的含义与典型场景，涵盖覆盖索引、条件过滤、临时表、filesort、join buffer、semi-join 策略与优化器决策思路。

## Knowledge Outline

- Using index — MySQL, EXPLAIN, 覆盖索引, 索引
- Using where — MySQL, EXPLAIN, 过滤条件, 索引
- Using temporary — MySQL, EXPLAIN, 临时表, 执行计划
- Using filesort — MySQL, EXPLAIN, 排序, 索引
- Using join buffer — MySQL, EXPLAIN, Join, 连接算法
- Impossible where — MySQL, EXPLAIN, 条件判断, 空结果集
- Select tables optimized away — MySQL, EXPLAIN, 优化器, 执行计划
- Using index condition — MySQL, EXPLAIN, 索引范围扫描, 回表
- LooseScan / FirstMatch — MySQL, EXPLAIN, semi-join, LooseScan, FirstMatch, 优化器
- 优化器执行流程 — MySQL, 优化器, 执行计划, 算法

## Repository Paths

- PDF: `collector/a298dd2bf5726df03a02ce438b399390.pdf`
- Extracted: `generated/extracted/a298dd2bf5726df03a02ce438b399390/full.md`
- Filtered: `generated/filtered/a298dd2bf5726df03a02ce438b399390/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
