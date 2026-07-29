---
doc_id: "1e8b6b87255ee140f42e8a9cc94f6190"
title: "SQL优化——我是如何将SQL执行性能提升10倍的"
aliases:
  - "SQL优化——我是如何将SQL执行性能提升10倍的"
url: "https://mp.weixin.qq.com/s/FDRczYdgZ5kMKU64yMB_fw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL优化"
  - "执行计划"
  - "索引"
  - "排序规则"
  - "性能调优"
generated: true
---

# SQL优化——我是如何将SQL执行性能提升10倍的

> [!info] Provenance
> - doc_id: `1e8b6b87255ee140f42e8a9cc94f6190`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/FDRczYdgZ5kMKU64yMB_fw)
> - PDF: [open local PDF](../../collector/1e8b6b87255ee140f42e8a9cc94f6190.pdf)

## Summary

本文记录了一条 MySQL SQL 的优化过程：先通过 explain 观察执行计划，再用 show warnings 发现索引未使用与关联字段排序规则不一致的问题，最后把两张表的排序规则统一为 utf8mb4_bin，使查询从 6s 降到 0.7s。

## Knowledge Outline

- 文章导言 — MySQL, SQL优化
- 优化前 — MySQL, SQL优化, 性能问题
- 执行计划解读 — MySQL, 执行计划, join, 索引, 性能调优
- show warnings — MySQL, show warnings, 索引, 执行计划
- 表列属性查询 — MySQL, SQL, information_schema, 字符集, 排序规则
- 排序规则定位 — MySQL, 排序规则, 索引, 字符集
- 优化后 — MySQL, SQL优化, 排序规则, 性能提升
- 优化结果与总结 — MySQL, SQL优化, 总结, 性能调优

## Repository Paths

- PDF: `collector/1e8b6b87255ee140f42e8a9cc94f6190.pdf`
- Extracted: `generated/extracted/1e8b6b87255ee140f42e8a9cc94f6190/full.md`
- Filtered: `generated/filtered/1e8b6b87255ee140f42e8a9cc94f6190/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
