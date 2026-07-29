---
doc_id: "801ad604fe510fdd79c023b9c99aa7df"
title: "mysql自适应哈希索引（AHI）,40%性能提升，为何有人却选择关闭？"
aliases:
  - "mysql自适应哈希索引（AHI）,40%性能提升，为何有人却选择关闭？"
url: "https://www.modb.pro/db/1937342590010011648"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "自适应哈希索引"
  - "AHI"
  - "性能调优"
  - "DBA"
  - "数据库优化"
  - "锁竞争"
generated: true
---

# mysql自适应哈希索引（AHI）,40%性能提升，为何有人却选择关闭？

> [!info] Provenance
> - doc_id: `801ad604fe510fdd79c023b9c99aa7df`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1937342590010011648)
> - PDF: [open local PDF](../../collector/801ad604fe510fdd79c023b9c99aa7df.pdf)

## Summary

文章说明 MySQL InnoDB 自适应哈希索引（AHI）的原理、适合开启的读密集与深层 B+ 树场景、一个开启/关闭 AHI 的性能对比案例，以及 DDL 成本、锁竞争、维护开销等副作用，最后给出按版本、负载、内存和写入频率决策的建议。

## Knowledge Outline

- AHI 核心机制 — MySQL, InnoDB, AHI, B+树
- 建议开启场景 — 最佳实践, 读密集, Buffer Pool, Join, 性能调优
- 执行计划案例 — Explain, 执行计划, SQL优化
- 开启 AHI 测试 — AHI, 性能测试, MySQL变量
- 关闭 AHI 测试 — AHI, 性能测试, Explain
- DDL 成本升高 — DDL, Drop Table, Buffer Pool, AHI, MySQL 5.7
- 高并发锁竞争 — 锁竞争, btr_search_latch, InnoDB Status, CPU, 并发
- 收益小于开销 — AHI, 维护开销, 热点数据, 索引页
- 开启决策结论 — MySQL 8.4 LTS, 性能基线, DBA决策, 读写负载

## Repository Paths

- PDF: `collector/801ad604fe510fdd79c023b9c99aa7df.pdf`
- Extracted: `generated/extracted/801ad604fe510fdd79c023b9c99aa7df/full.md`
- Filtered: `generated/filtered/801ad604fe510fdd79c023b9c99aa7df/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
