---
doc_id: "af409e79577162f416b6463ce5d15a87"
title: "[MYSQL] row_format=compressed的存储结构浅析"
aliases:
  - "[MYSQL] row_format=compressed的存储结构浅析"
url: "https://www.modb.pro/db/1946035841021784064"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "row_format=compressed"
  - "行压缩"
  - "存储结构"
  - "ibd解析"
  - "Python"
  - "数据库"
generated: true
---

# [MYSQL] row_format=compressed的存储结构浅析

> [!info] Provenance
> - doc_id: `af409e79577162f416b6463ce5d15a87`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1946035841021784064)
> - PDF: [open local PDF](../../collector/af409e79577162f416b6463ce5d15a87.pdf)

## Summary

这篇文章主要讲 MySQL InnoDB 的 `row_format=compressed` 行压缩：如何通过 `FSP_SPACE_FLAGS` 判断表是否压缩、`ZIP_SSIZE` 和 `PAGE_SSIZE` 的含义、压缩页的大致布局，以及通过 `ibd` 和 `zlib.decompressobj()` 验证压缩页结构的过程。

## Knowledge Outline

- 行压缩概述 — MySQL, InnoDB, row_format=compressed, 行压缩, 存储结构
- 确认压缩大小 — MySQL, InnoDB, FSP_SPACE_FLAGS, ZIP_SSIZE, PAGE_SSIZE, ibd解析, Python
- 压缩页结构 — MySQL, InnoDB, page_zip_decompress_low, 压缩页, 存储结构, 事务ID, rollptr
- 验证结构 — MySQL, InnoDB, ibd, Python, zlib, page dir, 压缩页验证
- 验证结论 — MySQL, InnoDB, 压缩页, zlib, rollptr, overflow page, 验证
- 总结 — MySQL, row_format=compressed, page compression, zlib, lz4, 总结

## Repository Paths

- PDF: `collector/af409e79577162f416b6463ce5d15a87.pdf`
- Extracted: `generated/extracted/af409e79577162f416b6463ce5d15a87/full.md`
- Filtered: `generated/filtered/af409e79577162f416b6463ce5d15a87/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
