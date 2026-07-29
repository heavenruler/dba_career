---
doc_id: "c987ef17da2cd800c929f41f933f30f9"
title: "Galera Cluster一致性问题本文主要说明MariaDB Galera Cluster + ProxySQL 方 - 掘金"
aliases:
  - "Galera Cluster一致性问题本文主要说明MariaDB Galera Cluster + ProxySQL 方 - 掘金"
url: "https://juejin.cn/post/6961245441136525320"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MariaDB"
  - "Galera Cluster"
  - "ProxySQL"
  - "一致性"
  - "复制"
  - "性能调优"
  - "故障处理"
generated: true
---

# Galera Cluster一致性问题本文主要说明MariaDB Galera Cluster + ProxySQL 方 - 掘金

> [!info] Provenance
> - doc_id: `c987ef17da2cd800c929f41f933f30f9`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/6961245441136525320)
> - PDF: [open local PDF](../../collector/c987ef17da2cd800c929f41f933f30f9.pdf)

## Summary

本文围绕 MariaDB Galera Cluster 的一致性与同步延迟问题，说明多主复制的基本原理、写集冲突检查、常见故障点，以及通过 wsrep_slave_threads、flow control 和 wsrep_causal_reads 等手段降低延迟和改善读取一致性。

## Knowledge Outline

- 多主模式概述 — MariaDB, Galera Cluster, 多主复制, 一致性
- 写集提交流程 — MariaDB, Galera Cluster, 写集, 同步延迟, 复制
- 常见问题汇总 — MariaDB, Galera Cluster, 故障处理, 脑裂, 并发写, DDL
- 同步延迟调优 — MariaDB, Galera Cluster, 性能调优, wsrep_slave_threads, wsrep_causal_reads, 一致性

## Repository Paths

- PDF: `collector/c987ef17da2cd800c929f41f933f30f9.pdf`
- Extracted: `generated/extracted/c987ef17da2cd800c929f41f933f30f9/full.md`
- Filtered: `generated/filtered/c987ef17da2cd800c929f41f933f30f9/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
