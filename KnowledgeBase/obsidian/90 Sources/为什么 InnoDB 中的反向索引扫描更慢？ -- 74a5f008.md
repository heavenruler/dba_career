---
doc_id: "74a5f008d96464e1db2c025ed58bf048"
title: "为什么 InnoDB 中的反向索引扫描更慢？"
aliases:
  - "为什么 InnoDB 中的反向索引扫描更慢？"
url: "https://mp.weixin.qq.com/s/QQJvmBhfgOPoQcoJnyMGWA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "索引扫描"
  - "性能分析"
  - "页面结构"
  - "数据库原理"
generated: true
---

# 为什么 InnoDB 中的反向索引扫描更慢？

> [!info] Provenance
> - doc_id: `74a5f008d96464e1db2c025ed58bf048`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/QQJvmBhfgOPoQcoJnyMGWA)
> - PDF: [open local PDF](../../collector/74a5f008d96464e1db2c025ed58bf048.pdf)

## Summary

本文解释了 MySQL/InnoDB 为何 ORDER BY DESC 往往比 ORDER BY ASC 慢：页内记录以单向链表组织，正向扫描可直接沿 REC_NEXT 前进，而反向扫描需要借助 page directory 和 n_owned 先定位所属槽，再在槽组内回找前一条记录；文末给出简单基准测试，展示正反向扫描耗时差异。

## Knowledge Outline

- 问题背景 — MySQL, InnoDB, 索引扫描, 性能
- 页面结构 — InnoDB, 页面结构, 单向链表, page directory, N_OWNED
- 正向扫描 — InnoDB, 正向扫描, 算法, 性能
- 反向扫描 — InnoDB, 反向扫描, page directory, n_owned, 算法, 性能
- 基准测试 — MySQL, InnoDB, benchmark, ORDER BY, 性能测试

## Repository Paths

- PDF: `collector/74a5f008d96464e1db2c025ed58bf048.pdf`
- Extracted: `generated/extracted/74a5f008d96464e1db2c025ed58bf048/full.md`
- Filtered: `generated/filtered/74a5f008d96464e1db2c025ed58bf048/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
