---
doc_id: "8011ad97f55be5ff49fb57fe47b36b7a"
title: "MySQL生产实战优化（利用Index skip scan优化性能提升257倍） - 墨天轮"
aliases:
  - "MySQL生产实战优化（利用Index skip scan优化性能提升257倍） - 墨天轮"
url: "https://www.modb.pro/db/1901462538399789056?utm_source=index_ori"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "Index skip scan"
  - "SQL优化"
  - "多租户"
  - "性能调优"
generated: true
---

# MySQL生产实战优化（利用Index skip scan优化性能提升257倍） - 墨天轮

> [!info] Provenance
> - doc_id: `8011ad97f55be5ff49fb57fe47b36b7a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1901462538399789056?utm_source=index_ori)
> - PDF: [open local PDF](../../collector/8011ad97f55be5ff49fb57fe47b36b7a.pdf)

## Summary

本文在说明 MySQL 生产环境中的单表多租户设计背景下，跨租户查询会导致常规索引失效，进而引出一个需要优化的慢 SQL 问题，并展示了研发同学写的原版 SQL 片段。

## Knowledge Outline

- 多租户背景 — MySQL, 多租户, 索引设计
- 跨租户查询问题 — MySQL, SQL优化, 性能调优, 索引失效

## Repository Paths

- PDF: `collector/8011ad97f55be5ff49fb57fe47b36b7a.pdf`
- Extracted: `generated/extracted/8011ad97f55be5ff49fb57fe47b36b7a/full.md`
- Filtered: `generated/filtered/8011ad97f55be5ff49fb57fe47b36b7a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
