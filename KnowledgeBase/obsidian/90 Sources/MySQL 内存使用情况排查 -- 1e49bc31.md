---
doc_id: "1e49bc31193fce5f3844c70461bbb30a"
title: "MySQL 内存使用情况排查"
aliases:
  - "MySQL 内存使用情况排查"
url: "https://mp.weixin.qq.com/s/7OAD4Pnc4ygwf7AAxJAhiA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "内存排查"
  - "故障排查"
  - "性能调优"
  - "performance_schema"
  - "sys库"
  - "Linux工具"
generated: true
---

# MySQL 内存使用情况排查

> [!info] Provenance
> - doc_id: `1e49bc31193fce5f3844c70461bbb30a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/7OAD4Pnc4ygwf7AAxJAhiA)
> - PDF: [open local PDF](../../collector/1e49bc31193fce5f3844c70461bbb30a.pdf)

## Summary

本文按参数配置、存储过程/视图/触发器、sys 与 performance_schema 统计、Linux 工具四层，给出排查 MySQL 内存使用过高与潜在内存泄露的方法。

## Knowledge Outline

- 参数与内存分类 — MySQL, 内存排查, 参数配置, 线程内存, performance_schema
- 存储过程与对象排查 — MySQL, 内存排查, 存储过程, 视图, 触发器, 函数
- sys 与 performance_schema 统计 — MySQL, sys库, performance_schema, 内存统计, 线程, 账号级别
- 系统工具与结论 — MySQL, Linux工具, 内存泄露, pmap, top, free, ps, 故障排查

## Repository Paths

- PDF: `collector/1e49bc31193fce5f3844c70461bbb30a.pdf`
- Extracted: `generated/extracted/1e49bc31193fce5f3844c70461bbb30a/full.md`
- Filtered: `generated/filtered/1e49bc31193fce5f3844c70461bbb30a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
