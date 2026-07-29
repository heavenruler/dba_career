---
doc_id: "1739e4ae182da8c5d4e409b063d6876a"
title: "重生之 MySQL B+Tree 提前问世二十年，MySQL之父叫我师父"
aliases:
  - "重生之 MySQL B+Tree 提前问世二十年，MySQL之父叫我师父"
url: "https://mp.weixin.qq.com/s/N2budx0ZuoKZMRdicp80SQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "B-Tree"
  - "B+Tree"
  - "数据库索引"
  - "性能调优"
  - "存储引擎"
  - "SQL"
  - "架构设计"
generated: true
---

# 重生之 MySQL B+Tree 提前问世二十年，MySQL之父叫我师父

> [!info] Provenance
> - doc_id: `1739e4ae182da8c5d4e409b063d6876a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/N2budx0ZuoKZMRdicp80SQ)
> - PDF: [open local PDF](../../collector/1739e4ae182da8c5d4e409b063d6876a.pdf)

## Summary

本文用故事化写法说明二叉树、B Tree、B+Tree 在数据库索引中的差异，重点落在磁盘 I/O、树高、范围查询、叶子节点与链表串联等核心概念，并给出一段 MySQL/InnoDB 相关代码与查询性能对比。

## Knowledge Outline

- 二叉树的致命缺陷 — MySQL, 索引, 递归查询, 性能调优, 数据库
- 机械困境 — BST, 磁盘I/O, 局部性原理, 性能调优, 数据库
- B Tree — B-Tree, 磁盘页, 数据库索引, IO, 性能调优
- B+Tree — B+Tree, InnoDB, 叶子节点, 范围查询, MySQL内核
- 实战对比 — B+Tree, 查询性能, 范围查询, SQL, 案例

## Repository Paths

- PDF: `collector/1739e4ae182da8c5d4e409b063d6876a.pdf`
- Extracted: `generated/extracted/1739e4ae182da8c5d4e409b063d6876a/full.md`
- Filtered: `generated/filtered/1739e4ae182da8c5d4e409b063d6876a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
