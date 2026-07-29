---
doc_id: "da3cbf9103dd0fde44989bcf85ce8d8e"
title: "[MYSQL] 出现大量的Waiting for table flush导致业务表查询不了"
aliases:
  - "[MYSQL] 出现大量的Waiting for table flush导致业务表查询不了"
url: "https://mp.weixin.qq.com/s/s4cFhr-AjTvY1biLmLl6cg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MYSQL"
  - "Waiting for table flush"
  - "MDL"
  - "mysqldump"
  - "gdb"
  - "源码分析"
  - "故障排查"
  - "备份"
  - "大事务"
generated: true
---

# [MYSQL] 出现大量的Waiting for table flush导致业务表查询不了

> [!info] Provenance
> - doc_id: `da3cbf9103dd0fde44989bcf85ce8d8e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/s4cFhr-AjTvY1biLmLl6cg)
> - PDF: [open local PDF](../../collector/da3cbf9103dd0fde44989bcf85ce8d8e.pdf)

## Summary

这篇文章围绕 MySQL 在 `Waiting for table flush` 状态下导致业务查询阻塞的问题展开，先从现象和备份时间点对齐做初判，再通过复现环境、`gdb` 堆栈和源码路径确认：`flush tables` 会推动 `refresh_version++`，而大事务或旧版本表共享对象会让后续会话在打开表时等待旧版本释放。最后给出减少大事务、避开大事务窗口做备份等建议，并指出 `flush tables with read lock` 也会触发相同行为。

## Knowledge Outline

- 现象与初判 — MYSQL, Waiting for table flush, MDL, 备份, 大事务, 故障排查
- 复现步骤 — MYSQL, 复现, SQL, 备份, 大事务, mysqldump
- 堆栈分析 — MYSQL, gdb, MDL, 源码分析, 表锁, 表刷新
- 版本刷新 — MYSQL, gdb, refresh_version, 源码分析, close_cached_tables, flush tables
- 结论与建议 — MYSQL, 总结, 建议, 备份, 大事务, binlog
- 参考 — MYSQL, 参考链接, metadata locks, thread states

## Repository Paths

- PDF: `collector/da3cbf9103dd0fde44989bcf85ce8d8e.pdf`
- Extracted: `generated/extracted/da3cbf9103dd0fde44989bcf85ce8d8e/full.md`
- Filtered: `generated/filtered/da3cbf9103dd0fde44989bcf85ce8d8e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
