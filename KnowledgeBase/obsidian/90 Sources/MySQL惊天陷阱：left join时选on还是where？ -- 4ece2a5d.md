---
doc_id: "4ece2a5d71108290a43bd9aa6fe88d14"
title: "MySQL惊天陷阱：left join时选on还是where？"
aliases:
  - "MySQL惊天陷阱：left join时选on还是where？"
url: "https://mp.weixin.qq.com/s/g6xKA76N1IR9EcESVoFO6A"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL"
  - "LEFT JOIN"
  - "数据库"
  - "查询优化"
generated: true
---

# MySQL惊天陷阱：left join时选on还是where？

> [!info] Provenance
> - doc_id: `4ece2a5d71108290a43bd9aa6fe88d14`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/g6xKA76N1IR9EcESVoFO6A)
> - PDF: [open local PDF](../../collector/4ece2a5d71108290a43bd9aa6fe88d14.pdf)

## Summary

这篇文章说明了 LEFT JOIN 中 ON 和 WHERE 的作用差异，并用 SQL 示例强调：ON 用于生成连接结果时的匹配条件，WHERE 用于生成临时表后的过滤；对于 LEFT JOIN，条件放在 ON 中不会改变左表记录的返回，而放在 WHERE 中可能把左表记录过滤掉。

## Knowledge Outline

- 问题示例 — MySQL, LEFT JOIN, SQL, 数据库
- ON 与 WHERE — MySQL, LEFT JOIN, ON, WHERE, 数据库
- 结论 — MySQL, LEFT JOIN, RIGHT JOIN, FULL JOIN, INNER JOIN, SQL

## Repository Paths

- PDF: `collector/4ece2a5d71108290a43bd9aa6fe88d14.pdf`
- Extracted: `generated/extracted/4ece2a5d71108290a43bd9aa6fe88d14/full.md`
- Filtered: `generated/filtered/4ece2a5d71108290a43bd9aa6fe88d14/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
