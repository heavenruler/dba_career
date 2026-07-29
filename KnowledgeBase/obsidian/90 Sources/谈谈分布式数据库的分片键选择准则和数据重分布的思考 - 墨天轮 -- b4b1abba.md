---
doc_id: "b4b1abba675ec98a51ed46678dd748af"
title: "谈谈分布式数据库的分片键选择准则和数据重分布的思考 - 墨天轮"
aliases:
  - "谈谈分布式数据库的分片键选择准则和数据重分布的思考 - 墨天轮"
url: "https://www.modb.pro/db/1827055525554642944"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "DBA"
  - "分布式数据库"
  - "分片键"
  - "数据重分布"
  - "数据倾斜"
  - "OLTP"
  - "OLAP"
  - "HATP"
  - "SQL优化"
generated: true
---

# 谈谈分布式数据库的分片键选择准则和数据重分布的思考 - 墨天轮

> [!info] Provenance
> - doc_id: `b4b1abba675ec98a51ed46678dd748af`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1827055525554642944)
> - PDF: [open local PDF](../../collector/b4b1abba675ec98a51ed46678dd748af.pdf)

## Summary

本文讨论分布式数据库中分片键的选择原则，核心围绕业务键、数据重分布、数据倾斜三点展开，并进一步用若干 join 场景解释何时会发生数据重分布，以及星形模式事实表分片键的取舍。

## Knowledge Outline

- 分片键选择的重要性 — DBA, 分布式数据库, 分片键, HATP, OLTP, OLAP
- 准则一 — DBA, 分布式数据库, 分片键, 业务键, 分布式事务, SQL优化
- 准则二、三与冲突 — DBA, 分布式数据库, 分片键, 数据重分布, 数据倾斜, join, 性能优化
- 重分布思考一至三 — DBA, 分布式数据库, 数据重分布, join, 分片键, SQL优化
- 星形模式与小表 — DBA, 分布式数据库, 星形模式, 事实表, 数据重分布, 性能瓶颈

## Repository Paths

- PDF: `collector/b4b1abba675ec98a51ed46678dd748af.pdf`
- Extracted: `generated/extracted/b4b1abba675ec98a51ed46678dd748af/full.md`
- Filtered: `generated/filtered/b4b1abba675ec98a51ed46678dd748af/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
