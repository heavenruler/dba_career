---
doc_id: "97425cfd61349709f701d3e36551b7cf"
title: "mysql 内存使用率高问题排查 - 墨天轮"
aliases:
  - "mysql 内存使用率高问题排查 - 墨天轮"
url: "https://www.modb.pro/db/1887320605045829632"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "内存排查"
  - "性能调优"
  - "DBA"
  - "performance_schema"
  - "pmap"
  - "transparent_hugepage"
  - "SRE"
generated: true
---

# mysql 内存使用率高问题排查 - 墨天轮

> [!info] Provenance
> - doc_id: `97425cfd61349709f701d3e36551b7cf`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1887320605045829632)
> - PDF: [open local PDF](../../collector/97425cfd61349709f701d3e36551b7cf.pdf)

## Summary

这篇文章记录了 MySQL 实例内存使用率偏高时的排查路径：先看参数配置，再用 information_schema、sys、performance_schema 做实例内存与账号级别统计，接着结合 top、ps、pmap 在操作系统层定位是否有内存泄露，最后给出关闭 transparent hugepage 的临时和永久方案。

## Knowledge Outline

- 问题现象与参数检查 — MySQL, 内存排查, 参数检查, DBA
- 检查内存使用 — MySQL, 内存排查, information_schema, SQL
- 对象统计 — MySQL, 对象统计, information_schema, 存储过程, 视图, 触发器
- 内存占用统计 — MySQL, 内存排查, sys, performance_schema, 账号级别统计
- 操作系统排查 — MySQL, 内存排查, Linux, top, ps, pmap, 内存泄露
- 大页与解决方案 — MySQL, transparent_hugepage, Linux, 配置, DBA

## Repository Paths

- PDF: `collector/97425cfd61349709f701d3e36551b7cf.pdf`
- Extracted: `generated/extracted/97425cfd61349709f701d3e36551b7cf/full.md`
- Filtered: `generated/filtered/97425cfd61349709f701d3e36551b7cf/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
