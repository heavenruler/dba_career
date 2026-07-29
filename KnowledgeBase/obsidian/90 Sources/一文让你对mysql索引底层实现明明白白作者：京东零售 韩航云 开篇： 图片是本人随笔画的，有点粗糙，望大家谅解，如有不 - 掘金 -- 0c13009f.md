---
doc_id: "0c13009f75e503fc241380577e1e1714"
title: "一文让你对mysql索引底层实现明明白白作者：京东零售 韩航云 开篇： 图片是本人随笔画的，有点粗糙，望大家谅解，如有不 - 掘金"
aliases:
  - "一文让你对mysql索引底层实现明明白白作者：京东零售 韩航云 开篇： 图片是本人随笔画的，有点粗糙，望大家谅解，如有不 - 掘金"
url: "https://juejin.cn/post/7460467888031514658"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "索引"
  - "B+Tree"
  - "InnoDB"
  - "MyISAM"
  - "数据库"
  - "性能优化"
generated: true
---

# 一文让你对mysql索引底层实现明明白白作者：京东零售 韩航云 开篇： 图片是本人随笔画的，有点粗糙，望大家谅解，如有不 - 掘金

> [!info] Provenance
> - doc_id: `0c13009f75e503fc241380577e1e1714`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7460467888031514658)
> - PDF: [open local PDF](../../collector/0c13009f75e503fc241380577e1e1714.pdf)

## Summary

本文围绕 MySQL 索引的底层实现展开，解释了索引的定义、磁盘 IO 成本、常见数据结构为何不用，以及 B+Tree、MyISAM、InnoDB 和联合索引最左原则。

## Knowledge Outline

- 索引与磁盘IO — MySQL, 索引, 磁盘IO, 数据库
- 数据结构对比 — MySQL, 索引, B-Tree, B+Tree, HASH, 红黑树, 二叉树, 性能优化
- MyISAM 与 InnoDB — MySQL, MyISAM, InnoDB, 聚集索引, 主键索引, 非主键索引, B+Tree
- 联合索引最左原则 — MySQL, 联合索引, 最左原则, B+Tree, 数据库

## Repository Paths

- PDF: `collector/0c13009f75e503fc241380577e1e1714.pdf`
- Extracted: `generated/extracted/0c13009f75e503fc241380577e1e1714/full.md`
- Filtered: `generated/filtered/0c13009f75e503fc241380577e1e1714/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
