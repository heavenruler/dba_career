---
doc_id: "5f7bdc0ef060d0efff808773e7782c67"
title: "重生之MySQL 索引失效六大陷阱"
aliases:
  - "重生之MySQL 索引失效六大陷阱"
url: "https://mp.weixin.qq.com/s/Vt37N499AocCqHPRpNbYaA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "資料庫"
  - "效能調優"
  - "索引"
  - "SQL"
  - "Troubleshooting"
generated: true
---

# 重生之MySQL 索引失效六大陷阱

> [!info] Provenance
> - doc_id: `5f7bdc0ef060d0efff808773e7782c67`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/Vt37N499AocCqHPRpNbYaA)
> - PDF: [open local PDF](../../collector/5f7bdc0ef060d0efff808773e7782c67.pdf)

## Summary

這篇文章用 6 個 MySQL 索引失效場景，整理了常見的查詢寫法陷阱、修復方式與檢查工具，核心重點集中在型別轉換、函數運算、最左前綴、字元集轉換、複合索引匹配與優化器選索引。

## Knowledge Outline

- 类型转换 — MySQL, 索引, 型別轉換, SQL
- 函数操作 — MySQL, 索引, 函數, 效能調優
- 最左前缀 — MySQL, 索引, 最左前缀, 执行计划
- 字符集转换 — MySQL, 索引, 字符集, 隐式转换
- 最左匹配 — MySQL, 索引, 複合索引, 最左匹配
- 索引选择器 — MySQL, 索引, 优化器, FORCE INDEX
- 检验与总结 — MySQL, 索引, 检验工具, 效能調優, SQL

## Repository Paths

- PDF: `collector/5f7bdc0ef060d0efff808773e7782c67.pdf`
- Extracted: `generated/extracted/5f7bdc0ef060d0efff808773e7782c67/full.md`
- Filtered: `generated/filtered/5f7bdc0ef060d0efff808773e7782c67/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
