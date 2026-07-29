---
doc_id: "813c74ea2eee6595f183870c6c05af83"
title: "xtrabackup 8.0如何恢复单表-腾讯云开发者社区-腾讯云"
aliases:
  - "xtrabackup 8.0如何恢复单表-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/1970574"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "GreatSQL"
  - "XtraBackup"
  - "单表恢复"
  - "物理备份"
  - "InnoDB"
  - "DBA"
generated: true
---

# xtrabackup 8.0如何恢复单表-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `813c74ea2eee6595f183870c6c05af83`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/1970574)
> - PDF: [open local PDF](../../collector/813c74ea2eee6595f183870c6c05af83.pdf)

## Summary

本文记录 GreatSQL 8.0.25 InnoDB 环境下使用 xtrabackup 8.0 备份并恢复单表 test.t_user 的操作流程，包括备份单表、prepare/export、创建同结构测试表、discard/import tablespace、复制 .cfg/.ibd 文件并验证数据行数。

## Knowledge Outline

- 实验环境 — GreatSQL, MySQL, InnoDB
- 备份单表 — XtraBackup, 单表备份, MySQL
- 恢复备份 — XtraBackup, prepare, export
- 创建测试表 — MySQL, DDL, InnoDB
- 卸载新表表空间 — InnoDB, tablespace, MySQL
- 复制备份文件 — XtraBackup, InnoDB, 文件复制
- 挂载新表表空间 — InnoDB, tablespace, MySQL
- 验证恢复数据 — MySQL, 数据校验, 单表恢复

## Repository Paths

- PDF: `collector/813c74ea2eee6595f183870c6c05af83.pdf`
- Extracted: `generated/extracted/813c74ea2eee6595f183870c6c05af83/full.md`
- Filtered: `generated/filtered/813c74ea2eee6595f183870c6c05af83/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
