---
doc_id: "681f331f41efc7e130c57fe0adb36cfd"
title: "意想不到的MySQL复制延迟原因-腾讯云开发者社区-腾讯云"
aliases:
  - "意想不到的MySQL复制延迟原因-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/2185088"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "主从复制"
  - "复制延迟"
  - "性能调优"
  - "故障排查"
  - "表分区"
  - "DBA"
generated: true
---

# 意想不到的MySQL复制延迟原因-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `681f331f41efc7e130c57fe0adb36cfd`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/2185088)
> - PDF: [open local PDF](../../collector/681f331f41efc7e130c57fe0adb36cfd.pdf)

## Summary

本文记录了一个 MySQL 5.7 主从复制严重延迟的排查过程，先排除负载、I/O、CPU、索引等常见因素，最终定位到表分区数量过多导致复制线程开销异常，并通过清理不需要的分区解决问题。

## Knowledge Outline

- 延迟现象 — MySQL, 主从复制, 复制延迟, 故障排查
- 排查过程 — MySQL, 主从复制, 性能调优, 源码分析, 表分区
- 根因与解决 — MySQL, 表分区, 主从复制, 故障排查, DBA

## Repository Paths

- PDF: `collector/681f331f41efc7e130c57fe0adb36cfd.pdf`
- Extracted: `generated/extracted/681f331f41efc7e130c57fe0adb36cfd/full.md`
- Filtered: `generated/filtered/681f331f41efc7e130c57fe0adb36cfd/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
