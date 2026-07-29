---
doc_id: "67b9239c1e117f57662e78ccd279613b"
title: "如何给MySQL的字符串字段加好索引？"
aliases:
  - "如何给MySQL的字符串字段加好索引？"
url: "https://mp.weixin.qq.com/s/ral7-TNRWuVbFCYpalnGrg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "索引"
  - "前缀索引"
  - "数据库优化"
  - "效能调优"
generated: true
---

# 如何给MySQL的字符串字段加好索引？

> [!info] Provenance
> - doc_id: `67b9239c1e117f57662e78ccd279613b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/ral7-TNRWuVbFCYpalnGrg)
> - PDF: [open local PDF](../../collector/67b9239c1e117f57662e78ccd279613b.pdf)

## Summary

本文围绕 MySQL 字符串字段索引的设计取舍，重点说明全字段索引与前缀索引的差异、如何用区分度选择前缀长度，以及前缀索引的副作用和替代优化方案。

## Knowledge Outline

- 问题引入 — MySQL, 索引, 数据库优化
- 为什么要特殊对待 — MySQL, 索引, 字符串字段, 性能
- 全字段索引 vs 前缀索引 — MySQL, 前缀索引, 索引设计, 存储空间
- 区分度计算 — MySQL, 索引, 区分度, SQL
- 副作用与应对 — MySQL, 前缀索引, 覆盖索引, 回表
- 其他优化方案 — MySQL, 索引优化, 哈希, ENUM, 字符集
- 总结 — MySQL, 索引, 字符集, 联合索引, Cardinality

## Repository Paths

- PDF: `collector/67b9239c1e117f57662e78ccd279613b.pdf`
- Extracted: `generated/extracted/67b9239c1e117f57662e78ccd279613b/full.md`
- Filtered: `generated/filtered/67b9239c1e117f57662e78ccd279613b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
