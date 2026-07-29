---
doc_id: "098499a5822a1ebae8f2016ac0d796e4"
title: "关于MySQL checkpoint - 海东潮 - 博客园"
aliases:
  - "关于MySQL checkpoint - 海东潮 - 博客园"
url: "https://www.cnblogs.com/DataArt/p/10236642.html"
source_domain: "www.cnblogs.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "checkpoint"
  - "LSN"
  - "redo log"
  - "undo log"
  - "dirty page"
  - "buffer pool"
  - "数据库恢复"
  - "性能调优"
generated: true
---

# 关于MySQL checkpoint - 海东潮 - 博客园

> [!info] Provenance
> - doc_id: `098499a5822a1ebae8f2016ac0d796e4`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.cnblogs.com/DataArt/p/10236642.html)
> - PDF: [open local PDF](../../collector/098499a5822a1ebae8f2016ac0d796e4.pdf)

## Summary

本文说明 MySQL/InnoDB checkpoint 的作用、LSN 的含义与存放位置、checkpoint 流程、flush list 设计原因、回滚与 undo log 的关系、checkpoint 分类，以及 dirty page 刷盘触发条件与相关参数。

## Knowledge Outline

- Checkpoint 作用 — MySQL, checkpoint, dirty page, redo log
- Checkpoint 恢复过程 — buffer pool, checkpoint, crash recovery
- LSN 示例步骤 — LSN, redo log, crash recovery
- LSN 重点 — LSN, redo log
- LSN 定义与位置 — LSN, page header, redo log, checkpoint
- Buffer Page LSN 字段 — INNODB_BUFFER_PAGE_LRU, LSN, buffer pool
- InnoDB Status LSN — show engine innodb status, LSN, redo log, checkpoint
- Flush List 组织方式 — flush list, dirty page, LSN
- Flush List 设计分析 — buffer pool, LRU, flush list, LSN
- 恢复连续性 — crash recovery, redo log, flush list, LSN
- Checkpoint 与回滚 — checkpoint, redo log, undo log, rollback, purge
- Checkpoint 分类 — Sharp Checkpoint, Fuzzy Checkpoint, innodb_fast_shutdown, innodb_io_capacity
- Dirty Page 刷新时机 — dirty page, page_cleaner_thread, FLUSH_LRU_LIST, innodb_lru_scan_depth, innodb_max_dirty_pages_pct
- Dirty Page 刷新 Tips — dirty page, flush list, LRU list, free list, innodb_io_capacity

## Repository Paths

- PDF: `collector/098499a5822a1ebae8f2016ac0d796e4.pdf`
- Extracted: `generated/extracted/098499a5822a1ebae8f2016ac0d796e4/full.md`
- Filtered: `generated/filtered/098499a5822a1ebae8f2016ac0d796e4/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
