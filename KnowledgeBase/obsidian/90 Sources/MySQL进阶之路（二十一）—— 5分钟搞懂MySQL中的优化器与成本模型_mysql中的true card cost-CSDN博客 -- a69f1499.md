---
doc_id: "a69f1499718af619f505a7bc9a176ea0"
title: "MySQL进阶之路（二十一）—— 5分钟搞懂MySQL中的优化器与成本模型_mysql中的true card cost-CSDN博客"
aliases:
  - "MySQL进阶之路（二十一）—— 5分钟搞懂MySQL中的优化器与成本模型_mysql中的true card cost-CSDN博客"
url: "https://blog.csdn.net/weixin_44829930/article/details/121658314"
source_domain: "blog.csdn.net"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "优化器"
  - "成本模型"
  - "SQL优化"
  - "性能调优"
generated: true
---

# MySQL进阶之路（二十一）—— 5分钟搞懂MySQL中的优化器与成本模型_mysql中的true card cost-CSDN博客

> [!info] Provenance
> - doc_id: `a69f1499718af619f505a7bc9a176ea0`
> - source_kind: `llm_filtered`
> - source: [original URL](https://blog.csdn.net/weixin_44829930/article/details/121658314)
> - PDF: [open local PDF](../../collector/a69f1499718af619f505a7bc9a176ea0.pdf)

## Summary

文章解释 MySQL 查询优化器如何在 possible_keys、全表扫描和不同连接计划之间搜索最优执行计划，并说明 optimizer_prune_level、optimizer_search_depth 以及基于 row_evaluate_cost、io_block_read_cost 的成本计算方式。

## Knowledge Outline

- 概述 — MySQL, 查询优化器, SQL优化
- 优化器 — MySQL, 优化器, optimizer_prune_level, optimizer_search_depth
- 成本模型 — MySQL, 成本模型, CPU成本, IO成本, SQL
- 成本计算示例 — MySQL, 成本计算, 全表扫描, 回表查询, 多表连接
- 总结 — MySQL, 优化器, 成本模型, Explain

## Repository Paths

- PDF: `collector/a69f1499718af619f505a7bc9a176ea0.pdf`
- Extracted: `generated/extracted/a69f1499718af619f505a7bc9a176ea0/full.md`
- Filtered: `generated/filtered/a69f1499718af619f505a7bc9a176ea0/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
