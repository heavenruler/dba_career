---
doc_id: "2521eca551359e30b8f64337d32bfc87"
title: "重现一条简单SQL的优化过程-腾讯云开发者社区-腾讯云"
aliases:
  - "重现一条简单SQL的优化过程-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/2321910"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL优化"
  - "执行计划"
  - "索引"
  - "覆盖索引"
  - "数据库性能调优"
generated: true
---

# 重现一条简单SQL的优化过程-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `2521eca551359e30b8f64337d32bfc87`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/2321910)
> - PDF: [open local PDF](../../collector/2521eca551359e30b8f64337d32bfc87.pdf)

## Summary

本文通过 MySQL 5.7.39 实验复现一条三表关联 insert-select SQL 的优化过程，比较大表加索引并 force index、小表关联字段加索引、覆盖索引等方案的执行效果，并总结大表驱动小表、索引选择与优化折中的经验。

## Knowledge Outline

- 背景 — SQL优化, 性能问题, MySQL
- 实验环境与表结构 — MySQL, 表结构, 实验环境
- 原始SQL — SQL, insert select, 三表关联
- 原始执行计划分析 — 执行计划, 笛卡尔积, 全表扫描, 索引
- 大表加索引方案 — 大表索引, BNL, force index, 优化器
- Force Index 执行效果 — force index, 执行耗时, 回表, 随机IO
- 小表关联字段加索引 — 小表索引, 优化器, 大表驱动小表
- 大表驱动小表执行效果 — 大表驱动小表, 执行耗时, 索引选择, 性能对比
- 覆盖索引优化 — 覆盖索引, 回表, 执行耗时, SQL优化
- 总结 — SQL优化, 执行计划, 优化决策, 折中选择

## Repository Paths

- PDF: `collector/2521eca551359e30b8f64337d32bfc87.pdf`
- Extracted: `generated/extracted/2521eca551359e30b8f64337d32bfc87/full.md`
- Filtered: `generated/filtered/2521eca551359e30b8f64337d32bfc87/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
