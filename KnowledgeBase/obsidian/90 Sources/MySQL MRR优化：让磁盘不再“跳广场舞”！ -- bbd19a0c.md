---
doc_id: "bbd19a0c71e5da944ef7cac41569bc91"
title: "MySQL MRR优化：让磁盘不再“跳广场舞”！"
aliases:
  - "MySQL MRR优化：让磁盘不再“跳广场舞”！"
url: "https://mp.weixin.qq.com/s/6phzzKNz2e98awXYJ_P7Xw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "MRR"
  - "InnoDB"
  - "索引优化"
  - "性能调优"
  - "数据库"
generated: true
---

# MySQL MRR优化：让磁盘不再“跳广场舞”！

> [!info] Provenance
> - doc_id: `bbd19a0c71e5da944ef7cac41569bc91`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/6phzzKNz2e98awXYJ_P7Xw)
> - PDF: [open local PDF](../../collector/bbd19a0c71e5da944ef7cac41569bc91.pdf)

## Summary

本文用 MRR 解释 MySQL 如何把随机回表转为顺序访问，并给出 InnoDB 工作流程、测试表与执行计划对比、适用场景和参数调优建议。

## Knowledge Outline

- MRR 定义 — MySQL, MRR, 概念, 性能调优
- 工作原理 — MySQL, MRR, InnoDB, 索引扫描, 回表
- 实战演示 — MySQL, MRR, EXPLAIN, 执行计划, 性能对比, SQL
- JOIN 与参数 — MySQL, MRR, JOIN, 参数调优, optimizer_switch
- 适用场景与限制 — MySQL, MRR, 适用场景, 范围查询, 限制
- 结语 — MySQL, MRR, 总结, 性能优化

## Repository Paths

- PDF: `collector/bbd19a0c71e5da944ef7cac41569bc91.pdf`
- Extracted: `generated/extracted/bbd19a0c71e5da944ef7cac41569bc91/full.md`
- Filtered: `generated/filtered/bbd19a0c71e5da944ef7cac41569bc91/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
