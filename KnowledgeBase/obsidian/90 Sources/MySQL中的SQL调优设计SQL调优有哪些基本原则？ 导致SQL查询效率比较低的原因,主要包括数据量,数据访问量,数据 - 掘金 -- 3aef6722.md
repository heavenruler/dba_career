---
doc_id: "3aef6722b6a737086a27c76a4aab979f"
title: "MySQL中的SQL调优设计SQL调优有哪些基本原则？ 导致SQL查询效率比较低的原因,主要包括数据量,数据访问量,数据 - 掘金"
aliases:
  - "MySQL中的SQL调优设计SQL调优有哪些基本原则？ 导致SQL查询效率比较低的原因,主要包括数据量,数据访问量,数据 - 掘金"
url: "https://juejin.cn/post/7358109207994712075"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL调优"
  - "慢查询"
  - "EXPLAIN"
  - "索引"
  - "数据库"
generated: true
---

# MySQL中的SQL调优设计SQL调优有哪些基本原则？ 导致SQL查询效率比较低的原因,主要包括数据量,数据访问量,数据 - 掘金

> [!info] Provenance
> - doc_id: `3aef6722b6a737086a27c76a4aab979f`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7358109207994712075)
> - PDF: [open local PDF](../../collector/3aef6722b6a737086a27c76a4aab979f.pdf)

## Summary

这篇文章主要讲 MySQL SQL 调优的基本原则、慢查询日志的使用方法，以及通过 EXPLAIN 分析执行计划时常见字段的含义与典型案例。核心知识点集中在减少数据量、减少数据访问量、减少计算、避免低效 SQL 写法、定位慢 SQL、以及识别全表扫描、索引命中、文件排序和临时表等执行特征。

## Knowledge Outline

- SQL调优基本原则 — MySQL, SQL调优, 索引, 数据库
- 慢SQL日志 — MySQL, 慢查询, 性能调优, 数据库
- 执行计划与字段 — MySQL, EXPLAIN, 执行计划, 索引, 性能调优

## Repository Paths

- PDF: `collector/3aef6722b6a737086a27c76a4aab979f.pdf`
- Extracted: `generated/extracted/3aef6722b6a737086a27c76a4aab979f/full.md`
- Filtered: `generated/filtered/3aef6722b6a737086a27c76a4aab979f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
