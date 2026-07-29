---
doc_id: "f0bc01c71363634b79aaa1216000b41d"
title: "技术分享 | 如何使用 bcc 工具观测 MySQL 延迟"
aliases:
  - "技术分享 | 如何使用 bcc 工具观测 MySQL 延迟"
url: "https://opensource.actionsky.com/20200324-mysql/"
source_domain: "opensource.actionsky.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "bcc"
  - "eBPF"
  - "BPF"
  - "性能分析"
  - "监控"
  - "Linux"
  - "开源软件"
generated: true
---

# 技术分享 | 如何使用 bcc 工具观测 MySQL 延迟

> [!info] Provenance
> - doc_id: `f0bc01c71363634b79aaa1216000b41d`
> - source_kind: `llm_filtered`
> - source: [original URL](https://opensource.actionsky.com/20200324-mysql/)
> - PDF: [open local PDF](../../collector/f0bc01c71363634b79aaa1216000b41d.pdf)

## Summary

本文介绍了 BPF/eBPF 与 bcc 的基本概念、bcc 的安装方式，以及用于观测 MySQL 延迟的 dbstat、dbslower 两个工具和使用限制。

## Knowledge Outline

- BPF 与 eBPF — BPF, eBPF, Linux, 监控, 可观测性
- bcc 是什么 — bcc, eBPF, Python, 开源软件, 可观测性
- 安装 bcc — bcc, 安装, Linux, Ubuntu, CentOS
- dbstat：查询延迟直方图 — MySQL, PostgreSQL, bcc, 延迟, 直方图, 监控
- dbslower：慢查询跟踪 — MySQL, PostgreSQL, bcc, 慢查询, 监控, 性能分析
- 使用限制 — bcc, 限制, Linux, MySQL, eBPF

## Repository Paths

- PDF: `collector/f0bc01c71363634b79aaa1216000b41d.pdf`
- Extracted: `generated/extracted/f0bc01c71363634b79aaa1216000b41d/full.md`
- Filtered: `generated/filtered/f0bc01c71363634b79aaa1216000b41d/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
