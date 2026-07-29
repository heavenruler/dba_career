---
doc_id: "e1462e7727b76b3201c2f59f40b77572"
title: "拒绝全表扫描！3个提升MySQL深度分页技巧！分析MySQL深度分页性能问题，并介绍了3种优化方案：子查询接力、游标分页 - 掘金"
aliases:
  - "拒绝全表扫描！3个提升MySQL深度分页技巧！分析MySQL深度分页性能问题，并介绍了3种优化方案：子查询接力、游标分页 - 掘金"
url: "https://juejin.cn/post/7471898162028167179"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "深度分页"
  - "性能优化"
  - "索引"
  - "B+树"
  - "数据库"
  - "SQL"
generated: true
---

# 拒绝全表扫描！3个提升MySQL深度分页技巧！分析MySQL深度分页性能问题，并介绍了3种优化方案：子查询接力、游标分页 - 掘金

> [!info] Provenance
> - doc_id: `e1462e7727b76b3201c2f59f40b77572`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7471898162028167179)
> - PDF: [open local PDF](../../collector/e1462e7727b76b3201c2f59f40b77572.pdf)

## Summary

这篇文章聚焦 MySQL 深度分页的性能问题，先用电商订单分页场景说明 offset 越大查询越慢的原因，再给出三种优化方案：子查询接力、游标分页、索引覆盖，并补充了方案选择建议与 B+ 树层面的性能解释。

## Knowledge Outline

- 深度分页问题与案例 — MySQL, 深度分页, 性能问题, 索引, 数据库
- 方案1：子查询接力 — MySQL, 深度分页, 子查询, 性能优化, 索引
- 方案2：游标分页 — MySQL, 深度分页, 游标分页, 无限滚动, 性能优化
- 方案3：索引覆盖 — MySQL, 覆盖索引, 深度分页, 性能优化, 回表
- 方案选择与原理 — MySQL, B+树, 深度分页, 架构设计, 性能优化
- 结语与替代方案 — MySQL, 分页, Elasticsearch, ClickHouse, Redis, 架构设计

## Repository Paths

- PDF: `collector/e1462e7727b76b3201c2f59f40b77572.pdf`
- Extracted: `generated/extracted/e1462e7727b76b3201c2f59f40b77572/full.md`
- Filtered: `generated/filtered/e1462e7727b76b3201c2f59f40b77572/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
