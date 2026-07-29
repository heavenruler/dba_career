---
doc_id: "3e6aea7a585dd2262279f6bf9853912a"
title: "MySQL 升级后查询性能跳水，排序竟成“罪魁祸首”？"
aliases:
  - "MySQL 升级后查询性能跳水，排序竟成“罪魁祸首”？"
url: "https://mp.weixin.qq.com/s/66ryA_iJ-29jnRlry7K5Og"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL优化"
  - "排序"
  - "数据库升级"
  - "性能调优"
  - "索引"
generated: true
---

# MySQL 升级后查询性能跳水，排序竟成“罪魁祸首”？

> [!info] Provenance
> - doc_id: `3e6aea7a585dd2262279f6bf9853912a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/66ryA_iJ-29jnRlry7K5Og)
> - PDF: [open local PDF](../../collector/3e6aea7a585dd2262279f6bf9853912a.pdf)

## Summary

本文分析了 MySQL 5.7 升级到 8.0 后，带 ORDER BY 的查询在多字段 SELECT 下明显变慢的原因。核心结论是 8.0.20 之后无索引排序的行为变化，以及 max_length_for_sort_data 不再生效，最佳优化方式是给排序字段加索引。

## Knowledge Outline

- 背景与分析 — MySQL, SQL优化, 排序, 性能分析, max_length_for_sort_data
- 验证测试 — MySQL, SQL优化, 排序, 验证测试, 性能对比
- 结论 — MySQL, SQL优化, 索引, 结论

## Repository Paths

- PDF: `collector/3e6aea7a585dd2262279f6bf9853912a.pdf`
- Extracted: `generated/extracted/3e6aea7a585dd2262279f6bf9853912a/full.md`
- Filtered: `generated/filtered/3e6aea7a585dd2262279f6bf9853912a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
