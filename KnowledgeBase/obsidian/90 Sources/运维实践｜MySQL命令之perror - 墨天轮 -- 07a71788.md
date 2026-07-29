---
doc_id: "07a717881b13a95b7c412894c5c890a6"
title: "运维实践｜MySQL命令之perror - 墨天轮"
aliases:
  - "运维实践｜MySQL命令之perror - 墨天轮"
url: "https://www.modb.pro/db/1762038265985699840"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "运维实践"
  - "DBA"
  - "命令行工具"
  - "故障排查"
  - "troubleshooting"
generated: true
---

# 运维实践｜MySQL命令之perror - 墨天轮

> [!info] Provenance
> - doc_id: `07a717881b13a95b7c412894c5c890a6`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1762038265985699840)
> - PDF: [open local PDF](../../collector/07a717881b13a95b7c412894c5c890a6.pdf)

## Summary

本文介绍 MySQL 的 `perror` 命令：它用于解释系统错误码与 MySQL 错误码，展示 `--help` 的用法与参数格式，说明 `perror 13` 同时返回操作系统错误和 MySQL 错误信息的情况，并给出通过修改 `tmpdir` 处理临时目录权限问题的做法，还提供了批量遍历错误码的命令。

## Knowledge Outline

- 使用背景与位置 — MySQL, perror, 命令行工具, 定位
- 帮助与错误码解释 — MySQL, perror, 错误码, OS errno, 命令行工具
- tmpdir 修复方法 — MySQL, tmpdir, 配置, 权限, 故障排查
- 批量导出错误码 — MySQL, perror, 批量处理, 命令行工具

## Repository Paths

- PDF: `collector/07a717881b13a95b7c412894c5c890a6.pdf`
- Extracted: `generated/extracted/07a717881b13a95b7c412894c5c890a6/full.md`
- Filtered: `generated/filtered/07a717881b13a95b7c412894c5c890a6/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
