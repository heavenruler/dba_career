---
doc_id: "5a12b61dad7853075f20eae390ee29c2"
title: "如何在 TiDB 上高效运行序列号生成服务 | PingCAP 平凯星辰"
aliases:
  - "如何在 TiDB 上高效运行序列号生成服务 | PingCAP 平凯星辰"
url: "https://cn.pingcap.com/blog/how-to-run-the-serial-number-generation-service-efficiently-on-tidb/"
source_domain: "cn.pingcap.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "数据库"
  - "写入热点"
  - "序列号生成"
  - "Snowflake"
  - "性能调优"
  - "分布式数据库"
  - "Key Visualizer"
generated: true
---

# 如何在 TiDB 上高效运行序列号生成服务 | PingCAP 平凯星辰

> [!info] Provenance
> - doc_id: `5a12b61dad7853075f20eae390ee29c2`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cn.pingcap.com/blog/how-to-run-the-serial-number-generation-service-efficiently-on-tidb/)
> - PDF: [open local PDF](../../collector/5a12b61dad7853075f20eae390ee29c2.pdf)

## Summary

本文说明 TiDB 上序列号生成服务的写入热点问题，比较自增列、Sequence、号段分配、Snowflake 等方案，并用三组压测展示整型主键默认写入、Snowflake 序列号换位、字符型主键加 shard_row_id_bits 的效果与取舍。

## Knowledge Outline

- 唯一序列号的用途 — 主键, 代理键, OLTP
- 常见序列号方案 — auto_increment, Sequence, segment, Snowflake
- TiDB 写入热点成因 — B+ tree, 主键, 写入热点
- 顺序主键在 TiDB 的影响 — TiKV, region, Key Visualizer, Dashboard
- TiDB Key 编码与隐藏列 — _tidb_rowid, SHARD_ROW_ID_BITS, PD, TiKV
- 测试表结构 — DDL, TiDB, 测试表
- 压测场景 — batch insert, Snowflake, 压测
- 默认设置测试结果 — 压测结果, 写入热点, Key Visualizer
- 序列号换位方案 — Snowflake, 序列号换位, region, 写入分片
- 序列号换位测试结果 — 压测结果, 性能调优
- 字符型主键打散方案 — 字符型主键, shard_row_id_bits, pre_split_regions, 非聚簇索引
- 字符型主键测试结果 — 压测结果, TiDB
- 测试结论 — 测试结论, 写入分片, 性能调优
- 测试成绩表 — 压测结果, 性能对比
- Snowflake 换位示例代码 — Java, Snowflake, 示例代码
- TiDB v5.0 聚簇索引展望 — TiDB v5.0, 聚簇索引, SHARD_ROW_ID_BITS

## Repository Paths

- PDF: `collector/5a12b61dad7853075f20eae390ee29c2.pdf`
- Extracted: `generated/extracted/5a12b61dad7853075f20eae390ee29c2/full.md`
- Filtered: `generated/filtered/5a12b61dad7853075f20eae390ee29c2/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
