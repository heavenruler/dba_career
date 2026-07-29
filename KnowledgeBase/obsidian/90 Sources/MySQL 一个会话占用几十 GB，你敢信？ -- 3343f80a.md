---
doc_id: "3343f80ad4ea02a9b1fc52250a3b2bff"
title: "MySQL 一个会话占用几十 GB，你敢信？"
aliases:
  - "MySQL 一个会话占用几十 GB，你敢信？"
url: "https://mp.weixin.qq.com/s/qFZoAK-n3pQy8L_ytCOYLA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "内存"
  - "会话"
  - "函数"
  - "故障分析"
  - "性能调优"
  - "DBA"
generated: true
---

# MySQL 一个会话占用几十 GB，你敢信？

> [!info] Provenance
> - doc_id: `3343f80ad4ea02a9b1fc52250a3b2bff`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/qFZoAK-n3pQy8L_ytCOYLA)
> - PDF: [open local PDF](../../collector/3343f80ad4ea02a9b1fc52250a3b2bff.pdf)

## Summary

这篇文章通过两个实验验证了 MySQL 会话内存增长的条件：变量被反复赋予不同值时，current_allocated 基本不变；变量被不断拼接成更大的值时，会话内存会明显增长。

## Knowledge Outline

- 问题背景 — MySQL, 内存, 会话, 实验
- 准备环境 SQL — MySQL, SQL, 实验环境
- 实验一：反复赋值 — MySQL, 内存, 会话, 函数, 实验
- 实验二：不断扩大变量值 — MySQL, 内存, 会话, 函数, 实验
- 总结 — MySQL, 结论, 内存, 会话

## Repository Paths

- PDF: `collector/3343f80ad4ea02a9b1fc52250a3b2bff.pdf`
- Extracted: `generated/extracted/3343f80ad4ea02a9b1fc52250a3b2bff/full.md`
- Filtered: `generated/filtered/3343f80ad4ea02a9b1fc52250a3b2bff/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
