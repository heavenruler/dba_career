---
doc_id: "662013dda71c61bbe2c09ad1428dad4e"
title: "MySQL内存为什么不断增高，怎么让它释放"
aliases:
  - "MySQL内存为什么不断增高，怎么让它释放"
url: "https://mp.weixin.qq.com/s?__biz=MjM5NzAzMTY4NQ==&mid=2653938861&idx=1&sn=2de853dd9120693b85d91c78330249f2&chksm=bd3b7ec78a4cf7d1a95fe21ad7cff60d61c8f913f75269eec931c671e6959aa852d9525e8858&scene=178&cur_album_id=1337959503719137280#rd"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "内存管理"
  - "jemalloc"
  - "glibc"
  - "gdb"
  - "性能调优"
  - "故障排查"
  - "OOM"
generated: true
---

# MySQL内存为什么不断增高，怎么让它释放

> [!info] Provenance
> - doc_id: `662013dda71c61bbe2c09ad1428dad4e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s?__biz=MjM5NzAzMTY4NQ==&mid=2653938861&idx=1&sn=2de853dd9120693b85d91c78330249f2&chksm=bd3b7ec78a4cf7d1a95fe21ad7cff60d61c8f913f75269eec931c671e6959aa852d9525e8858&scene=178&cur_album_id=1337959503719137280#rd)
> - PDF: [open local PDF](../../collector/662013dda71c61bbe2c09ad1428dad4e.pdf)

## Summary

本文通过 sysbench 压测和大事务 insert 两个场景复现 MySQL 连接断开后内存不回落的问题，对比 glibc 与 jemalloc 的释放行为，并用 gdb 验证 SQL 语句执行完会释放 mem_root，session 退出后还会释放部分 NET::buff。

## Knowledge Outline

- 问题现象与复现 — MySQL, 内存管理, 故障排查, sysbench, OOM
- 大事务插入与 jemalloc — MySQL, jemalloc, 内存管理, 性能调优, 故障排查
- jemalloc 的回收效果 — jemalloc, glibc, MySQL, 内存管理, OOM
- gdb 调试验证 — MySQL, gdb, 内存管理, jemalloc, 源码调试
- 会话退出与 NET::buff — MySQL, 内存管理, NET::buff, 连接生命周期, 故障排查
- 结论 — MySQL, jemalloc, glibc, 内存管理, 结论

## Repository Paths

- PDF: `collector/662013dda71c61bbe2c09ad1428dad4e.pdf`
- Extracted: `generated/extracted/662013dda71c61bbe2c09ad1428dad4e/full.md`
- Filtered: `generated/filtered/662013dda71c61bbe2c09ad1428dad4e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
