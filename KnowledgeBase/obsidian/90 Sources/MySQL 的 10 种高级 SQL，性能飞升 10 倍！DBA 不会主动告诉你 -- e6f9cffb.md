---
doc_id: "e6f9cffbc2723d3fc1b8f8cd5e9fc12b"
title: "MySQL 的 10 种高级 SQL，性能飞升 10 倍！DBA 不会主动告诉你"
aliases:
  - "MySQL 的 10 种高级 SQL，性能飞升 10 倍！DBA 不会主动告诉你"
url: "https://mp.weixin.qq.com/s/HtkcO8fn-_VSTvUaj20-MQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL优化"
  - "DBA"
  - "性能调优"
  - "索引"
  - "查询优化"
  - "实战案例"
generated: true
---

# MySQL 的 10 种高级 SQL，性能飞升 10 倍！DBA 不会主动告诉你

> [!info] Provenance
> - doc_id: `e6f9cffbc2723d3fc1b8f8cd5e9fc12b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/HtkcO8fn-_VSTvUaj20-MQ)
> - PDF: [open local PDF](../../collector/e6f9cffbc2723d3fc1b8f8cd5e9fc12b.pdf)

## Summary

這篇文章整理了 MySQL 常見 SQL 優化手法與兩個實戰案例，核心在於減少掃描、減少傳輸、減少計算、善用索引。內容涵蓋 EXISTS 代替 IN、LIMIT 1、避免 SELECT *、UNION ALL、批量插入、ORDER BY / GROUP BY / LIKE / 分頁優化，以及索引設計與 EXPLAIN 的基本觀念。

## Knowledge Outline

- 引言 — MySQL, SQL优化, 性能调优
- 技巧 1 — MySQL, SQL优化, EXISTS, IN, 索引
- 技巧 2 — MySQL, SQL优化, LIMIT, 索引
- 技巧 3 — MySQL, SQL优化, SELECT *, 覆盖索引
- 技巧 4 — MySQL, SQL优化, UNION, UNION ALL
- 技巧 5 — MySQL, SQL优化, 批量插入, 事务
- 技巧 6 — MySQL, SQL优化, ORDER BY, filesort, 联合索引
- 技巧 7 — MySQL, SQL优化, GROUP BY, 索引
- 技巧 8 — MySQL, SQL优化, 索引失效, 范围查询, 函数
- 技巧 9 — MySQL, SQL优化, LIKE, 全文检索, 索引
- 技巧 10 — MySQL, SQL优化, 分页, 延迟关联
- 案例 1 — MySQL, 案例, 电商, SQL优化, 索引
- 案例 2 — MySQL, 案例, 报表, SQL优化, 索引
- 核心思想 — SQL优化, 性能调优, 索引
- 优化建议 — SQL优化, 索引, EXPLAIN, 最佳实践

## Repository Paths

- PDF: `collector/e6f9cffbc2723d3fc1b8f8cd5e9fc12b.pdf`
- Extracted: `generated/extracted/e6f9cffbc2723d3fc1b8f8cd5e9fc12b/full.md`
- Filtered: `generated/filtered/e6f9cffbc2723d3fc1b8f8cd5e9fc12b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
