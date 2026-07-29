---
doc_id: "418a747501aa79be9d4ccc7e444cd1b8"
title: "从ibdata1到ibd：MySQL是如何管理数据“不动产”的？"
aliases:
  - "从ibdata1到ibd：MySQL是如何管理数据“不动产”的？"
url: "https://mp.weixin.qq.com/s/JknHpRh8ZsUfBwbta9Um8g"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "DBA"
  - "表空间"
  - "存储引擎"
  - "性能优化"
  - "运维"
generated: true
---

# 从ibdata1到ibd：MySQL是如何管理数据“不动产”的？

> [!info] Provenance
> - doc_id: `418a747501aa79be9d4ccc7e444cd1b8`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/JknHpRh8ZsUfBwbta9Um8g)
> - PDF: [open local PDF](../../collector/418a747501aa79be9d4ccc7e444cd1b8.pdf)

## Summary

这篇文章用房产比喻梳理了 InnoDB 表空间的核心概念，包括共享表空间、独立表空间、临时表空间，以及 `ibdata1`、`ibd`、`ibtmp1` 的用途；同时给出了表空间迁移、信息架构查询、页/段/区结构、行格式和碎片整理的实战命令。

## Knowledge Outline

- 表空间与住房比喻 — MySQL, InnoDB, 表空间
- 共享表空间与多文件配置 — MySQL, InnoDB, ibdata1, 配置
- 独立表空间与 .ibd — MySQL, InnoDB, 独立表空间, .ibd
- 临时表空间 — MySQL, InnoDB, 临时表空间, 监控, 风险
- 迁移与元数据查询 — MySQL, InnoDB, 表空间迁移, information_schema, DBA
- 内部结构与页布局 — MySQL, InnoDB, 页, 段, 区, 存储结构
- 行格式 — MySQL, InnoDB, 行格式, ROW_FORMAT, 存储优化
- 性能优化与维护 — MySQL, InnoDB, 性能优化, 碎片整理, 监控, DBA

## Repository Paths

- PDF: `collector/418a747501aa79be9d4ccc7e444cd1b8.pdf`
- Extracted: `generated/extracted/418a747501aa79be9d4ccc7e444cd1b8/full.md`
- Filtered: `generated/filtered/418a747501aa79be9d4ccc7e444cd1b8/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
