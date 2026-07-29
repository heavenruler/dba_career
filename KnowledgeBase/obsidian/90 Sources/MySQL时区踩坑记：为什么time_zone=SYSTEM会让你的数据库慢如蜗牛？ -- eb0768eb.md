---
doc_id: "eb0768ebcf35cf0e987dc2e6e6ca9fac"
title: "MySQL时区踩坑记：为什么time_zone=SYSTEM会让你的数据库慢如蜗牛？"
aliases:
  - "MySQL时区踩坑记：为什么time_zone=SYSTEM会让你的数据库慢如蜗牛？"
url: "https://mp.weixin.qq.com/s/FpEKpITrhkunVNLP-gluhA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "时区"
  - "性能优化"
  - "DBA"
  - "TIMESTAMP"
  - "SQL"
  - "生产实践"
generated: true
---

# MySQL时区踩坑记：为什么time_zone=SYSTEM会让你的数据库慢如蜗牛？

> [!info] Provenance
> - doc_id: `eb0768ebcf35cf0e987dc2e6e6ca9fac`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/FpEKpITrhkunVNLP-gluhA)
> - PDF: [open local PDF](../../collector/eb0768ebcf35cf0e987dc2e6e6ca9fac.pdf)

## Summary

文章说明 `time_zone=SYSTEM` 会让 MySQL 的时区转换频繁访问操作系统，带来系统调用与锁竞争开销，并对 `NOW()`、`TIMESTAMP` 查询、时间范围查询和批量写入造成明显性能下降；同时给出检测、修复和最佳实践。

## Knowledge Outline

- SYSTEM 时区的性能坑 — MySQL, 时区, 性能优化, DBA
- 函数与 TIMESTAMP 测试 — MySQL, 时区, TIMESTAMP, 性能测试, SQL
- 检测与修复 — MySQL, 时区, 排查, 配置, DBA
- 机制与对比 — MySQL, 时区, 性能优化, 最佳实践, Java
- 分布式思考 — MySQL, 时区, 分布式系统, 架构设计, 数据一致性

## Repository Paths

- PDF: `collector/eb0768ebcf35cf0e987dc2e6e6ca9fac.pdf`
- Extracted: `generated/extracted/eb0768ebcf35cf0e987dc2e6e6ca9fac/full.md`
- Filtered: `generated/filtered/eb0768ebcf35cf0e987dc2e6e6ca9fac/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
