---
doc_id: "3af90e819f357a240e851eb7f9e58f5c"
title: "技术译文 | MySQL 8.4.3 和 9.1.0：显著提升性能！"
aliases:
  - "技术译文 | MySQL 8.4.3 和 9.1.0：显著提升性能！"
url: "https://mp.weixin.qq.com/s/IEbamb9-OzMFCS9lh0sRvA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "性能优化"
  - "数据库"
  - "QPS"
  - "索引扫描"
  - "JOIN"
  - "binlog"
generated: true
---

# 技术译文 | MySQL 8.4.3 和 9.1.0：显著提升性能！

> [!info] Provenance
> - doc_id: `3af90e819f357a240e851eb7f9e58f5c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/IEbamb9-OzMFCS9lh0sRvA)
> - PDF: [open local PDF](../../collector/3af90e819f357a240e851eb7f9e58f5c.pdf)

## Summary

本文总结了 MySQL 8.4.3 和 9.1.0 的性能改进，并拆解出三项关键变化：binlog 事务依赖切换、使用 JOINS 优化查询执行、改进索引范围扫描。文章还给出写入/读取负载的平均提升幅度，以及相较 MySQL 8.0.40 和 8.4.3 的整体性能对比。

## Knowledge Outline

- 前言与结论 — MySQL, 性能测试, QPS, 数据库
- Binlog 依赖切换 — MySQL, binlog, 性能优化, 数据库
- JOINS 优化 — MySQL, JOIN, 查询优化, 性能优化, 数据库
- 索引范围扫描 — MySQL, 索引, 范围扫描, 性能优化, 数据库
- 整体表现 — MySQL, 性能测试, 写入性能, 读取性能, 数据库
- 结语 — MySQL, 社区协作, 性能优化, 数据库

## Repository Paths

- PDF: `collector/3af90e819f357a240e851eb7f9e58f5c.pdf`
- Extracted: `generated/extracted/3af90e819f357a240e851eb7f9e58f5c/full.md`
- Filtered: `generated/filtered/3af90e819f357a240e851eb7f9e58f5c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
