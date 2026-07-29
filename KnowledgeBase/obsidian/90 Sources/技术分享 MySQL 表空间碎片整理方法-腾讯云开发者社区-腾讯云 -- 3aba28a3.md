---
doc_id: "3aba28a31c245563bc6d4253665d9938"
title: "技术分享 | MySQL 表空间碎片整理方法-腾讯云开发者社区-腾讯云"
aliases:
  - "技术分享 | MySQL 表空间碎片整理方法-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/1848499"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "表空间碎片"
  - "性能调优"
  - "MyISAM"
  - "InnoDB"
  - "mysqlcheck"
  - "数据库运维"
generated: true
---

# 技术分享 | MySQL 表空间碎片整理方法-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `3aba28a31c245563bc6d4253665d9938`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/1848499)
> - PDF: [open local PDF](../../collector/3aba28a31c245563bc6d4253665d9938.pdf)

## Summary

本文說明 MySQL 表空間碎片形成原因、如何用 show table status / OS 檔案大小 / data_free 檢查碎片，並比較整理前後全表掃描效能與磁碟空間占用，涵蓋 alter table force、OPTIMIZE TABLE、alter table engine=innodb、mysqlcheck 批量優化等方法。

## Knowledge Outline

- 表空间碎片背景 — MySQL, 表空间碎片, 性能调优
- 检查表空间碎片 — MySQL, show table status, Data_free, MyISAM
- 删除后空间未释放 — MySQL, delete, Data_free, 磁盘空间
- 整理前全表扫描 — MySQL, 全表扫描, 性能测试, sys.session
- 整理表空间 — MySQL, alter table force, 表空间整理, Data_free
- 整理后性能提升 — MySQL, MyISAM, InnoDB, Linux, drop_caches, 性能测试
- OPTIMIZE TABLE 替代方式 — MySQL, OPTIMIZE TABLE, InnoDB, ARCHIVE, alter table
- 查找可释放空间表 — MySQL, information_schema, data_free, SQL
- mysqlcheck 批量优化 — MySQL, mysqlcheck, crontab, Windows计划任务, 批量优化

## Repository Paths

- PDF: `collector/3aba28a31c245563bc6d4253665d9938.pdf`
- Extracted: `generated/extracted/3aba28a31c245563bc6d4253665d9938/full.md`
- Filtered: `generated/filtered/3aba28a31c245563bc6d4253665d9938/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
