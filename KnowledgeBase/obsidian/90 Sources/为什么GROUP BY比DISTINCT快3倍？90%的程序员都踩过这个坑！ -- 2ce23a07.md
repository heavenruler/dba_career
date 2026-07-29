---
doc_id: "2ce23a075947fcba62bdaaeaa37af067"
title: "为什么GROUP BY比DISTINCT快3倍？90%的程序员都踩过这个坑！"
aliases:
  - "为什么GROUP BY比DISTINCT快3倍？90%的程序员都踩过这个坑！"
url: "https://mp.weixin.qq.com/s/t2tun1tEU7a2bc2hszgkuQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL优化"
  - "GROUP BY"
  - "DISTINCT"
  - "索引"
  - "性能调优"
  - "数据库"
generated: true
---

# 为什么GROUP BY比DISTINCT快3倍？90%的程序员都踩过这个坑！

> [!info] Provenance
> - doc_id: `2ce23a075947fcba62bdaaeaa37af067`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/t2tun1tEU7a2bc2hszgkuQ)
> - PDF: [open local PDF](../../collector/2ce23a075947fcba62bdaaeaa37af067.pdf)

## Summary

这篇文章讨论 MySQL 中 DISTINCT 与 GROUP BY 的去重差异，重点解释了在有索引时 GROUP BY 为什么常常更快：能利用索引有序性、减少临时表和排序开销。文章也给出了分组字段无索引、混合非分组字段、函数计算分组等常见坑，以及覆盖索引、内存参数和 Elasticsearch 预聚合等优化思路。

## Knowledge Outline

- 引言 — SQL优化, DISTINCT, GROUP BY, 性能
- 功能解析 — SQL, DISTINCT, GROUP BY, MySQL, 去重
- 执行计划与性能差异 — MySQL, EXPLAIN, 索引, 临时表, 排序, 性能
- 避坑指南 — MySQL, GROUP BY, 索引, 警告, SQL
- 实战优化 — MySQL, 索引设计, 参数调优, Elasticsearch, 去重优化, 性能调优
- 选择原则 — SQL, COUNT(DISTINCT), GROUP BY, 窗口函数, 查询设计

## Repository Paths

- PDF: `collector/2ce23a075947fcba62bdaaeaa37af067.pdf`
- Extracted: `generated/extracted/2ce23a075947fcba62bdaaeaa37af067/full.md`
- Filtered: `generated/filtered/2ce23a075947fcba62bdaaeaa37af067/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
