---
doc_id: "b99633e6d09d838bd40f4241534d131e"
title: "故障分析 | 为什么 MySQL 8.0.13 要引入新参数 sql_require_primary_key？"
aliases:
  - "故障分析 | 为什么 MySQL 8.0.13 要引入新参数 sql_require_primary_key？"
url: "https://mp.weixin.qq.com/s/qZ7sMBMFfvKiIhErQAPqVQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "主从复制"
  - "主键"
  - "auto_increment"
  - "故障分析"
  - "数据一致性"
generated: true
---

# 故障分析 | 为什么 MySQL 8.0.13 要引入新参数 sql_require_primary_key？

> [!info] Provenance
> - doc_id: `b99633e6d09d838bd40f4241534d131e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/qZ7sMBMFfvKiIhErQAPqVQ)
> - PDF: [open local PDF](../../collector/b99633e6d09d838bd40f4241534d131e.pdf)

## Summary

本文通过一个无主键表新增自增主键后主从数据不一致的案例，解释了 InnoDB 在无主键情况下使用内部 RowID、以及主从写入顺序差异如何导致排序与自增值不一致；同时给出重建表的解决方案，并说明 MySQL 8.0.13 的 sql_require_primary_key 与 8.0.30 的 GIPK 相关背景。

## Knowledge Outline

- 问题描述 — MySQL, 主从复制, 主键
- 问题复现 — MySQL, 主从复制, 主键自增, SQL
- 问题分析 — MySQL, InnoDB, RowID, 主从复制, 数据一致性
- 问题解决 — MySQL, SQL, 主从复制, 数据迁移
- 总结 — MySQL, sql_require_primary_key, GIPK, 主键, 建表规范

## Repository Paths

- PDF: `collector/b99633e6d09d838bd40f4241534d131e.pdf`
- Extracted: `generated/extracted/b99633e6d09d838bd40f4241534d131e/full.md`
- Filtered: `generated/filtered/b99633e6d09d838bd40f4241534d131e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
