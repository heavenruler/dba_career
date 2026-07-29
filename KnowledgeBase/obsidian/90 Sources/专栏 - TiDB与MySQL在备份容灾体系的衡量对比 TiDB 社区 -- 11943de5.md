---
doc_id: "11943de59bf565b7d958f82d5ef421cf"
title: "专栏 - TiDB与MySQL在备份容灾体系的衡量对比 | TiDB 社区"
aliases:
  - "专栏 - TiDB与MySQL在备份容灾体系的衡量对比 | TiDB 社区"
url: "https://tidb.net/blog/8788eb77"
source_domain: "tidb.net"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "TiDB"
  - "备份容灾"
  - "快照"
  - "BR"
  - "LVM"
  - "DBA"
  - "时间点恢复"
generated: true
---

# 专栏 - TiDB与MySQL在备份容灾体系的衡量对比 | TiDB 社区

> [!info] Provenance
> - doc_id: `11943de59bf565b7d958f82d5ef421cf`
> - source_kind: `llm_filtered`
> - source: [original URL](https://tidb.net/blog/8788eb77)
> - PDF: [open local PDF](../../collector/11943de59bf565b7d958f82d5ef421cf.pdf)

## Summary

本文对 MySQL 与 TiDB 的备份容灾体系做了对比，重点讲了逻辑备份、物理备份、增量备份、时间点恢复、BR、LVM 快照，以及一致性与性能之间的权衡。

## Knowledge Outline

- 三大体系 — 数据库, 备份容灾, DBA, 架构
- MySQL 备份体系 — MySQL, 逻辑备份, 物理备份, Xtrabackup, 一致性备份, 增量备份, PITR
- TiDB 备份体系 — TiDB, 逻辑备份, BR, 快照, 一致性备份, SST, 时间戳
- 快照与 LVM 示例 — TiDB, 快照, LVM, BR, 时间点恢复, 容灾
- 备份容灾总结 — MySQL, TiDB, 备份策略, 服务层备份, 物理备份, LVM, 锁, 性能权衡

## Repository Paths

- PDF: `collector/11943de59bf565b7d958f82d5ef421cf.pdf`
- Extracted: `generated/extracted/11943de59bf565b7d958f82d5ef421cf/full.md`
- Filtered: `generated/filtered/11943de59bf565b7d958f82d5ef421cf/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
