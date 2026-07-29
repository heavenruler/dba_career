---
doc_id: "9188f9c7f4423974c11dd8222435fe12"
title: "如何分析 mysqld crash 的原因"
aliases:
  - "如何分析 mysqld crash 的原因"
url: "https://mp.weixin.qq.com/s/BY75sBfrDWGVQZGsoiwMBQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "crash analysis"
  - "gdb"
  - "bug tracking"
  - "SQL"
  - "troubleshooting"
generated: true
---

# 如何分析 mysqld crash 的原因

> [!info] Provenance
> - doc_id: `9188f9c7f4423974c11dd8222435fe12`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/BY75sBfrDWGVQZGsoiwMBQ)
> - PDF: [open local PDF](../../collector/9188f9c7f4423974c11dd8222435fe12.pdf)

## Summary

文章示範如何從 mysqld signal 11 的 crash log，透過堆疊位置、gdb / c++filt、關鍵字搜尋與 release note 追到 MySQL digest code 的已知 bug。

## Knowledge Outline

- Crash 現象與堆疊 — MySQL, crash log, signal 11, stack trace, DBA
- 先排除常见原因 — MySQL, OOM, monitoring, incident analysis, DBA
- 定位崩溃点 — gdb, mysqld, debugging, source code, MySQL
- 查到 bug 与版本 — MySQL, bug tracking, release note, sql, digest code, Percona, TXSQL

## Repository Paths

- PDF: `collector/9188f9c7f4423974c11dd8222435fe12.pdf`
- Extracted: `generated/extracted/9188f9c7f4423974c11dd8222435fe12/full.md`
- Filtered: `generated/filtered/9188f9c7f4423974c11dd8222435fe12/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
