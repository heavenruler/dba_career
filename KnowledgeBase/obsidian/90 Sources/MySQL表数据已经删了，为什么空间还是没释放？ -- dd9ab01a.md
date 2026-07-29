---
doc_id: "dd9ab01aa305698c82f77c8cc05f2e0d"
title: "MySQL表数据已经删了，为什么空间还是没释放？"
aliases:
  - "MySQL表数据已经删了，为什么空间还是没释放？"
url: "https://mp.weixin.qq.com/s/08QfxxIgMCCIjElE5A2Q9g"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "表空间"
  - "空间回收"
  - "碎片化"
  - "MVCC"
  - "DBA"
  - "性能调优"
generated: true
---

# MySQL表数据已经删了，为什么空间还是没释放？

> [!info] Provenance
> - doc_id: `dd9ab01aa305698c82f77c8cc05f2e0d`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/08QfxxIgMCCIjElE5A2Q9g)
> - PDF: [open local PDF](../../collector/dd9ab01aa305698c82f77c8cc05f2e0d.pdf)

## Summary

这篇文章解释了为什么 MySQL 执行 DELETE 或 DROP TABLE 后磁盘空间不一定立刻释放，核心原因包括 InnoDB 的表空间机制、逻辑删除、数据空洞、MVCC、共享表空间限制，并给出 OPTIMIZE TABLE、ALTER TABLE 重建、迁移系统表空间、调整 purge 参数、定期维护和在线 DDL 工具等回收与预防方法。

## Knowledge Outline

- 问题现象 — MySQL, 空间回收, InnoDB
- InnoDB 核心机制 — InnoDB, B+树, 表空间, 逻辑删除
- 空间不释放原因 — InnoDB, MVCC, 数据空洞, 共享表空间, 碎片化
- 空间回收方法 — OPTIMIZE TABLE, ALTER TABLE, 在线DDL, purge, pt-online-schema-change, gh-ost, 空间回收
- 预防碎片化 — 碎片化, 监控, 预警, 分区表, InnoDB参数, 性能调优
- 总结 — MySQL, 总结, 空间管理, DBA, 性能调优

## Repository Paths

- PDF: `collector/dd9ab01aa305698c82f77c8cc05f2e0d.pdf`
- Extracted: `generated/extracted/dd9ab01aa305698c82f77c8cc05f2e0d/full.md`
- Filtered: `generated/filtered/dd9ab01aa305698c82f77c8cc05f2e0d/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
