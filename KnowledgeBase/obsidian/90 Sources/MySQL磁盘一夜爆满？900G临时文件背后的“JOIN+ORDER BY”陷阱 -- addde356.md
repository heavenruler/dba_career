---
doc_id: "addde3560fe66ae3d4eacc59c2ec85d4"
title: "MySQL磁盘一夜爆满？900G临时文件背后的“JOIN+ORDER BY”陷阱"
aliases:
  - "MySQL磁盘一夜爆满？900G临时文件背后的“JOIN+ORDER BY”陷阱"
url: "https://mp.weixin.qq.com/s/jrLpr-EVV_tdYrsL8D_9BQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL优化"
  - "JOIN"
  - "ORDER BY"
  - "临时表"
  - "EXPLAIN"
  - "效能调优"
  - "SRE"
  - "事故覆盘"
generated: true
---

# MySQL磁盘一夜爆满？900G临时文件背后的“JOIN+ORDER BY”陷阱

> [!info] Provenance
> - doc_id: `addde3560fe66ae3d4eacc59c2ec85d4`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/jrLpr-EVV_tdYrsL8D_9BQ)
> - PDF: [open local PDF](../../collector/addde3560fe66ae3d4eacc59c2ec85d4.pdf)

## Summary

这篇文章讲的是 MySQL 在复杂 JOIN + ORDER BY 查询下生成大量临时表文件，导致磁盘短时间暴涨的事故。核心结论是：热点 SQL 若伴随 Using temporary / Using filesort，尤其排序列涉及大字段时，很容易触发磁盘临时文件失控；可通过 EXPLAIN、覆盖索引重写 SQL，以及限制 ibtmp1 上限来缓解。

## Knowledge Outline

- 事故现象 — MySQL, 磁盘告警, 事故覆盘, 临时文件
- 定位幽灵文件 — MySQL, lsof, 临时表, 排查
- 根因分析 — MySQL, JOIN, ORDER BY, BLOB, tmp_table_size, EXPLAIN, Using temporary, Using filesort
- SQL 重构 — MySQL, 覆盖索引, SQL重写, 性能优化
- 临时表上限 — MySQL, my.cnf, ibtmp1, 配置上限, 防护

## Repository Paths

- PDF: `collector/addde3560fe66ae3d4eacc59c2ec85d4.pdf`
- Extracted: `generated/extracted/addde3560fe66ae3d4eacc59c2ec85d4/full.md`
- Filtered: `generated/filtered/addde3560fe66ae3d4eacc59c2ec85d4/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
