---
doc_id: "65a4c9cc26789c98e196bd0be9c0a1e3"
title: "专栏 - 为什么说TiDB在线扩容对业务几乎没有影响 | TiDB 社区"
aliases:
  - "专栏 - 为什么说TiDB在线扩容对业务几乎没有影响 | TiDB 社区"
url: "https://tidb.net/blog/e82b2c5f"
source_domain: "tidb.net"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "TiKV"
  - "分布式数据库"
  - "数据库架构"
  - "在线扩容"
  - "一致性哈希"
  - "Multi Raft"
  - "性能影响"
generated: true
---

# 专栏 - 为什么说TiDB在线扩容对业务几乎没有影响 | TiDB 社区

> [!info] Provenance
> - doc_id: `65a4c9cc26789c98e196bd0be9c0a1e3`
> - source_kind: `llm_filtered`
> - source: [original URL](https://tidb.net/blog/e82b2c5f)
> - PDF: [open local PDF](../../collector/65a4c9cc26789c98e196bd0be9c0a1e3.pdf)

## Summary

文章对比分布式数据库与 TiDB 的在线扩容机制：一般分布式数据库扩容往往会触发大规模数据重分布，而 TiDB 因为存算分离，计算层可直接加节点，存储层则通过 PD 调度、副本复制、删除旧副本和 Leader 重新均衡来实现几乎无感扩容。

## Knowledge Outline

- 一般分布式数据库扩容 — 数据库架构, 分布式数据库, 在线扩容, 一致性哈希, Greenplum, DBA
- TiDB 计算层扩容 — TiDB, 存算分离, 无状态服务, 计算扩容, 负载均衡, 数据库架构
- TiKV 扩容流程 — TiKV, Multi Raft, Region, Raft, PD调度, Leader均衡, 流控, 在线扩容

## Repository Paths

- PDF: `collector/65a4c9cc26789c98e196bd0be9c0a1e3.pdf`
- Extracted: `generated/extracted/65a4c9cc26789c98e196bd0be9c0a1e3/full.md`
- Filtered: `generated/filtered/65a4c9cc26789c98e196bd0be9c0a1e3/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
